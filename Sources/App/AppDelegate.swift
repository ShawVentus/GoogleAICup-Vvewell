import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupRingSDK()
        setupLocalPersistence()
        setupSyncEngine()
        setupProfileCloudSync()
        LocaleManager.shared.loadSavedLanguage()
        ZhEnTranslator.install()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // MARK: - Ring SDK Setup

    private func setupRingSDK() {
#if targetEnvironment(simulator)
        registerSimulatorDevices()
#else
        let appID = getOrCreateAppID()
        let ringDevice = RingDevice()
        ringDevice.initialize(appID: appID, region: 2)
        DeviceManager.shared.register(device: ringDevice)
        DeviceManager.shared.register(device: GenericBluetoothFactory.robot())
        DeviceManager.shared.register(device: GenericBluetoothFactory.radar())
#endif
    }

    private func setupLocalPersistence() {
        do {
            try HealthMetricStore.shared.initialize()
        } catch {
            print("[App] Failed to initialize local health store: \(error)")
        }
    }

    private func setupSyncEngine() {
        guard Config.useRelay else { return }
        SyncEngine.shared.start()
    }

    private func setupProfileCloudSync() {
        guard Config.useRelay else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(authTokenChanged),
            name: .authTokenDidChange,
            object: nil
        )

        if AuthTokenManager.shared.isLoggedIn {
            Task {
                try? await ProfileManager.shared.mergeProfilesFromCloud()
            }
        }
    }

    @objc private func authTokenChanged() {
        guard Config.useRelay, AuthTokenManager.shared.isLoggedIn else { return }
        Task {
            try? await ProfileManager.shared.mergeProfilesFromCloud()
        }
    }

    private func registerSimulatorDevices() {
        DeviceManager.shared.register(device: RingDevice())
        DeviceManager.shared.register(device: MockDevice(type: .watch, autoConnect: false))
        DeviceManager.shared.register(device: MockDevice(type: .band, autoConnect: false))
        DeviceManager.shared.register(device: MockDevice(type: .robot, autoConnect: false))
        DeviceManager.shared.register(device: MockDevice(type: .radar, autoConnect: false))
    }

    private func getOrCreateAppID() -> String {
        let keychainKey = "com.vvewell.app.uniqueID"
        if let existing = KeychainHelper.read(key: keychainKey) {
            return existing
        }
        let newID = UUID().uuidString
        KeychainHelper.save(key: keychainKey, value: newID)
        return newID
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
