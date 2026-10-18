import Foundation

/// Device source types for health data.
/// Each reading tracks which device it came from.
enum MetricSourceDevice: String, Codable {
    /// Smart ring device (primary)
    case ring
    
    /// iPhone camera (rPPG algorithm)
    case phone
    
    /// Smart watch (future support)
    case watch
    
    /// Fitness band (future support)
    case band
    
    /// Medical-grade certified device
    case medical
    
    /// Unknown or unspecified source
    case unknown
}

// MARK: - Display

extension MetricSourceDevice {
    /// Localized display name
    var displayName: String {
        switch self {
        case .ring: return "智能戒指"
        case .phone: return "iPhone"
        case .watch: return "智能手表"
        case .band: return "手环"
        case .medical: return "医疗设备"
        case .unknown: return "未知"
        }
    }
    
    /// Icon for display
    var icon: String {
        switch self {
        case .ring: return "💍"
        case .phone: return "📱"
        case .watch: return "⌚"
        case .band: return "📿"
        case .medical: return "🏥"
        case .unknown: return "❓"
        }
    }
}

// MARK: - Accuracy

extension MetricSourceDevice {
    /// Default accuracy level for this device type
    var defaultAccuracy: ReadingAccuracy {
        switch self {
        case .ring, .watch, .band:
            return .consumer
        case .phone:
            return .estimated
        case .medical:
            return .medical
        case .unknown:
            return .estimated
        }
    }
}
