import Foundation
import Combine

protocol HealthDeviceProtocol: AnyObject {
    var deviceType: DeviceType { get }
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
    var deviceInfo: AnyPublisher<DeviceInfo?, Never> { get }
    var batteryLevel: AnyPublisher<Int?, Never> { get }

    func scan() -> AnyPublisher<[DiscoveredDevice], Never>
    func stopScan()
    func connect(device: DiscoveredDevice)
    func disconnect()
    func isConnected() -> Bool
    func isPaired() -> Bool
}
