import Foundation
import Combine
import UIKit
import Vision

struct RespiratoryRateResult {
    let bpm: Double?
    let qualityScore: Double
    let isReliable: Bool
    let buffering: Bool
    let filteredSignal: [Double]
}

final class RespiratoryRateEstimator {

    private let resultsSubject = PassthroughSubject<RespiratoryRateResult, Never>()
    var results: AnyPublisher<RespiratoryRateResult, Never> {
        resultsSubject.eraseToAnyPublisher()
    }

    private let sampleRate: Double = 7.5
    private let minBufferSeconds: Double = 20.0
    private var minBufferSize: Int { Int(sampleRate * minBufferSeconds) }

    private var signalBuffer: [(timestamp: Date, value: Double)] = []
    private let bandpass: ButterworthBandpass
    private let welch: WelchEstimator

    private let processingQueue = DispatchQueue(label: "com.vvewell.rr.estimator", qos: .userInitiated)
    private var lastEmitTime: Date = .distantPast
    private let emitInterval: TimeInterval = 2.0

    init() {
        bandpass = ButterworthBandpass(sampleRate: sampleRate, lowCut: 0.1, highCut: 0.5, order: 4)
        welch = WelchEstimator(sampleRate: sampleRate, windowSize: 150, overlap: 0.5)
    }

    func processFrame(_ image: UIImage) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            guard let roiValue = self.extractNostrilROI(from: image) else { return }

            self.signalBuffer.append((Date(), roiValue))

            let maxBuffer = Int(self.sampleRate * 40)
            if self.signalBuffer.count > maxBuffer {
                self.signalBuffer.removeFirst(self.signalBuffer.count - maxBuffer)
            }

            let now = Date()
            if now.timeIntervalSince(self.lastEmitTime) >= self.emitInterval {
                self.lastEmitTime = now
                self.estimateAndEmit()
            }
        }
    }

    func reset() {
        signalBuffer.removeAll()
        bandpass.reset()
    }

    // MARK: - ROI Extraction

    private func extractNostrilROI(from image: UIImage) -> Double? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let face = request.results?.first,
              let landmarks = face.landmarks,
              let nose = landmarks.nose else {
            return extractCenterROI(from: image)
        }

        let boundingBox = face.boundingBox
        let nosePoints = nose.normalizedPoints

        guard !nosePoints.isEmpty else {
            return extractCenterROI(from: image)
        }

        let imgWidth = CGFloat(cgImage.width)
        let imgHeight = CGFloat(cgImage.height)

        let noseRect = nosePoints.reduce(CGRect.null) { rect, point in
            let pixelX = point.x * imgWidth
            let pixelY = (1 - point.y) * imgHeight
            return rect.union(CGRect(x: pixelX, y: pixelY, width: 1, height: 1))
        }

        let expandedRect = noseRect.insetBy(dx: -noseRect.width * 0.5, dy: -noseRect.height * 0.5)
        let clampedRect = expandedRect.intersection(CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
        guard !clampedRect.isNull else { return nil }

        return computeMeanIntensity(in: clampedRect, from: cgImage)
    }

    private func extractCenterROI(from image: UIImage) -> Double? {
        guard let cgImage = image.cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let roiWidth = width * 0.15
        let roiHeight = height * 0.1
        let rect = CGRect(
            x: (width - roiWidth) / 2,
            y: (height - roiHeight) / 2,
            width: roiWidth,
            height: roiHeight
        )
        return computeMeanIntensity(in: rect, from: cgImage)
    }

    private func computeMeanIntensity(in rect: CGRect, from cgImage: CGImage) -> Double? {
        let intRect = CGRect(
            x: max(0, Int(rect.origin.x)),
            y: max(0, Int(rect.origin.y)),
            width: min(Int(rect.width), cgImage.width - Int(rect.origin.x)),
            height: min(Int(rect.height), cgImage.height - Int(rect.origin.y))
        )
        guard intRect.width > 0, intRect.height > 0 else { return nil }

        guard let cropped = cgImage.cropping(to: intRect) else { return nil }
        let croppedImage = UIImage(cgImage: cropped)

        guard let pixelData = croppedImage.pixelData() else { return nil }

        var sum: Double = 0
        for pixel in pixelData {
            let gray = 0.299 * Double(pixel.r) + 0.587 * Double(pixel.g) + 0.114 * Double(pixel.b)
            sum += gray
        }
        return sum / Double(pixelData.count)
    }

    // MARK: - Estimation

    private func estimateAndEmit() {
        guard signalBuffer.count >= minBufferSize else {
            emitResult(RespiratoryRateResult(
                bpm: nil,
                qualityScore: 0,
                isReliable: false,
                buffering: true,
                filteredSignal: []
            ))
            return
        }

        let rawSignal = resampleSignal(signalBuffer)

        let filtered = bandpass.process(rawSignal)

        let spectralResult = welch.estimate(from: filtered)

        let timeDomainBpm = estimatePeakBased(from: filtered)

        var bpm: Double? = nil
        var qualityScore: Double = 0
        var isReliable = false

        if let spectral = spectralResult {
            let spectralBpm = spectral.dominantFreq * 60

            if let timeBpm = timeDomainBpm {
                let diff = abs(spectralBpm - timeBpm)
                if diff < 3.0 {
                    bpm = (spectralBpm + timeBpm) / 2
                    qualityScore = min(1.0, spectral.spectralConcentration * 2)
                    isReliable = qualityScore > 0.3
                } else {
                    bpm = spectralBpm
                    qualityScore = spectral.spectralConcentration
                    isReliable = qualityScore > 0.5
                }
            } else {
                bpm = spectralBpm
                qualityScore = spectral.spectralConcentration
                isReliable = qualityScore > 0.5
            }
        }

        let displaySignal = Array(filtered.suffix(225))

        emitResult(RespiratoryRateResult(
            bpm: bpm,
            qualityScore: qualityScore,
            isReliable: isReliable,
            buffering: false,
            filteredSignal: displaySignal
        ))
    }

    private func resampleSignal(_ buffer: [(timestamp: Date, value: Double)]) -> [Double] {
        guard let first = buffer.first, let last = buffer.last else { return [] }
        let duration = last.timestamp.timeIntervalSince(first.timestamp)
        guard duration > 0 else { return buffer.map { $0.value } }

        let targetCount = Int(duration * sampleRate)
        guard targetCount > 1 else { return buffer.map { $0.value } }

        var result = [Double](repeating: 0, count: targetCount)
        for i in 0..<targetCount {
            let targetTime = first.timestamp.addingTimeInterval(Double(i) / sampleRate)
            let nearest = buffer.min(by: { abs($0.timestamp.timeIntervalSince(targetTime)) < abs($1.timestamp.timeIntervalSince(targetTime)) })
            result[i] = nearest?.value ?? 0
        }
        return result
    }

    private func estimatePeakBased(from signal: [Double]) -> Double? {
        guard signal.count > 10 else { return nil }

        let mean = signal.reduce(0, +) / Double(signal.count)
        let threshold = mean

        var peaks: [Int] = []
        for i in 1..<(signal.count - 1) {
            if signal[i] > threshold && signal[i] > signal[i-1] && signal[i] >= signal[i+1] {
                peaks.append(i)
            }
        }

        guard peaks.count >= 2 else { return nil }

        var intervals: [Double] = []
        for i in 1..<peaks.count {
            intervals.append(Double(peaks[i] - peaks[i-1]) / sampleRate)
        }

        let medianInterval = intervals.sorted()[intervals.count / 2]
        guard medianInterval > 0 else { return nil }

        return 60.0 / medianInterval
    }

    private func emitResult(_ result: RespiratoryRateResult) {
        DispatchQueue.main.async { [weak self] in
            self?.resultsSubject.send(result)
        }
    }
}

// MARK: - UIImage Pixel Data Extension

private struct PixelData {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

private extension UIImage {
    func pixelData() -> [PixelData]? {
        guard let cgImage = self.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var result: [PixelData] = []
        result.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                result.append(PixelData(r: pixelData[offset], g: pixelData[offset+1], b: pixelData[offset+2]))
            }
        }
        return result
    }
}
