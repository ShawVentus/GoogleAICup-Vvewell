import Accelerate
import AVFoundation
import CoreImage
import CoreML
import Foundation
import Vision

enum RPPGFailureReason: Equatable {
    case unsupportedOS
    case modelLoadFailed
    case faceNotFound
    case insufficientFrames
    case lowSignalQuality
    case predictionFailed
}

struct RPPGLiveSnapshot {
    let hr: Double?
    let sqi: Double?
    let confidence: String?
    let processedFrameCount: Int
    let validFrameCount: Int
    let progress: Double
    let failureReason: RPPGFailureReason?
}

/// rPPG 端侧 CoreML 推理服务
/// 管理有状态流式模型，逐帧累积 BVP 信号，最终估算生理指标
final class RPPGInferenceService {

    private struct StateTensorSpec {
        let inputName: String
        let outputName: String
        let shape: [Int]
    }

    private struct MetricsState {
        var processedFrameCount = 0
        var validFrameCount = 0
        var bvpBuffer: [Float] = []
        var redMeans: [Float] = []
        var greenMeans: [Float] = []
        var blueMeans: [Float] = []
        var latestHR: Double?
        var latestSQI: Double?
        var latestConfidence: String?
        var failureReason: RPPGFailureReason?
        var consecutiveFaceMisses = 0
    }

    private struct FacePatch {
        let tensor: MLMultiArray
        let redMean: Float
        let greenMean: Float
        let blueMean: Float
    }

    private struct ComplexSample {
        let frequency: Double
        let real: Float
        let imag: Float
        let power: Double
    }

    private static let frameInputName = "input_1"
    private static let dtInputName = "input_38"
    private static let bvpOutputName = "var_1555"
    private static let frameShape = [1, 1, 36, 36, 3]
    private static let patchSize = 36
    private static let fps = 30.0
    private static let minResultFrames = 150
    private static let maxBVPBufferSize = 1800
    private static let maxFaceMissesBeforeFailure = 15
    private static let roiExpansionRatio = 0.18
    private static let minimumSQI = 0.2

    private static let stateSpecs: [StateTensorSpec] = [
        .init(inputName: "input_2", outputName: "second_13", shape: [1, 1, 36, 36, 32]),
        .init(inputName: "input_3", outputName: "first_11", shape: [1, 1, 36, 36, 32]),
        .init(inputName: "input_4", outputName: "var_358", shape: [1, 1, 4, 32, 128]),
        .init(inputName: "input_5", outputName: "input_tensor_53", shape: [1, 4, 384]),
        .init(inputName: "input_6", outputName: "second_75", shape: [1, 1, 36, 36, 32]),
        .init(inputName: "input_7", outputName: "first_59", shape: [1, 1, 36, 36, 32]),
        .init(inputName: "input_8", outputName: "var_495", shape: [1, 1, 4, 32, 128]),
        .init(inputName: "input_9", outputName: "input_tensor_193", shape: [1, 4, 384]),
        .init(inputName: "input_10", outputName: "second_139", shape: [1, 1, 18, 18, 32]),
        .init(inputName: "input_11", outputName: "first_111", shape: [1, 1, 18, 18, 32]),
        .init(inputName: "input_12", outputName: "var_641", shape: [1, 1, 4, 32, 128]),
        .init(inputName: "input_13", outputName: "input_tensor_343", shape: [1, 4, 384]),
        .init(inputName: "input_14", outputName: "second_201", shape: [1, 1, 18, 18, 32]),
        .init(inputName: "input_15", outputName: "first_159", shape: [1, 1, 18, 18, 32]),
        .init(inputName: "input_16", outputName: "var_778", shape: [1, 1, 4, 32, 128]),
        .init(inputName: "input_17", outputName: "input_tensor_483", shape: [1, 4, 384]),
        .init(inputName: "input_18", outputName: "second_265", shape: [1, 1, 9, 9, 32]),
        .init(inputName: "input_19", outputName: "first_211", shape: [1, 1, 9, 9, 32]),
        .init(inputName: "input_20", outputName: "var_924", shape: [1, 1, 4, 32, 128]),
        .init(inputName: "input_21", outputName: "input_tensor_633", shape: [1, 4, 384]),
        .init(inputName: "input_22", outputName: "second_327", shape: [1, 1, 9, 9, 32]),
        .init(inputName: "input_23", outputName: "first_259", shape: [1, 1, 9, 9, 32]),
        .init(inputName: "input_24", outputName: "var_1061", shape: [1, 1, 4, 32, 128]),
        .init(inputName: "input_25", outputName: "input_tensor_773", shape: [1, 4, 384]),
        .init(inputName: "input_26", outputName: "second_423", shape: [1, 1, 5, 5, 32]),
        .init(inputName: "input_27", outputName: "first_337", shape: [1, 1, 5, 5, 32]),
        .init(inputName: "input_28", outputName: "var_1208", shape: [1, 1, 4, 32, 128]),
        .init(inputName: "input_29", outputName: "input_tensor_981", shape: [1, 4, 384]),
        .init(inputName: "input_30", outputName: "second_485", shape: [1, 1, 5, 5, 32]),
        .init(inputName: "input_31", outputName: "first_385", shape: [1, 1, 5, 5, 32]),
        .init(inputName: "input_32", outputName: "var_1345", shape: [1, 1, 4, 32, 128]),
        .init(inputName: "input_33", outputName: "input_tensor_1121", shape: [1, 4, 384]),
        .init(inputName: "input_34", outputName: "var_1460", shape: [1, 1, 2, 32, 128]),
        .init(inputName: "input_35", outputName: "input_tensor_1305", shape: [1, 4, 320]),
        .init(inputName: "input_36", outputName: "var_1546", shape: [1, 1, 2, 32, 128]),
        .init(inputName: "input_37", outputName: "input_tensor_1393", shape: [1, 4, 320]),
    ]

    private let lock = NSLock()
    private let ciContext = CIContext()

    private var model: MLModel?
    private var stateArrays: [String: MLMultiArray] = [:]
    private var metrics = MetricsState()
    private let warmupFrames = 90

    var onSnapshot: ((RPPGLiveSnapshot) -> Void)?

    var isModelReady: Bool {
        lock.withLock { model != nil }
    }

    var failureReason: RPPGFailureReason? {
        lock.withLock { metrics.failureReason }
    }

    var processedFrameCount: Int {
        lock.withLock { metrics.processedFrameCount }
    }

    var validFrameCount: Int {
        lock.withLock { metrics.validFrameCount }
    }

    var bvpBufferCount: Int {
        lock.withLock { metrics.bvpBuffer.count }
    }

    var lastSnapshot: RPPGLiveSnapshot {
        lock.withLock { makeSnapshotLocked() }
    }

    init() {
        initStates()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadModel()
        }
    }

    func reset() {
        lock.withLock {
            metrics = MetricsState()
        }
        initStates()
        publishSnapshot()
    }

    func processFrame(_ buffer: CMSampleBuffer, dt: Double = 1.0 / 30.0) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }

        let preflightFailure = lock.withLock { () -> RPPGFailureReason? in
            metrics.processedFrameCount += 1
            if #unavailable(iOS 17.0) {
                metrics.failureReason = .unsupportedOS
                return .unsupportedOS
            }
            if model == nil {
                metrics.failureReason = .modelLoadFailed
                return .modelLoadFailed
            }
            return nil
        }

        guard preflightFailure == nil else {
            publishSnapshot()
            return
        }

        guard let patch = extractFacePatch(from: buffer, pixelBuffer: pixelBuffer) else {
            lock.withLock {
                metrics.consecutiveFaceMisses += 1
                if metrics.consecutiveFaceMisses >= Self.maxFaceMissesBeforeFailure {
                    metrics.failureReason = .faceNotFound
                }
            }
            publishSnapshot()
            return
        }

        do {
            let model = lock.withLock { self.model }
            guard let model else {
                lock.withLock { metrics.failureReason = .modelLoadFailed }
                publishSnapshot()
                return
            }

            let input = try buildInput(patch: patch.tensor, dt: dt)
            let output = try model.prediction(from: input)
            updateStates(from: output)

            guard let bvp = output.featureValue(for: Self.bvpOutputName)?.multiArrayValue else {
                lock.withLock { metrics.failureReason = .predictionFailed }
                publishSnapshot()
                return
            }

            let value = Self.readScalar(from: bvp)
            let signal = lock.withLock { () -> [Float] in
                metrics.consecutiveFaceMisses = 0
                metrics.validFrameCount += 1
                metrics.failureReason = nil
                metrics.bvpBuffer.append(value)
                metrics.redMeans.append(patch.redMean)
                metrics.greenMeans.append(patch.greenMean)
                metrics.blueMeans.append(patch.blueMean)
                if metrics.bvpBuffer.count > Self.maxBVPBufferSize {
                    metrics.bvpBuffer.removeFirst(metrics.bvpBuffer.count - Self.maxBVPBufferSize)
                    metrics.redMeans.removeFirst(metrics.redMeans.count - metrics.bvpBuffer.count)
                    metrics.greenMeans.removeFirst(metrics.greenMeans.count - metrics.bvpBuffer.count)
                    metrics.blueMeans.removeFirst(metrics.blueMeans.count - metrics.bvpBuffer.count)
                }
                return metrics.bvpBuffer
            }

            updateLiveMetricsIfNeeded(signal: signal)
        } catch {
            lock.withLock {
                metrics.failureReason = .predictionFailed
            }
        }

        publishSnapshot()
    }

    func finalizeResult() -> AnalyzeResponse? {
        let state = lock.withLock { metrics }
        if state.failureReason == .unsupportedOS || state.failureReason == .modelLoadFailed {
            return nil
        }

        guard state.validFrameCount >= Self.minResultFrames else {
            lock.withLock { metrics.failureReason = .insufficientFrames }
            publishSnapshot()
            return nil
        }

        let fullSignal = state.bvpBuffer
        let analysisSignal: [Float]
        if fullSignal.count - warmupFrames >= Self.minResultFrames {
            analysisSignal = Array(fullSignal.dropFirst(warmupFrames))
        } else {
            analysisSignal = fullSignal
        }

        let hr = estimateHR(from: analysisSignal, fps: Self.fps)
        guard hr.isFinite, hr > 0 else {
            lock.withLock { metrics.failureReason = .predictionFailed }
            publishSnapshot()
            return nil
        }

        let sqi = estimateSignalQuality(from: analysisSignal, hr: hr, fps: Self.fps)
        guard sqi >= Self.minimumSQI else {
            lock.withLock {
                metrics.latestHR = hr
                metrics.latestSQI = sqi
                metrics.latestConfidence = confidenceText(for: sqi)
                metrics.failureReason = .lowSignalQuality
            }
            publishSnapshot()
            return nil
        }

        let hrStatus: String
        switch hr {
        case ..<60:
            hrStatus = "偏低"
        case 60...100:
            hrStatus = "正常"
        default:
            hrStatus = "偏高"
        }

        lock.withLock {
            metrics.latestHR = hr
            metrics.latestSQI = sqi
            metrics.latestConfidence = confidenceText(for: sqi)
            metrics.failureReason = nil
        }
        publishSnapshot()

        let rr = estimateRespirationRate(from: analysisSignal, fps: Self.fps)
        let spo2 = estimateSpO2(redMeans: state.redMeans, blueMeans: state.blueMeans, fps: Self.fps)
        let (stressScore, stressLevel) = estimateStress(from: analysisSignal, fps: Self.fps)

        return AnalyzeResponse(
            hr: hr,
            hrStatus: hrStatus,
            rr: rr,
            rrStatus: rr.map(respirationStatus(for:)),
            spo2: spo2,
            spo2Status: spo2.map(spo2Status(for:)),
            stressScore: stressScore,
            stressLevel: stressLevel,
            sqi: sqi,
            confidence: confidenceText(for: sqi),
            skinLabel: nil,
            skinI18n: nil
        )
    }

    private func loadModel() {
        guard #available(iOS 17.0, *) else {
            lock.withLock {
                model = nil
                metrics.failureReason = .unsupportedOS
            }
            initStates()
            publishSnapshot()
            return
        }

        do {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            let loadedModel: MLModel?

            if let url = Bundle.main.url(forResource: "rppg_model", withExtension: "mlmodelc") {
                loadedModel = try MLModel(contentsOf: url, configuration: configuration)
            } else if let packageURL = locateModelPackage() {
                let compiledURL = try MLModel.compileModel(at: packageURL)
                loadedModel = try MLModel(contentsOf: compiledURL, configuration: configuration)
            } else {
                loadedModel = nil
            }

            lock.withLock {
                self.model = loadedModel
                metrics.failureReason = loadedModel == nil ? .modelLoadFailed : nil
            }
        } catch {
            lock.withLock {
                model = nil
                metrics.failureReason = .modelLoadFailed
            }
        }

        initStates()
        publishSnapshot()
    }

    private func locateModelPackage() -> URL? {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "rppg_model", withExtension: "mlpackage"),
            Bundle.main.url(forResource: "rppg_model", withExtension: "mlpackage", subdirectory: "Resources"),
            Bundle.main.resourceURL?.appendingPathComponent("rppg_model.mlpackage"),
            Bundle.main.resourceURL?.appendingPathComponent("Resources/rppg_model.mlpackage")
        ]

        return candidates
            .compactMap { $0 }
            .first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }

    private func initStates() {
        var states: [String: MLMultiArray] = [:]
        for spec in Self.stateSpecs {
            if let array = try? Self.makeZeroArray(shape: spec.shape) {
                states[spec.inputName] = array
            }
        }

        lock.withLock {
            stateArrays = states
        }
    }

    private func extractFacePatch(from sampleBuffer: CMSampleBuffer, pixelBuffer: CVPixelBuffer) -> FacePatch? {
        guard #available(iOS 17.0, *) else { return nil }

        guard let boundingBox = detectLargestFace(in: sampleBuffer) else { return nil }
        let expanded = expandedBoundingBox(from: boundingBox)
        return cropPatch(from: pixelBuffer, normalizedBoundingBox: expanded)
    }

    @available(iOS 17.0, *)
    private func detectLargestFace(in sampleBuffer: CMSampleBuffer) -> CGRect? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .leftMirrored, options: [:])

        do {
            try handler.perform([request])
            let observations = request.results ?? []
            return observations
                .map(\.boundingBox)
                .max(by: { ($0.width * $0.height) < ($1.width * $1.height) })
        } catch {
            return nil
        }
    }

    private func expandedBoundingBox(from normalizedBoundingBox: CGRect) -> CGRect {
        let expandX = normalizedBoundingBox.width * Self.roiExpansionRatio
        let expandY = normalizedBoundingBox.height * Self.roiExpansionRatio
        return CGRect(
            x: max(0, normalizedBoundingBox.origin.x - expandX * 0.5),
            y: max(0, normalizedBoundingBox.origin.y - expandY * 0.5),
            width: min(1, normalizedBoundingBox.width + expandX),
            height: min(1, normalizedBoundingBox.height + expandY)
        ).standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    @available(iOS 17.0, *)
    private func cropPatch(from pixelBuffer: CVPixelBuffer, normalizedBoundingBox: CGRect) -> FacePatch? {
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        guard width > 0, height > 0 else { return nil }

        let cropRect = CGRect(
            x: normalizedBoundingBox.origin.x * width,
            y: (1 - normalizedBoundingBox.origin.y - normalizedBoundingBox.height) * height,
            width: normalizedBoundingBox.width * width,
            height: normalizedBoundingBox.height * height
        ).integral

        guard cropRect.width >= 1, cropRect.height >= 1 else { return nil }

        let scaleX = CGFloat(Self.patchSize) / cropRect.width
        let scaleY = CGFloat(Self.patchSize) / cropRect.height
        let image = CIImage(cvPixelBuffer: pixelBuffer)
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var rgba = [UInt8](repeating: 0, count: Self.patchSize * Self.patchSize * 4)
        ciContext.render(
            image,
            toBitmap: &rgba,
            rowBytes: Self.patchSize * 4,
            bounds: CGRect(x: 0, y: 0, width: Self.patchSize, height: Self.patchSize),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        guard let array = try? MLMultiArray(
            shape: Self.frameShape.map(NSNumber.init(value:)),
            dataType: .float16
        ) else {
            return nil
        }

        let pointer = array.dataPointer.bindMemory(to: UInt16.self, capacity: array.count)
        let strides = array.strides.map(\.intValue)
        let heightStride = strides[2]
        let widthStride = strides[3]
        let channelStride = strides[4]
        var redSum: Float = 0
        var greenSum: Float = 0
        var blueSum: Float = 0

        for row in 0..<Self.patchSize {
            for col in 0..<Self.patchSize {
                let sourceIndex = (row * Self.patchSize + col) * 4
                let baseIndex = row * heightStride + col * widthStride
                let rValue = Float(rgba[sourceIndex]) / 255.0
                let gValue = Float(rgba[sourceIndex + 1]) / 255.0
                let bValue = Float(rgba[sourceIndex + 2]) / 255.0
                let r = Self.encodeFloat16(rValue)
                let g = Self.encodeFloat16(gValue)
                let b = Self.encodeFloat16(bValue)

                pointer[baseIndex] = r
                pointer[baseIndex + channelStride] = g
                pointer[baseIndex + channelStride * 2] = b
                redSum += rValue
                greenSum += gValue
                blueSum += bValue
            }
        }

        let pixelCount = Float(Self.patchSize * Self.patchSize)
        return FacePatch(
            tensor: array,
            redMean: redSum / pixelCount,
            greenMean: greenSum / pixelCount,
            blueMean: blueSum / pixelCount
        )
    }

    private func buildInput(patch: MLMultiArray, dt: Double) throws -> MLDictionaryFeatureProvider {
        var features: [String: MLFeatureValue] = [:]
        features[Self.frameInputName] = MLFeatureValue(multiArray: patch)

        let states = lock.withLock { stateArrays }
        for spec in Self.stateSpecs {
            guard let state = states[spec.inputName] else { continue }
            features[spec.inputName] = MLFeatureValue(multiArray: state)
        }

        let dtArray = try Self.makeScalarArray(value: Float(dt))
        features[Self.dtInputName] = MLFeatureValue(multiArray: dtArray)
        return try MLDictionaryFeatureProvider(dictionary: features)
    }

    private func updateStates(from output: MLFeatureProvider) {
        lock.withLock {
            for spec in Self.stateSpecs {
                if let updated = output.featureValue(for: spec.outputName)?.multiArrayValue {
                    stateArrays[spec.inputName] = updated
                }
            }
        }
    }

    private func updateLiveMetricsIfNeeded(signal: [Float]) {
        guard signal.count >= Self.minResultFrames else { return }

        let hr = estimateHR(from: signal, fps: Self.fps)
        guard hr.isFinite, hr > 0 else { return }
        let sqi = estimateSignalQuality(from: signal, hr: hr, fps: Self.fps)

        lock.withLock {
            metrics.latestHR = hr
            metrics.latestSQI = sqi
            metrics.latestConfidence = confidenceText(for: sqi)
            if sqi < Self.minimumSQI {
                metrics.failureReason = .lowSignalQuality
            } else if metrics.failureReason == .lowSignalQuality {
                metrics.failureReason = nil
            }
        }
    }

    private func publishSnapshot() {
        let snapshot = lock.withLock { makeSnapshotLocked() }
        DispatchQueue.main.async { [weak self] in
            self?.onSnapshot?(snapshot)
        }
    }

    private func makeSnapshotLocked() -> RPPGLiveSnapshot {
        RPPGLiveSnapshot(
            hr: metrics.latestHR,
            sqi: metrics.latestSQI,
            confidence: metrics.latestConfidence,
            processedFrameCount: metrics.processedFrameCount,
            validFrameCount: metrics.validFrameCount,
            progress: min(Double(metrics.validFrameCount) / Double(Self.minResultFrames), 1),
            failureReason: metrics.failureReason
        )
    }

    private func estimateHR(from signal: [Float], fps: Double) -> Double {
        guard signal.count >= 128 else { return 72.0 }

        var processedSignal = signal
        let mean = vDSP.mean(processedSignal)
        vDSP.add(-mean, processedSignal, result: &processedSignal)

        var processedSignalWithWindow = [Float](repeating: 0, count: processedSignal.count)
        for i in 0..<processedSignal.count {
            let multiplier = 0.5 * (1 - cos(2 * Float.pi * Float(i) / Float(processedSignal.count - 1)))
            processedSignalWithWindow[i] = processedSignal[i] * multiplier
        }

        let fftSize = Self.nextPowerOfTwo(max(processedSignalWithWindow.count, 2))
        var fftInput = processedSignalWithWindow
        if fftInput.count < fftSize {
            fftInput.append(contentsOf: repeatElement(Float(0), count: fftSize - fftInput.count))
        }

        var real = fftInput
        var imag = [Float](repeating: 0, count: fftSize)
        let log2n = vDSP_Length(Int(log2(Double(fftSize))))

        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return 72.0
        }
        defer { vDSP_destroy_fftsetup(setup) }

        real.withUnsafeMutableBufferPointer { realBuffer in
            imag.withUnsafeMutableBufferPointer { imagBuffer in
                guard let realBaseAddress = realBuffer.baseAddress,
                      let imagBaseAddress = imagBuffer.baseAddress else { return }
                var splitComplex = DSPSplitComplex(realp: realBaseAddress, imagp: imagBaseAddress)
                vDSP_fft_zip(setup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }

        let freqResolution = fps / Double(fftSize)
        let lowBin = max(1, Int(0.7 / freqResolution))
        let highBin = min(Int(4.0 / freqResolution), fftSize / 2 - 1)
        guard lowBin <= highBin else { return 72.0 }

        var maxPower: Float = 0
        var maxBin = lowBin

        for bin in lowBin...highBin {
            let power = real[bin] * real[bin] + imag[bin] * imag[bin]
            if power > maxPower {
                maxPower = power
                maxBin = bin
            }
        }

        guard maxPower > 0 else { return 72.0 }
        return Double(maxBin) * freqResolution * 60.0
    }

    private func estimateSignalQuality(from signal: [Float], hr: Double, fps: Double) -> Double {
        guard signal.count >= 2 else { return 0.2 }

        let targetFrequency = hr / 60.0
        let mean = signal.reduce(0, +) / Float(signal.count)
        let centered = signal.map { $0 - mean }
        let energy = centered.reduce(0) { $0 + $1 * $1 }
        guard energy > 0 else { return 0.2 }

        let phaseStep = Float(2.0 * .pi * targetFrequency / fps)
        var projectionSin: Float = 0
        var projectionCos: Float = 0

        for (index, value) in centered.enumerated() {
            let phase = phaseStep * Float(index)
            projectionSin += value * sin(phase)
            projectionCos += value * cos(phase)
        }

        let targetEnergy = projectionSin * projectionSin + projectionCos * projectionCos
        return min(max(Double(targetEnergy / energy), 0), 1)
    }

    private func confidenceText(for sqi: Double) -> String {
        switch sqi {
        case 0.7...:
            return "高"
        case 0.35...:
            return "中等"
        default:
            return "低"
        }
    }

    private func estimateRespirationRate(from signal: [Float], fps: Double) -> Double? {
        guard let prepared = prepareRespirationSignal(from: signal, fps: fps) else { return nil }

        let spectrum = powerSpectrum(of: prepared, fps: fps)
        guard let peak = dominantFrequency(in: spectrum, range: 0.15...0.40) else { return nil }

        let bandPowers = spectrum.filter { 0.15...0.40 ~= $0.frequency }.map(\.power)
        guard let averagePower = bandPowers.nonEmptyAverage, peak.power >= averagePower * 1.5 else {
            return nil
        }

        return round(peak.frequency * 60.0 * 10) / 10
    }

    private func estimateStress(from signal: [Float], fps: Double) -> (Double?, String?) {
        guard let prepared = prepareRespirationSignal(from: signal, fps: fps) else { return (nil, nil) }

        let spectrum = powerSpectrum(of: prepared, fps: fps)
        let rrBand = spectrum.filter { 0.15...0.40 ~= $0.frequency }.map(\.power)
        guard let averagePower = rrBand.nonEmptyAverage,
              averagePower > 1e-10,
              let peak = dominantFrequency(in: spectrum, range: 0.15...0.40) else {
            return (nil, nil)
        }

        let rsaRatio = peak.power / averagePower
        let score = max(0, min(100, (4.0 - rsaRatio) / 2.5 * 100))
        let rounded = round(score * 10) / 10

        switch rounded {
        case ..<30:
            return (rounded, "低压力")
        case 30..<60:
            return (rounded, "正常")
        default:
            return (rounded, "高压力")
        }
    }

    private func estimateSpO2(redMeans: [Float], blueMeans: [Float], fps: Double) -> Double? {
        let red = trimmedSignal(from: redMeans)
        let blue = trimmedSignal(from: blueMeans)
        guard red.count >= Self.minResultFrames, blue.count == red.count else { return nil }

        let dcRed = red.reduce(0, +) / Float(red.count)
        let dcBlue = blue.reduce(0, +) / Float(blue.count)
        guard dcRed > 1e-6, dcBlue > 1e-6 else { return nil }

        let detrendedRed = detrendedSignal(red)
        let detrendedBlue = detrendedSignal(blue)
        let nyquistHigh = min(2.5, fps / 2.0 - 0.1)
        guard nyquistHigh > 0.6 else { return nil }

        let acRed = standardDeviation(of: bandpassedSignal(detrendedRed, fps: fps, low: 0.6, high: nyquistHigh))
        let acBlue = standardDeviation(of: bandpassedSignal(detrendedBlue, fps: fps, low: 0.6, high: nyquistHigh))
        guard acRed > 1e-6, acBlue > 1e-6 else { return nil }

        let ratio = (acRed / Double(dcRed)) / (acBlue / Double(dcBlue))
        let spo2 = pow(0.01 * (110.0 - 25.0 * ratio), 0.3) * 100.0
        guard spo2.isFinite else { return nil }
        return round(max(70.0, min(100.0, spo2)) * 10) / 10
    }

    private func prepareRespirationSignal(from signal: [Float], fps: Double) -> [Float]? {
        guard signal.count >= 300 else { return nil }

        let detrended = detrendedSignal(signal)
        let normalized = zScoreNormalizedSignal(detrended)
        guard normalized.contains(where: { abs($0) > 1e-6 }) else { return nil }

        return lowPassSignal(normalized, fps: fps, cutoff: 5.0)
    }

    private func respirationStatus(for rr: Double) -> String {
        switch rr {
        case ..<12:
            return "偏低"
        case 12...20:
            return "正常"
        default:
            return "偏高"
        }
    }

    private func spo2Status(for spo2: Double) -> String {
        switch spo2 {
        case 95...:
            return "正常"
        case 90..<95:
            return "偏低"
        default:
            return "危险"
        }
    }

    private func trimmedSignal(from values: [Float]) -> [Float] {
        if values.count - warmupFrames >= Self.minResultFrames {
            return Array(values.dropFirst(warmupFrames))
        }
        return values
    }

    private func detrendedSignal(_ signal: [Float]) -> [Float] {
        guard signal.count >= 2 else { return signal }

        let count = Double(signal.count)
        let xMean = (count - 1.0) / 2.0
        let yMean = Double(signal.reduce(0, +)) / count

        var numerator = 0.0
        var denominator = 0.0
        for (index, value) in signal.enumerated() {
            let x = Double(index) - xMean
            numerator += x * (Double(value) - yMean)
            denominator += x * x
        }

        let slope = denominator > 1e-12 ? numerator / denominator : 0.0
        let intercept = yMean - slope * xMean

        return signal.enumerated().map { index, value in
            Float(Double(value) - (slope * Double(index) + intercept))
        }
    }

    private func zScoreNormalizedSignal(_ signal: [Float]) -> [Float] {
        let std = standardDeviation(of: signal)
        guard std > 1e-6 else { return signal.map { _ in 0 } }
        let mean = signal.reduce(0, +) / Float(signal.count)
        return signal.map { Float((Double($0 - mean)) / std) }
    }

    private func lowPassSignal(_ signal: [Float], fps: Double, cutoff: Double) -> [Float] {
        guard signal.count >= 8 else { return signal }
        let spectrum = powerSpectrum(of: signal, fps: fps)
        let filtered = spectrum.map { sample -> ComplexSample in
            if sample.frequency <= cutoff {
                return sample
            }
            return ComplexSample(frequency: sample.frequency, real: 0, imag: 0, power: 0)
        }
        return inverseSpectrum(filtered, signalCount: signal.count)
    }

    private func bandpassedSignal(_ signal: [Float], fps: Double, low: Double, high: Double) -> [Float] {
        guard signal.count >= 8 else { return signal }
        let spectrum = powerSpectrum(of: signal, fps: fps)
        let filtered = spectrum.map { sample -> ComplexSample in
            if low...high ~= sample.frequency {
                return sample
            }
            return ComplexSample(frequency: sample.frequency, real: 0, imag: 0, power: 0)
        }
        return inverseSpectrum(filtered, signalCount: signal.count)
    }

    private func powerSpectrum(of signal: [Float], fps: Double) -> [ComplexSample] {
        let fftSize = Self.nextPowerOfTwo(max(signal.count, 2))
        var fftInput = signal
        if fftInput.count < fftSize {
            fftInput.append(contentsOf: repeatElement(Float(0), count: fftSize - fftInput.count))
        }

        var real = fftInput
        var imag = [Float](repeating: 0, count: fftSize)
        let log2n = vDSP_Length(Int(log2(Double(fftSize))))

        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(setup) }

        real.withUnsafeMutableBufferPointer { realBuffer in
            imag.withUnsafeMutableBufferPointer { imagBuffer in
                guard let realBaseAddress = realBuffer.baseAddress,
                      let imagBaseAddress = imagBuffer.baseAddress else { return }
                var splitComplex = DSPSplitComplex(realp: realBaseAddress, imagp: imagBaseAddress)
                vDSP_fft_zip(setup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }

        let resolution = fps / Double(fftSize)
        return (0..<(fftSize / 2)).map { bin in
            let realPart = real[bin]
            let imagPart = imag[bin]
            let power = Double(realPart * realPart + imagPart * imagPart)
            return ComplexSample(
                frequency: Double(bin) * resolution,
                real: realPart,
                imag: imagPart,
                power: power
            )
        }
    }

    private func dominantFrequency(in spectrum: [ComplexSample], range: ClosedRange<Double>) -> ComplexSample? {
        spectrum
            .filter { range.contains($0.frequency) }
            .max(by: { $0.power < $1.power })
    }

    private func inverseSpectrum(_ spectrum: [ComplexSample], signalCount: Int) -> [Float] {
        let fftSize = Self.nextPowerOfTwo(max(signalCount, 2))
        var real = [Float](repeating: 0, count: fftSize)
        var imag = [Float](repeating: 0, count: fftSize)

        for (index, sample) in spectrum.enumerated() where index < fftSize / 2 {
            real[index] = sample.real
            imag[index] = sample.imag
            if index > 0 {
                let mirrored = fftSize - index
                real[mirrored] = sample.real
                imag[mirrored] = -sample.imag
            }
        }

        let log2n = vDSP_Length(Int(log2(Double(fftSize))))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return Array(real.prefix(signalCount)) }
        defer { vDSP_destroy_fftsetup(setup) }

        real.withUnsafeMutableBufferPointer { realBuffer in
            imag.withUnsafeMutableBufferPointer { imagBuffer in
                guard let realBaseAddress = realBuffer.baseAddress,
                      let imagBaseAddress = imagBuffer.baseAddress else { return }
                var splitComplex = DSPSplitComplex(realp: realBaseAddress, imagp: imagBaseAddress)
                vDSP_fft_zip(setup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Inverse))
            }
        }

        let scale = Float(1.0 / Double(fftSize))
        return real.prefix(signalCount).map { $0 * scale }
    }

    private func standardDeviation(of signal: [Float]) -> Double {
        guard signal.count > 1 else { return 0 }
        let mean = signal.reduce(0, +) / Float(signal.count)
        let variance = signal.reduce(0) { partial, value in
            let delta = value - mean
            return partial + delta * delta
        } / Float(signal.count)
        return Double(sqrt(variance))
    }

    private static func makeZeroArray(shape: [Int]) throws -> MLMultiArray {
        guard #available(iOS 17.0, *) else {
            throw NSError(domain: "RPPGInferenceService", code: -1, userInfo: nil)
        }

        let array = try MLMultiArray(shape: shape.map(NSNumber.init(value:)), dataType: .float16)
        memset(array.dataPointer, 0, array.count * MemoryLayout<UInt16>.size)
        return array
    }

    private static func makeScalarArray(value: Float) throws -> MLMultiArray {
        guard #available(iOS 17.0, *) else {
            throw NSError(domain: "RPPGInferenceService", code: -2, userInfo: nil)
        }

        let array = try MLMultiArray(shape: [1 as NSNumber], dataType: .float16)
        array.dataPointer.bindMemory(to: UInt16.self, capacity: 1)[0] = encodeFloat16(value)
        return array
    }

    private static func readScalar(from tensor: MLMultiArray) -> Float {
        switch tensor.dataType {
        case .float16:
            let bits = tensor.dataPointer.bindMemory(to: UInt16.self, capacity: tensor.count)[0]
            return Float(decodeFloat16(bits))
        case .float32:
            return tensor.dataPointer.bindMemory(to: Float.self, capacity: tensor.count)[0]
        case .double:
            return Float(tensor.dataPointer.bindMemory(to: Double.self, capacity: tensor.count)[0])
        default:
            return tensor[0].floatValue
        }
    }

    private static func nextPowerOfTwo(_ value: Int) -> Int {
        var result = 1
        while result < value {
            result <<= 1
        }
        return result
    }

    private static func encodeFloat16(_ value: Float) -> UInt16 {
        let bits = value.bitPattern
        let sign = UInt16((bits >> 16) & 0x8000)
        var exponent = Int((bits >> 23) & 0xFF) - 127 + 15
        var mantissa = bits & 0x007FFFFF

        if exponent <= 0 {
            if exponent < -10 { return sign }
            mantissa |= 0x00800000
            let shift = UInt32(14 - exponent)
            let rounded = (mantissa >> shift) + ((mantissa >> (shift - 1)) & 1)
            return sign | UInt16(rounded)
        }

        if exponent >= 0x1F {
            return sign | (mantissa == 0 ? 0x7C00 : 0x7E00)
        }

        mantissa += 0x1000
        if mantissa & 0x00800000 != 0 {
            mantissa = 0
            exponent += 1
        }

        if exponent >= 0x1F {
            return sign | 0x7C00
        }

        return sign | UInt16(exponent << 10) | UInt16(mantissa >> 13)
    }

    private static func decodeFloat16(_ bitPattern: UInt16) -> Double {
        let sign = UInt32(bitPattern & 0x8000) << 16
        let exponent = Int((bitPattern >> 10) & 0x1F)
        let mantissa = UInt32(bitPattern & 0x03FF)
        let floatBits: UInt32

        if exponent == 0 {
            if mantissa == 0 {
                floatBits = sign
            } else {
                var normalizedMantissa = mantissa
                var normalizedExponent = -14

                while normalizedMantissa & 0x0400 == 0 {
                    normalizedMantissa <<= 1
                    normalizedExponent -= 1
                }
                normalizedMantissa &= 0x03FF
                let finalExponent = UInt32(normalizedExponent + 127)
                floatBits = sign | (finalExponent << 23) | (normalizedMantissa << 13)
            }
        } else if exponent == 0x1F {
            floatBits = sign | 0x7F800000 | (mantissa << 13)
        } else {
            let finalExponent = UInt32(exponent - 15 + 127)
            floatBits = sign | (finalExponent << 23) | (mantissa << 13)
        }

        return Double(Float(bitPattern: floatBits))
    }
}

private extension NSLock {
    @discardableResult
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

private extension Array where Element == Double {
    var nonEmptyAverage: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
