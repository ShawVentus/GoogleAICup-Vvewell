import Foundation
import Combine

class DeviceManager {

    static let shared = DeviceManager()

    private var devices: [DeviceType: HealthDeviceProtocol] = [:]
    private var cancellables = Set<AnyCancellable>()

    private let _connectionStates = PassthroughSubject<(DeviceType, ConnectionState), Never>()
    var connectionStates: AnyPublisher<(DeviceType, ConnectionState), Never> {
        _connectionStates.eraseToAnyPublisher()
    }

    private init() {}

    // MARK: - Registration

    func register(device: HealthDeviceProtocol) {
        devices[device.deviceType] = device
        device.connectionState
            .map { (device.deviceType, $0) }
            .sink { [weak self] pair in
                self?._connectionStates.send(pair)
            }
            .store(in: &cancellables)
    }

    func unregister(type: DeviceType) {
        devices.removeValue(forKey: type)
    }

    // MARK: - Access

    func device(for type: DeviceType) -> HealthDeviceProtocol? {
        devices[type]
    }

    func ring() -> RingDevice? {
        devices[.ring] as? RingDevice
    }

    var registeredTypes: [DeviceType] {
        Array(devices.keys)
    }

    // MARK: - Unified Scan

    private var scanResults: [DeviceType: [DiscoveredDevice]] = [:]
    private var scanCancellables = Set<AnyCancellable>()
    private let _allDiscoveredDevices = CurrentValueSubject<[DiscoveredDevice], Never>([])

    /// Starts scanning on all registered devices and merges results into a single stream.
    func scanAll() -> AnyPublisher<[DiscoveredDevice], Never> {
        scanResults.removeAll()
        scanCancellables.removeAll()

        for (type, device) in devices {
            device.scan()
                .sink { [weak self] discovered in
                    guard let self = self else { return }
                    self.scanResults[type] = discovered
                    self._allDiscoveredDevices.send(self.scanResults.values.flatMap { $0 })
                }
                .store(in: &scanCancellables)
        }

        return _allDiscoveredDevices.eraseToAnyPublisher()
    }

    func stopAllScans() {
        for device in devices.values {
            device.stopScan()
        }
        scanCancellables.removeAll()
        scanResults.removeAll()
    }
}
