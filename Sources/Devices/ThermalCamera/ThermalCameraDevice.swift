import Foundation
import Combine

final class ThermalCameraDevice: HealthDeviceProtocol {

    let deviceType: DeviceType = .thermalCamera

    private let _connectionState = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    var connectionState: AnyPublisher<ConnectionState, Never> {
        _connectionState.removeDuplicates().eraseToAnyPublisher()
    }

    private let _deviceInfo = CurrentValueSubject<DeviceInfo?, Never>(nil)
    var deviceInfo: AnyPublisher<DeviceInfo?, Never> {
        _deviceInfo.eraseToAnyPublisher()
    }

    private let _batteryLevel = CurrentValueSubject<Int?, Never>(nil)
    var batteryLevel: AnyPublisher<Int?, Never> {
        _batteryLevel.eraseToAnyPublisher()
    }

    private let _discoveredDevices = PassthroughSubject<[DiscoveredDevice], Never>()

    private var session: ThermalCameraSession?
    private var usbConnected = false

    init() {
        USBAccessoryMonitor.shared.startMonitoring()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(usbDidConnect),
            name: .thermalCameraUSBConnected,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(usbDidDisconnect),
            name: .thermalCameraUSBDisconnected,
            object: nil
        )
        usbConnected = USBAccessoryMonitor.shared.isCameraConnected
        if usbConnected {
            handleUSBConnect()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - USB Events

    @objc private func usbDidConnect() {
        usbConnected = true
        handleUSBConnect()
    }

    @objc private func usbDidDisconnect() {
        usbConnected = false
        session?.disconnect()
        session = nil
        _connectionState.send(.disconnected)
        _deviceInfo.send(nil)
        _batteryLevel.send(nil)
    }

    private func handleUSBConnect() {
        _connectionState.send(.connecting)

        let session = ThermalCameraSession()
        self.session = session

        session.connect { [weak self] success, info in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if success {
                    self._connectionState.send(.authSuccess)
                    self._connectionState.send(.connected)
                    self._deviceInfo.send(info)
                } else {
                    self._connectionState.send(.disconnected)
                }
            }
        }
    }

    // MARK: - HealthDeviceProtocol

    func scan() -> AnyPublisher<[DiscoveredDevice], Never> {
        _discoveredDevices.eraseToAnyPublisher()
    }

    func stopScan() {}

    func connect(device: DiscoveredDevice) {
        handleUSBConnect()
    }

    func disconnect() {
        session?.disconnect()
        session = nil
        _connectionState.send(.disconnecting)
        _connectionState.send(.disconnected)
        _deviceInfo.send(nil)
        _batteryLevel.send(nil)
    }

    func isConnected() -> Bool {
        _connectionState.value == .connected || _connectionState.value == .authSuccess
    }

    func isPaired() -> Bool {
        usbConnected
    }
}
