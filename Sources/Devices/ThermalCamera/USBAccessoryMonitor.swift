import Foundation
import ExternalAccessory

final class USBAccessoryMonitor {

    static let shared = USBAccessoryMonitor()

    private(set) var isCameraConnected = false

    private init() {}

    func startMonitoring() {
        EAAccessoryManager.shared().registerForLocalNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessoryDidConnect(_:)),
            name: .EAAccessoryDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessoryDidDisconnect(_:)),
            name: .EAAccessoryDidDisconnect,
            object: nil
        )
        checkConnectedAccessories()
    }

    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self)
    }

    private func checkConnectedAccessories() {
        let accessories = EAAccessoryManager.shared().connectedAccessories
        isCameraConnected = accessories.contains { accessory in
            accessory.name.lowercased().contains("hikmicro") ||
            accessory.name.lowercased().contains("hikvision") ||
            accessory.protocolStrings.contains { proto in
                proto.lowercased().contains("hikmicro") || proto.lowercased().contains("hikvision")
            }
        }
    }

    @objc private func accessoryDidConnect(_ notification: Notification) {
        guard let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory else { return }
        let isCamera = accessory.name.lowercased().contains("hikmicro") ||
            accessory.name.lowercased().contains("hikvision") ||
            accessory.protocolStrings.contains { proto in
                proto.lowercased().contains("hikmicro") || proto.lowercased().contains("hikvision")
            }
        if isCamera {
            isCameraConnected = true
            NotificationCenter.default.post(name: .thermalCameraUSBConnected, object: nil)
        }
    }

    @objc private func accessoryDidDisconnect(_ notification: Notification) {
        guard let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory else { return }
        let wasCamera = accessory.name.lowercased().contains("hikmicro") ||
            accessory.name.lowercased().contains("hikvision") ||
            accessory.protocolStrings.contains { proto in
                proto.lowercased().contains("hikmicro") || proto.lowercased().contains("hikvision")
            }
        if wasCamera {
            isCameraConnected = false
            NotificationCenter.default.post(name: .thermalCameraUSBDisconnected, object: nil)
        }
    }
}

extension Notification.Name {
    static let thermalCameraUSBConnected = Notification.Name("thermalCameraUSBConnected")
    static let thermalCameraUSBDisconnected = Notification.Name("thermalCameraUSBDisconnected")
}
