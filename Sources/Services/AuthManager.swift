import Foundation

class AuthManager {

    static let shared = AuthManager()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let isLoggedIn = "auth_isLoggedIn"
        static let phoneNumber = "auth_phoneNumber"
    }

    private init() {}

    var isLoggedIn: Bool {
        defaults.bool(forKey: Keys.isLoggedIn)
    }

    var phoneNumber: String? {
        defaults.string(forKey: Keys.phoneNumber)
    }

    func login(phone: String) {
        defaults.set(true, forKey: Keys.isLoggedIn)
        defaults.set(phone, forKey: Keys.phoneNumber)
    }

    func logout() {
        defaults.set(false, forKey: Keys.isLoggedIn)
        defaults.removeObject(forKey: Keys.phoneNumber)
    }
}
