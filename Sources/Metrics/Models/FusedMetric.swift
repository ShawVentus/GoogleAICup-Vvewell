import Foundation

/// Fused metric result after applying fusion policy.
/// UI layer consumes this for display.
struct FusedMetric: Identifiable, Codable {
    // MARK: - Properties
    
    /// Unique identifier
    let id: String
    
    /// Owner profile ID
    let profileId: String
    
    /// Type of health metric
    let metricType: HealthMetricType
    
    /// Fused value
    let value: Double
    
    /// Unit string
    let unit: String
    
    /// Timestamp of the selected reading
    let timestamp: Double
    
    /// Source device that provided the selected value
    let source: MetricSourceDevice
    
    /// Source device display name
    let sourceName: String
    
    /// Accuracy of the selected reading
    let accuracy: ReadingAccuracy
    
    /// All source readings that were considered (for detail view)
    let allReadings: [RawReading]
    
    /// Fusion strategy used
    let fusionStrategy: FusionStrategy
    
    /// Number of sources
    var sourceCount: Int {
        let uniqueSources = Set(allReadings.map { $0.source })
        return uniqueSources.count
    }
    
    /// Whether multiple sources contributed
    var hasMultipleSources: Bool {
        sourceCount > 1
    }
}

// MARK: - Date Helpers

extension FusedMetric {
    /// Measurement date
    var date: Date {
        Date(timeIntervalSince1970: timestamp)
    }
}

// MARK: - Display

extension FusedMetric {
    /// Formatted value for display
    var formattedValue: String {
        switch metricType {
        case .heartRate, .spo2, .bodyTemperature, .stress, .hrv:
            return String(format: "%.0f", value)
        case .steps:
            return NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
        case .calories:
            return String(format: "%.0f", value)
        case .distance:
            if value >= 1000 {
                return String(format: "%.2f km", value / 1000)
            } else {
                return String(format: "%.0f m", value)
            }
        case .sleep:
            let hours = Int(value) / 60
            let mins = Int(value) % 60
            return "\(hours)h \(mins)m"
        case .sport:
            let hours = Int(value) / 3600
            let mins = Int(value) % 3600 / 60
            let secs = Int(value) % 60
            if hours > 0 {
                return String(format: "%dh %dm", hours, mins)
            } else {
                return String(format: "%dm %ds", mins, secs)
            }
        default:
            return String(format: "%.1f", value)
        }
    }
    
    /// Full display string with unit
    var displayString: String {
        "\(formattedValue) \(unit)"
    }
}

// MARK: - Creation

extension FusedMetric {
    /// Create from a single reading (no fusion needed)
    static func from(reading: RawReading) -> FusedMetric {
        FusedMetric(
            id: UUID().uuidString,
            profileId: reading.profileId,
            metricType: reading.metricType,
            value: reading.value,
            unit: reading.unit,
            timestamp: reading.timestamp,
            source: reading.source,
            sourceName: reading.sourceName,
            accuracy: reading.accuracy,
            allReadings: [reading],
            fusionStrategy: .highestAccuracy
        )
    }
    
    /// Create from multiple readings after fusion
    static func from(
        readings: [RawReading],
        strategy: FusionStrategy,
        selectedReading: RawReading
    ) -> FusedMetric {
        FusedMetric(
            id: UUID().uuidString,
            profileId: selectedReading.profileId,
            metricType: selectedReading.metricType,
            value: selectedReading.value,
            unit: selectedReading.unit,
            timestamp: selectedReading.timestamp,
            source: selectedReading.source,
            sourceName: selectedReading.sourceName,
            accuracy: selectedReading.accuracy,
            allReadings: readings,
            fusionStrategy: strategy
        )
    }
}
