import Foundation

/// Accuracy level for health readings.
/// Used to determine data quality and fusion priority.
enum ReadingAccuracy: Int, Codable, Comparable, CaseIterable {
    /// Algorithm-estimated value (e.g., rPPG from camera)
    case estimated = 1
    
    /// Consumer-grade sensor (e.g., ring, watch, band)
    case consumer = 2
    
    /// Medical-grade certified device
    case medical = 3
}

// MARK: - Comparable

extension ReadingAccuracy {
    static func < (lhs: ReadingAccuracy, rhs: ReadingAccuracy) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Display

extension ReadingAccuracy {
    /// Localized display name
    var displayName: String {
        switch self {
        case .estimated: return "估算"
        case .consumer: return "消费级"
        case .medical: return "医疗级"
        }
    }
    
    /// Description of accuracy level
    var description: String {
        switch self {
        case .estimated:
            return "算法估算值，仅供参考"
        case .consumer:
            return "消费级传感器测量"
        case .medical:
            return "医疗级认证设备测量"
        }
    }
    
    /// Icon for display
    var icon: String {
        switch self {
        case .estimated: return "📱"
        case .consumer: return "💍"
        case .medical: return "🏥"
        }
    }
    
    /// Tag color for UI display
    var tagColor: String {
        switch self {
        case .estimated: return "yellow"
        case .consumer: return "green"
        case .medical: return "cyan"
        }
    }
}

// MARK: - Sync API

extension ReadingAccuracy {
    /// String representation for API sync
    var apiValue: String {
        switch self {
        case .estimated: return "estimated"
        case .consumer: return "consumer"
        case .medical: return "medical"
        }
    }
    
    /// Create from API string
    static func from(apiValue: String) -> ReadingAccuracy? {
        switch apiValue {
        case "estimated": return .estimated
        case "consumer": return .consumer
        case "medical": return .medical
        default: return nil
        }
    }
}
