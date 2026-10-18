import AVFoundation
import UIKit

/// 管理前置摄像头捕获会话，提供预览层、录制控制与亮度检测
final class CameraManager: NSObject {

    // MARK: - 公开属性

    /// 相机预览层，供 VC 挂载到容器 View
    private(set) lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    /// 低亮度警告回调（主线程）；true = 环境过暗
    var onLowLightWarning: ((Bool) -> Void)?

    /// 视频帧输出回调（数据输出线程）
    var onVideoFrame: ((CMSampleBuffer) -> Void)?

    // MARK: - 私有属性

    private let captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()

    private let sessionQueue = DispatchQueue(label: "com.vvewell.camera.session")
    private let dataOutputQueue = DispatchQueue(label: "com.vvewell.camera.data")
    private let ciContext = CIContext()

    private enum RecordingState { case idle, starting, recording, stopping }
    private var recordingState: RecordingState = .idle

    private var recordingCompletion: ((URL?) -> Void)?
    private var recordingTimer: Timer?

    // MARK: - 权限

    deinit {
        recordingTimer?.invalidate()
    }

    /// 请求相机权限；completion 在主线程回调
    /// - Parameter completion: 是否已授权
    func requestPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { completion(true) }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            DispatchQueue.main.async { completion(false) }
        }
    }

    // MARK: - 会话控制

    /// 配置并启动捕获会话（非阻塞）
    func setupAndStart() {
        sessionQueue.async { [weak self] in
            self?.configureCaptureSession()
            self?.captureSession.startRunning()
        }
    }

    /// 停止捕获会话
    func stopSession() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.movieOutput.isRecording {
                self.setRecordingState(.stopping)
                self.movieOutput.stopRecording()
            }
            self.captureSession.stopRunning()
        }
    }

    // MARK: - 录制控制

    /// 开始录制到临时目录，duration 秒后自动停止
    /// - Parameters:
    ///   - duration: 录制时长（秒），默认 60
    ///   - completion: 完成后返回视频 URL；失败返回 nil（主线程）
    func startRecording(duration: TimeInterval = 60, completion: @escaping (URL?) -> Void) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("health_\(UUID().uuidString).mp4")
        sessionQueue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard self.currentRecordingState() == .idle else { return }
            guard self.captureSession.isRunning,
                  self.captureSession.outputs.contains(self.movieOutput),
                  !self.movieOutput.isRecording else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.setRecordingState(.recording)
            self.recordingCompletion = completion
            self.movieOutput.startRecording(to: tempURL, recordingDelegate: self)
            DispatchQueue.main.async { [weak self] in
                self?.recordingTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    self?.stopRecording()
                }
            }
        }
    }

    /// 提前停止录制
    func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        sessionQueue.async { [weak self] in
            guard let self, self.currentRecordingState() == .recording,
                  self.movieOutput.isRecording else { return }
            self.setRecordingState(.stopping)
            self.movieOutput.stopRecording()
        }
    }

    // MARK: - 私有：会话配置

    private func configureCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium

        // 前置摄像头输入
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        // 视频数据输出（亮度检测）
        videoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        // 文件录制输出
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }

        captureSession.commitConfiguration()
    }

    private func currentRecordingState() -> RecordingState {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        return recordingState
    }

    private func setRecordingState(_ newValue: RecordingState) {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        recordingState = newValue
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let url: URL? = error == nil ? outputFileURL : nil
            self.setRecordingState(.idle)
            let completion = self.recordingCompletion
            self.recordingCompletion = nil
            DispatchQueue.main.async {
                completion?(url)
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate（亮度检测）

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
        ]), let output = filter.outputImage else { return }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(output,
                           toBitmap: &bitmap,
                           rowBytes: 4,
                           bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBA8,
                           colorSpace: CGColorSpaceCreateDeviceRGB())

        let brightness = Float(bitmap[0]) * 0.299 / 255
                       + Float(bitmap[1]) * 0.587 / 255
                       + Float(bitmap[2]) * 0.114 / 255
        let isLow = brightness < 0.25

        DispatchQueue.main.async { [weak self] in
            self?.onLowLightWarning?(isLow)
        }

        onVideoFrame?(sampleBuffer)
    }
}

// MARK: - DEBUG：从相册选取视频

#if DEBUG
extension CameraManager: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    /// 弹出相册 picker，选取视频后拷贝到临时目录并回调（仅 DEBUG）
    /// - Parameters:
    ///   - vc: 用于 present 的控制器
    ///   - completion: 选取成功返回临时 URL；取消或失败返回 nil
    func pickVideoFromLibrary(presenting vc: UIViewController, completion: @escaping (URL?) -> Void) {
        _debugCompletion = completion
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.movie"]
        picker.allowsEditing = false
        picker.delegate = self
        vc.present(picker, animated: true)
    }

    private static var _debugCompletionKey: UInt8 = 0
    private var _debugCompletion: ((URL?) -> Void)? {
        get { objc_getAssociatedObject(self, &Self._debugCompletionKey) as? (URL?) -> Void }
        set { objc_setAssociatedObject(self, &Self._debugCompletionKey, newValue, .OBJC_ASSOCIATION_COPY) }
    }

    func imagePickerController(_ picker: UIImagePickerController,
                                didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let srcURL = info[.mediaURL] as? URL else {
            _debugCompletion?(nil); return
        }
        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("debug_\(UUID().uuidString).mp4")
        try? FileManager.default.copyItem(at: srcURL, to: destURL)
        _debugCompletion?(destURL)
        _debugCompletion = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        _debugCompletion?(nil)
        _debugCompletion = nil
    }
}
#endif
