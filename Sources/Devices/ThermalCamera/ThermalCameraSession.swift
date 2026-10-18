import Foundation
import Combine
import UIKit

struct ThermometryReading: Equatable {
    let minTemp: Float
    let maxTemp: Float
    let avgTemp: Float
    let timestamp: Date
}

final class ThermalCameraSession: NSObject, HikMicroSDKBridgeDelegate {

    private let bridge = HikMicroSDKBridge.shared()
    private let processingQueue = DispatchQueue(label: "com.vvewell.thermal.session")

    private let _thermometry = PassthroughSubject<ThermometryReading, Never>()
    var thermometry: AnyPublisher<ThermometryReading, Never> {
        _thermometry.eraseToAnyPublisher()
    }

    private let _frameCapture = PassthroughSubject<UIImage, Never>()
    var frameCapture: AnyPublisher<UIImage, Never> {
        _frameCapture.eraseToAnyPublisher()
    }

    private var captureTimer: DispatchSourceTimer?
    private let captureInterval: TimeInterval = 1.0 / 7.5
    private weak var previewView: UIView?

    override init() {
        super.init()
        bridge.delegate = self
    }

    // MARK: - Connection

    func connect(completion: @escaping (Bool, DeviceInfo?) -> Void) {
        processingQueue.async { [weak self] in
            guard let self = self else {
                completion(false, nil)
                return
            }

            let ip = self.cameraIP()
            let port: Int = 8000
            let user = self.cameraUser()
            let password = self.cameraPassword()

            self.bridge.login(withIP: ip, port: Int32(port), user: user, password: password) { success, deviceName, serial, firmware in
                if success {
                    let info = DeviceInfo(
                        name: deviceName ?? "HikMicro Thermal Camera",
                        macAddress: "",
                        firmwareVersion: firmware ?? "Unknown",
                        hardwareVersion: "",
                        serialNumber: serial ?? ""
                    )
                    DispatchQueue.main.async {
                        completion(true, info)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, nil)
                    }
                }
            }
        }
    }

    func disconnect() {
        stopPreview()
        stopThermometry()
        stopFrameCapture()
        bridge.logout()
    }

    // MARK: - Preview

    func startPreview(in view: UIView) -> Bool {
        previewView = view
        return bridge.startPreview(in: view)
    }

    func stopPreview() {
        bridge.stopPreview()
        previewView = nil
    }

    // MARK: - Thermometry

    func startThermometry() -> Bool {
        bridge.startThermometry()
    }

    func stopThermometry() {
        bridge.stopThermometry()
    }

    // MARK: - Frame Capture

    func startFrameCapture() {
        stopFrameCapture()
        let timer = DispatchSource.makeTimerSource(queue: processingQueue)
        timer.schedule(deadline: .now(), repeating: captureInterval)
        timer.setEventHandler { [weak self] in
            self?.captureFrame()
        }
        timer.resume()
        captureTimer = timer
    }

    func stopFrameCapture() {
        captureTimer?.cancel()
        captureTimer = nil
    }

    private func captureFrame() {
        guard bridge.isLoggedIn else { return }
        guard let view = previewView else { return }

        DispatchQueue.main.async { [weak self] in
            UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0)
            guard let context = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                return
            }
            view.layer.render(in: context)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            if let image = image {
                self?._frameCapture.send(image)
            }
        }
    }

    // MARK: - HikMicroSDKBridgeDelegate

    func bridgeDidLogin(withDeviceName deviceName: String, serialNumber: String, firmwareVersion: String) {
        // Handled via connect completion
    }

    func bridgeDidLogout() {
        stopFrameCapture()
    }

    func bridgeDidReceiveTemperatureMin(_ tempMin: Float, max tempMax: Float, avg tempAvg: Float, timestamp: TimeInterval) {
        let reading = ThermometryReading(
            minTemp: tempMin,
            maxTemp: tempMax,
            avgTemp: tempAvg,
            timestamp: Date(timeIntervalSince1970: timestamp)
        )
        _thermometry.send(reading)
    }

    func bridgeDidFailWithError(_ error: String) {
        NSLog("[ThermalCameraSession] SDK error: %@", error)
    }

    // MARK: - Credentials

    private func cameraIP() -> String {
        KeychainHelper.read(key: "com.vvewell.thermal.ip") ?? "192.168.1.1"
    }

    private func cameraUser() -> String {
        KeychainHelper.read(key: "com.vvewell.thermal.user") ?? "admin"
    }

    private func cameraPassword() -> String {
        KeychainHelper.read(key: "com.vvewell.thermal.password") ?? ""
    }

    func saveCredentials(ip: String, user: String, password: String) {
        KeychainHelper.save(key: "com.vvewell.thermal.ip", value: ip)
        KeychainHelper.save(key: "com.vvewell.thermal.user", value: user)
        KeychainHelper.save(key: "com.vvewell.thermal.password", value: password)
    }
}
