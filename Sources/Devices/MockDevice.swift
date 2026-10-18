import Foundation
import Combine

/// A mock device for testing the scan/connect UI without real hardware.
class MockDevice: HealthDeviceProtocol {

    let deviceType: DeviceType

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
    private var foundDevices: [DiscoveredDevice] = []
    private var scanWorkItems: [DispatchWorkItem] = []

    /// Creates a mock device.
    /// - Parameters:
    ///   - type: The device type to mock.
    ///   - autoConnect: If true, the device starts in a connected state with mock info populated.
    init(type: DeviceType, autoConnect: Bool = false) {
        self.deviceType = type
        if autoConnect {
            simulateConnected()
        }
    }

    /// Immediately sets the device to connected state with mock device info and battery.
    private func simulateConnected() {
        _connectionState.send(.authSuccess)
        _connectionState.send(.connected)
        _deviceInfo.send(DeviceInfo(
            name: mockDeviceName(),
            macAddress: mockMacAddress(),
            firmwareVersion: "2.1.3",
            hardwareVersion: "HW2.0",
            serialNumber: "KNW-\(deviceType.rawValue.uppercased())-20260101"
        ))
        _batteryLevel.send(Int.random(in: 60...92))
    }

    private func mockDeviceName() -> String {
        switch deviceType {
        case .ring: return "Vvewell Ring Pro"
        case .watch: return "Vvewell Watch Pro"
        case .band: return "Vvewell Band Lite"
        case .robot: return "vvewell-robot"
        case .radar: return "JDY-23"
        case .thermalCamera: return "Hikmicro Thermal Camera"
        }
    }

    private func mockMacAddress() -> String {
        switch deviceType {
        case .ring: return "11:22:33:AA:BB:CC"
        case .watch: return "AA:BB:CC:11:22:33"
        case .band: return "DD:EE:FF:11:22:33"
        case .robot: return "ROBOT-BLE"
        case .radar: return "RADAR-BLE"
        case .thermalCamera: return "00:00:00:00:00:00"
        }
    }

    // MARK: - Scan

    func scan() -> AnyPublisher<[DiscoveredDevice], Never> {
        stopScan()
        foundDevices = []

        let mockList = generateMockDevices()
        var delay: TimeInterval = Double.random(in: 1.5...3.0)

        for device in mockList {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.foundDevices.append(device)
                self._discoveredDevices.send(self.foundDevices)
            }
            scanWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            delay += Double.random(in: 2.0...4.0)
        }

        return _discoveredDevices.eraseToAnyPublisher()
    }

    func stopScan() {
        scanWorkItems.forEach { $0.cancel() }
        scanWorkItems.removeAll()
    }

    // MARK: - Connect / Disconnect

    func connect(device: DiscoveredDevice) {
        _connectionState.send(.connecting)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            self._connectionState.send(.authSuccess)
            self._connectionState.send(.connected)
            self._deviceInfo.send(DeviceInfo(
                name: device.name,
                macAddress: device.macAddress,
                firmwareVersion: "1.0.0-mock",
                hardwareVersion: "HW1.0",
                serialNumber: "MOCK-\(device.deviceType.rawValue.uppercased())-001"
            ))
            self._batteryLevel.send(Int.random(in: 55...95))
        }
    }

    func disconnect() {
        _connectionState.send(.disconnecting)
        _connectionState.send(.disconnected)
        _deviceInfo.send(nil)
        _batteryLevel.send(nil)
    }

    func isConnected() -> Bool {
        _connectionState.value == .connected || _connectionState.value == .authSuccess
    }

    func isPaired() -> Bool {
        isConnected()
    }

    // MARK: - Mock Data

    private func generateMockDevices() -> [DiscoveredDevice] {
        switch deviceType {
        case .watch:
            return [
                DiscoveredDevice(
                    uuid: UUID().uuidString,
                    name: "Vvewell Watch Pro",
                    macAddress: "AA:BB:CC:11:22:33",
                    rssi: -42,
                    deviceType: .watch,
                    rawDevice: NSNull()
                ),
                DiscoveredDevice(
                    uuid: UUID().uuidString,
                    name: "Vvewell Watch SE",
                    macAddress: "AA:BB:CC:44:55:66",
                    rssi: -71,
                    deviceType: .watch,
                    rawDevice: NSNull()
                ),
            ]
        case .band:
            return [
                DiscoveredDevice(
                    uuid: UUID().uuidString,
                    name: "Vvewell Band Lite",
                    macAddress: "DD:EE:FF:11:22:33",
                    rssi: -56,
                    deviceType: .band,
                    rawDevice: NSNull()
                ),
            ]
        case .ring:
            return [
                DiscoveredDevice(
                    uuid: UUID().uuidString,
                    name: "Vvewell Ring",
                    macAddress: "11:22:33:AA:BB:CC",
                    rssi: -38,
                    deviceType: .ring,
                    rawDevice: NSNull()
                ),
            ]
        case .thermalCamera:
            return []
        case .robot:
            return [DiscoveredDevice(uuid: UUID().uuidString, name: "vvewell-robot", macAddress: "ROBOT-BLE", rssi: -48, deviceType: .robot, rawDevice: NSNull())]
        case .radar:
            return [DiscoveredDevice(uuid: UUID().uuidString, name: "JDY-23", macAddress: "RADAR-BLE", rssi: -52, deviceType: .radar, rawDevice: NSNull())]
        }
    }
}
