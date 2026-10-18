import Foundation
import Security

/// Manages JWT access/refresh tokens in the iOS Keychain.
/// Provides automatic token refresh when the access token expires.
final class AuthTokenManager {

    static let shared = AuthTokenManager()
    private init() {}

    // MARK: - Keychain Keys

    private let accessTokenKey  = "com.vvewell.relay.accessToken"
    private let refreshTokenKey = "com.vvewell.relay.refreshToken"

    // MARK: - Public API

    /// Current access token, or nil if not logged in.
    var accessToken: String? {
        get { keychainRead(key: accessTokenKey) }
        set {
            if let value = newValue {
                keychainWrite(key: accessTokenKey, value: value)
            } else {
                keychainDelete(key: accessTokenKey)
            }
        }
    }

    /// Current refresh token, or nil if not logged in.
    var refreshToken: String? {
        get { keychainRead(key: refreshTokenKey) }
        set {
            if let value = newValue {
                keychainWrite(key: refreshTokenKey, value: value)
            } else {
                keychainDelete(key: refreshTokenKey)
            }
        }
    }

    /// Whether the user is logged in (has a refresh token).
    var isLoggedIn: Bool { refreshToken != nil }

    /// Best-effort email extracted from the current JWT access token.
    /// This keeps user-facing account surfaces aligned with relay auth without
    /// introducing another persistence channel.
    var currentEmail: String? {
        guard let token = accessToken,
              let payload = jwtPayload(from: token),
              let email = payload["email"] as? String,
              !email.isEmpty else {
            return nil
        }
        return email
    }

    /// Store tokens received from login / refresh response.
    func storeTokens(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
        NotificationCenter.default.post(name: .authTokenDidChange, object: nil)
    }

    /// Clear all tokens (logout).
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        NotificationCenter.default.post(name: .authTokenDidChange, object: nil)
    }

    /// Apply the JWT Authorization header to a URLRequest.
    /// Returns the modified request, or nil if no token is available.
    func authorizeRequest(_ request: inout URLRequest) {
        guard let token = accessToken else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    // MARK: - Token Refresh

    /// Attempt to refresh the access token using the refresh token.
    /// - Returns: `true` if refresh succeeded, `false` otherwise.
    func refreshAccessToken() async -> Bool {
        guard let refresh = refreshToken else { return false }

        let baseURL = Config.apiBaseURL
        guard let url = URL(string: "\(baseURL)/auth/refresh") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["refresh_token": refresh]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                // Refresh failed — force logout
                clearTokens()
                return false
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newAccess = json["access_token"] as? String,
               let newRefresh = json["refresh_token"] as? String {
                storeTokens(access: newAccess, refresh: newRefresh)
                return true
            }

            return false
        } catch {
            return false
        }
    }

    // MARK: - Keychain Helpers

    private func keychainWrite(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func keychainRead(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }

        return value
    }

    private func keychainDelete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func jwtPayload(from token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count > 1,
              let payloadData = decodeBase64URL(String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return nil
        }
        return json
    }

    private func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }
        return Data(base64Encoded: base64)
    }
}

extension Notification.Name {
    static let authTokenDidChange = Notification.Name("authTokenDidChange")
}
