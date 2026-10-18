import Foundation

enum Config {
    // MARK: - Relay Server Configuration (from RelayConfig.plist)

    /// 从 RelayConfig.plist 读取中继服务器配置，支持运行时修改 IP 而无需重新编译。
    /// plist 包含: relay_scheme, relay_host, relay_port, use_relay
    private static let relayConfig: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "RelayConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return dict
    }()

    /// 是否启用中继服务器（RelayConfig.plist 中 use_relay = true）
    static var useRelay: Bool {
        relayConfig?["use_relay"] as? Bool ?? false
    }

    /// 中继服务器的完整 base URL，从 plist 动态构建。
    static var relayBaseURL: String {
        let scheme = relayConfig?["relay_scheme"] as? String ?? "https"
        let host   = relayConfig?["relay_host"]   as? String ?? "203.0.113.50"
        let port   = relayConfig?["relay_port"]    as? Int    ?? 8443
        // 标准端口省略端口号
        if (scheme == "https" && port == 443) || (scheme == "http" && port == 80) {
            return "\(scheme)://\(host)"
        }
        return "\(scheme)://\(host):\(port)"
    }

    /// 当前生效的 API base URL。
    /// 优先使用中继服务器；若未启用，回退到旧的硬编码地址。
    static var apiBaseURL: String {
        if useRelay { return relayBaseURL }
        #if DEBUG
        // DIRTY_DEMO_LOCALHOST_TRANSPORT_KEEP_FOR_PARITY_REMOVE_BEFORE_RELEASE
        return "http://127.0.0.1:8000"
        #else
        return "https://api.vvewell.health"
        #endif
    }
}
