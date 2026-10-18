import Foundation

final class RingDevice: MockDevice {
    init() {
        super.init(type: .ring, autoConnect: true)
    }

    func initialize(appID: String, region: Int = 2) {}

    func setAutoReconnect(_ enabled: Bool) {}
}
