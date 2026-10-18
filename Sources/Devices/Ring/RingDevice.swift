import Foundation
import Combine
import RingSDK
import CoreBluetooth

class RingDevice: HealthDeviceProtocol {

    let deviceType: DeviceType = .ring

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
    private var scannedRings: [Ring] = []

    // Sub-services
    private(set) lazy var healthService = RingHealthService()
    private(set) lazy var ecgService = RingECGService()
    private(set) lazy var gluService = RingGluService()
    private(set) lazy var emotionService = RingEmotionService()
    private(set) lazy var sleepService = RingSleepService()
    private(set) lazy var sportService = RingSportService()
    private(set) lazy var otaService = RingOTAService()
    private(set) lazy var settingsService = RingSettingsService()

    // MARK: - Initialization

    func initialize(appID: String, region: Int = 2) {
        BTService.shared().setUniqueAppIDKey(appID)
        BTService.shared().setLogEnable(true)
        setupBLEStateMonitoring()
        setupRingStatusMonitoring()
        setupChargeMonitoring()

        // Enable auto-reconnect to previously paired device
        BTService.shared().setAutoReconnectionEnabled(true)
    }

    private func setupBLEStateMonitoring() {
        BTService.shared().bleStatusUpdated { [weak self] state in
            guard let self = self else { return }
            if state == .poweredOn {
                // BLE just became ready — re-enable auto-reconnect so the SDK
                // picks up a previously paired device that may now be in range.
                if !self.isConnected() {
                    BTService.shared().setAutoReconnectionEnabled(true)
                }
            } else if self._connectionState.value == .connected || self._connectionState.value == .authSuccess {
                self._connectionState.send(.disconnected)
                self._deviceInfo.send(nil)
                self._batteryLevel.send(nil)
            }
        }
    }

    private func setupRingStatusMonitoring() {
        BTService.shared().ringStatusUpdated { [weak self] status in
            guard let self = self else { return }
            switch status {
            case .authSuccess:
                self._connectionState.send(.authSuccess)
                self._connectionState.send(.connected)
                self.fetchDeviceInfo()
            case .connected:
                // BLE connected but auth pending — only move to .connecting
                // if we haven't already authenticated (avoids reverting state)
                let current = self._connectionState.value
                if current != .connected && current != .authSuccess {
                    self._connectionState.send(.connecting)
                }
            case .disconnected, .off, .pairingRemoved:
                self._connectionState.send(.disconnected)
            case .connecting:
                self._connectionState.send(.connecting)
            case .connectFailed:
                self._connectionState.send(.authFailed(reason: "Connection failed"))
                self._connectionState.send(.disconnected)
            case .authRefused:
                self._connectionState.send(.authFailed(reason: "Auth refused by ring"))
                self._connectionState.send(.disconnected)
            case .authBound:
                self._connectionState.send(.authFailed(reason: "Device bound to another phone"))
                self._connectionState.send(.disconnected)
            case .authIllegal:
                self._connectionState.send(.authFailed(reason: "Illegal manufacturer"))
                self._connectionState.send(.disconnected)
            default:
                break
            }
        }
    }

    private func setupChargeMonitoring() {
        BTService.shared().chargeHandler = { [weak self] powerModel in
            self?._batteryLevel.send(Int(powerModel.batteryLevel))
        }
    }

    // MARK: - Scan

    func scan() -> AnyPublisher<[DiscoveredDevice], Never> {
        scannedRings = []
        BTService.shared().startScan()
        BTService.shared().scanningDeviceUpdated { [weak self] rings in
            guard let self = self else { return }
            self.scannedRings = rings
            let discovered = rings.map { ring in
                DiscoveredDevice(
                    uuid: ring.peripheral?.identifier.uuidString ?? "",
                    name: ring.name,
                    macAddress: ring.macAddress ?? "",
                    rssi: Int(ring.rssi),
                    deviceType: .ring,
                    rawDevice: ring
                )
            }
            self._discoveredDevices.send(discovered)
        }
        return _discoveredDevices.eraseToAnyPublisher()
    }

    func stopScan() {
        BTService.shared().stopScan()
    }

    // MARK: - Connect / Disconnect

    func connect(device: DiscoveredDevice) {
        _connectionState.send(.connecting)
        BTService.shared().bindDevice(device.macAddress)
    }

    func disconnect() {
        _connectionState.send(.disconnecting)
        BTService.shared().unbindDevice()
        _connectionState.send(.disconnected)
        _deviceInfo.send(nil)
        _batteryLevel.send(nil)
    }

    func isConnected() -> Bool {
        let state = _connectionState.value
        return state == .connected || state == .authSuccess
    }

    func isPaired() -> Bool {
        BTService.shared().getPairedDevice() != nil
    }

    // MARK: - Device Info

    private func fetchDeviceInfo() {
        BTService.shared().baseReq.fetch(.information) { [weak self] model, _ in
            guard let aboutModel = model as? BTAboutModel else { return }
            let pairedDevice = BTService.shared().getPairedDevice()
            let info = DeviceInfo(
                name: pairedDevice?.name ?? "",
                macAddress: pairedDevice?.macAddress ?? "",
                firmwareVersion: aboutModel.softwareVersion,
                hardwareVersion: aboutModel.hardwareVersion,
                serialNumber: aboutModel.serialNumber
            )
            self?._deviceInfo.send(info)
        }
        BTService.shared().baseReq.fetch(.status) { [weak self] model, _ in
            guard let statusModel = model as? BTStatusModel else { return }
            self?._batteryLevel.send(Int(statusModel.electricityLevel))
        }
    }

    // MARK: - Paired Device

    func getPairedDevice() -> BTDevice? {
        BTService.shared().getPairedDevice()
    }

    func setAutoReconnect(_ enabled: Bool) {
        BTService.shared().setAutoReconnectionEnabled(enabled)
    }
}
