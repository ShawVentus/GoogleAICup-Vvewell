import Foundation

/// Unified health metric types, decoupled from device-specific types.
/// Each device maps its measurements to these common types.
enum HealthMetricType: String, Codable, CaseIterable {
    // MARK: - Basic Physiological
    
    /// Heart rate in beats per minute (bpm)
    case heartRate
    
    /// Blood oxygen saturation percentage (%)
    case spo2
    
    /// Blood pressure (mmHg) - value stores systolic, payload has diastolic
    case bloodPressure
    
    /// Body temperature in degrees Celsius (°C)
    case bodyTemperature
    
    /// Stress level (1-100 scale)
    case stress
    
    /// Heart rate variability in milliseconds (ms)
    case hrv
    
    // MARK: - Specialized Tests
    
    /// Electrocardiogram with waveform data
    case ecg
    
    /// Blood glucose level
    case bloodGlucose
    
    /// Body composition (BMI, body fat, muscle mass, etc.)
    case bodyComposition
    
    /// Emotion/PPI analysis result
    case emotion
    
    /// UV radiation exposure
    case uv
    
    // MARK: - Activity
    
    /// Step count
    case steps
    
    /// Calories burned
    case calories
    
    /// Distance traveled in meters
    case distance
    
    // MARK: - Sleep & Sport
    
    /// Sleep session data with stages
    case sleep
    
    /// Sport/exercise session data
    case sport
}

// MARK: - Category

extension HealthMetricType {
    enum Category {
        case basicPhysiological
        case specializedTests
        case activity
        case sleepAndSport
    }
    
    var category: Category {
        switch self {
        case .heartRate, .spo2, .bloodPressure, .bodyTemperature, .stress, .hrv:
            return .basicPhysiological
        case .ecg, .bloodGlucose, .bodyComposition, .emotion, .uv:
            return .specializedTests
        case .steps, .calories, .distance:
            return .activity
        case .sleep, .sport:
            return .sleepAndSport
        }
    }
}

// MARK: - Display

extension HealthMetricType {
    /// Localized display name
    var displayName: String {
        switch self {
        case .heartRate: return "心率"
        case .spo2: return "血氧"
        case .bloodPressure: return "血压"
        case .bodyTemperature: return "体温"
        case .stress: return "压力"
        case .hrv: return "心率变异"
        case .ecg: return "心电图"
        case .bloodGlucose: return "血糖"
        case .bodyComposition: return "体成分"
        case .emotion: return "情绪"
        case .uv: return "紫外线"
        case .steps: return "步数"
        case .calories: return "卡路里"
        case .distance: return "距离"
        case .sleep: return "睡眠"
        case .sport: return "运动"
        }
    }
    
    /// Default unit for this metric
    var defaultUnit: String {
        switch self {
        case .heartRate: return "bpm"
        case .spo2: return "%"
        case .bloodPressure: return "mmHg"
        case .bodyTemperature: return "°C"
        case .stress: return ""
        case .hrv: return "ms"
        case .ecg: return "bpm"
        case .bloodGlucose: return "mmol/L"
        case .bodyComposition: return ""
        case .emotion: return ""
        case .uv: return ""
        case .steps: return "步"
        case .calories: return "kcal"
        case .distance: return "m"
        case .sleep: return "min"
        case .sport: return "s"
        }
    }
    
    /// Icon emoji for display
    var icon: String {
        switch self {
        case .heartRate: return "❤️"
        case .spo2: return "🫁"
        case .bloodPressure: return "💜"
        case .bodyTemperature: return "🌡"
        case .stress: return "🧠"
        case .hrv: return "💓"
        case .ecg: return "💜"
        case .bloodGlucose: return "🩸"
        case .bodyComposition: return "⚖️"
        case .emotion: return "😊"
        case .uv: return "☀️"
        case .steps: return "🚶"
        case .calories: return "🔥"
        case .distance: return "📏"
        case .sleep: return "💤"
        case .sport: return "🏃"
        }
    }
}

// MARK: - Payload Support

extension HealthMetricType {
    /// Whether this metric type has a payload
    var hasPayload: Bool {
        switch self {
        case .ecg, .sleep, .sport, .bodyComposition, .bloodGlucose, .emotion, .bloodPressure:
            return true
        default:
            return false
        }
    }
    
    /// Payload type string for JSON serialization
    var payloadType: String? {
        guard hasPayload else { return nil }
        return rawValue
    }
}

// MARK: - Ring SDK Mapping

extension HealthMetricType {
    /// Map Ring SDK measurement type code to HealthMetricType
    /// - Parameter sdkCode: SDK measurement type code (0x01, 0x02, etc.)
    /// - Returns: Corresponding HealthMetricType, or nil if not supported
    static func from(ringSDKCode sdkCode: UInt8) -> HealthMetricType? {
        switch sdkCode {
        case 0x01: return .heartRate
        case 0x02: return .spo2
        case 0x04: return .ecg
        case 0x06: return .bodyTemperature
        case 0x07: return .bodyComposition
        case 0x08: return .bloodGlucose
        case 0x09: return .stress
        case 0x0A: return .uv
        default: return nil
        }
    }
    
    /// Ring SDK measurement type code
    var ringSDKCode: UInt8? {
        switch self {
        case .heartRate: return 0x01
        case .spo2: return 0x02
        case .ecg: return 0x04
        case .bodyTemperature: return 0x06
        case .bodyComposition: return 0x07
        case .bloodGlucose: return 0x08
        case .stress: return 0x09
        case .uv: return 0x0A
        default: return nil
        }
    }
}
