import Foundation

/// Fusion strategy for combining multiple readings
enum FusionStrategy: String, Codable {
    /// Pick highest accuracy source; ties go to most recent
    case highestAccuracy
    
    /// Pick most recent timestamp
    case mostRecent
    
    /// Average values from multiple sources
    case average
    
    /// User-specified source override
    case userPreferred
}

// MARK: - Display

extension FusionStrategy {
    /// Localized display name
    var displayName: String {
        switch self {
        case .highestAccuracy: return "最高精度"
        case .mostRecent: return "最新数据"
        case .average: return "平均值"
        case .userPreferred: return "用户指定"
        }
    }
    
    /// Description
    var description: String {
        switch self {
        case .highestAccuracy:
            return "优先选择精度更高的设备数据"
        case .mostRecent:
            return "优先选择最新的测量数据"
        case .average:
            return "计算多个来源的平均值"
        case .userPreferred:
            return "使用用户指定的数据来源"
        }
    }
}

// MARK: - Fusion Policy

/// Policy for fusing readings of a specific metric type
struct FusionPolicy: Codable {
    /// Metric type this policy applies to
    let metricType: HealthMetricType
    
    /// Fusion strategy
    var strategy: FusionStrategy
    
    /// User's preferred source (for userPreferred strategy)
    var preferredSource: MetricSourceDevice?
    
    /// Last update timestamp
    var updatedAt: Double
    
    // MARK: - Initialization
    
    init(
        metricType: HealthMetricType,
        strategy: FusionStrategy = .highestAccuracy,
        preferredSource: MetricSourceDevice? = nil
    ) {
        self.metricType = metricType
        self.strategy = strategy
        self.preferredSource = preferredSource
        self.updatedAt = Date().timeIntervalSince1970
    }
    
    // MARK: - Defaults
    
    /// Default policy for a metric type
    static func `default`(for metricType: HealthMetricType) -> FusionPolicy {
        FusionPolicy(metricType: metricType, strategy: defaultStrategy(for: metricType))
    }
    
    /// Default strategy for a metric type
    static func defaultStrategy(for metricType: HealthMetricType) -> FusionStrategy {
        switch metricType {
        case .heartRate, .spo2, .stress, .ecg, .bloodGlucose, .sleep, .steps:
            return .highestAccuracy
        default:
            return .highestAccuracy
        }
    }
}

// MARK: - Database Mapping

extension FusionPolicy {
    /// Create from database row
    init?(from row: [String: Any]) {
        guard let metricTypeString = row["metric_type"] as? String,
              let metricType = HealthMetricType(rawValue: metricTypeString),
              let strategyString = row["strategy"] as? String,
              let strategy = FusionStrategy(rawValue: strategyString),
              let updatedAt = row["updated_at"] as? Double else {
            return nil
        }
        
        self.metricType = metricType
        self.strategy = strategy
        self.preferredSource = (row["preferred_source"] as? String).flatMap { MetricSourceDevice(rawValue: $0) }
        self.updatedAt = updatedAt
    }
    
    /// Convert to dictionary for database
    func toDatabaseRow() -> [String: Any] {
        var row: [String: Any] = [
            "metric_type": metricType.rawValue,
            "strategy": strategy.rawValue,
            "updated_at": updatedAt
        ]
        
        if let source = preferredSource {
            row["preferred_source"] = source.rawValue
        }
        
        return row
    }
}
