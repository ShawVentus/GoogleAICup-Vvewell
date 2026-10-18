import Foundation

// MARK: - ReadingPayload Protocol

/// Protocol for payload types that can be stored in RawReading
protocol ReadingPayload: Codable {
    /// Payload type identifier
    static var typeIdentifier: String { get }
    
    /// Type string for this instance
    var type: String { get }
    
    /// Encode to JSON string
    func toJsonString() -> String?
    
    /// Decode from JSON string
    static func fromJsonString(_ json: String) -> Self?
}

extension ReadingPayload {
    var type: String { Self.typeIdentifier }
    
    func toJsonString() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func fromJsonString(_ json: String) -> Self? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(Self.self, from: data)
    }
}

// MARK: - ECG Payload

/// ECG measurement payload with waveform data
struct ECGPayload: ReadingPayload {
    static var typeIdentifier: String { "ecg" }
    
    /// Sampling rate in Hz (typically 250)
    let sampleRate: Int
    
    /// ECG waveform in millivolts
    let waveform: [Float]
    
    /// Duration in seconds
    let duration: Double
    
    /// Minimum heart rate during recording
    let minHeartRate: Int
    
    /// Average heart rate during recording
    let avgHeartRate: Int
    
    /// Maximum heart rate during recording
    let maxHeartRate: Int
    
    /// Rhythm classification (0=sinus, 1=AF, etc.)
    let rhythmType: Int
    
    /// Confidence of rhythm classification (0.0-1.0)
    let rhythmConfidence: Double
}

// MARK: - Sleep Payload

/// Sleep session payload with stage data
struct SleepPayload: ReadingPayload {
    static var typeIdentifier: String { "sleep" }
    
    /// Total sleep duration in minutes
    let totalMinutes: Int
    
    /// Deep sleep duration in minutes
    let deepMinutes: Int
    
    /// Light sleep duration in minutes
    let lightMinutes: Int
    
    /// REM sleep duration in minutes
    let remMinutes: Int
    
    /// Awake time in minutes
    let awakeMinutes: Int
    
    /// Sleep efficiency percentage
    let efficiency: Double?
    
    /// Detailed sleep stages
    let stages: [SleepStage]?
    
    /// Sleep start timestamp
    let startTime: Double?
    
    /// Sleep end timestamp
    let endTime: Double?
}

/// Single sleep stage segment
struct SleepStage: Codable {
    /// Stage mode (1=light, 2=deep, 3=awake, 5=rem)
    let mode: Int
    
    /// Stage start timestamp
    let startTimestamp: Double
    
    /// Duration in minutes
    let durationMinutes: Int
    
    /// Display name
    var displayName: String {
        switch mode {
        case 1: return "浅睡"
        case 2: return "深睡"
        case 3: return "清醒"
        case 5: return "REM"
        default: return "未知"
        }
    }
}

// MARK: - Sport Payload

/// Sport/exercise session payload
struct SportPayload: ReadingPayload {
    static var typeIdentifier: String { "sport" }
    
    /// Sport type code
    let sportType: Int
    
    /// Duration in seconds
    let duration: Int
    
    /// Calories burned
    let calories: Int?
    
    /// Steps taken
    let steps: Int?
    
    /// Distance in meters
    let distance: Int?
    
    /// Average heart rate
    let avgHeartRate: Int?
    
    /// Maximum heart rate
    let maxHeartRate: Int?
    
    /// Minimum heart rate
    let minHeartRate: Int?
    
    /// Average pace (seconds per km)
    let avgPace: Int?
    
    /// Maximum pace
    let maxPace: Int?
    
    /// Average cadence (steps per minute)
    let avgCadence: Int?
    
    /// Maximum cadence
    let maxCadence: Int?
    
    /// Detailed segments
    let segments: [SportSegment]?
    
    /// Sport type display name
    var sportTypeName: String {
        switch sportType {
        case 0x05: return "室内步行"
        case 0x07: return "室内单车"
        case 0x08: return "室内跑步"
        case 0x09: return "室外步行"
        case 0x0A: return "室外跑步"
        case 0x0B: return "室外骑行"
        default: return "运动"
        }
    }
}

/// Sport segment detail
struct SportSegment: Codable {
    /// Time offset from start in seconds
    let timeOffset: Int
    
    /// Heart rate at this segment
    let heartRate: Int?
    
    /// Pace (seconds per km)
    let pace: Int?
    
    /// Cadence (steps per minute)
    let cadence: Int?
    
    /// Calories in this segment
    let calories: Int?
    
    /// Steps in this segment
    let steps: Int?
    
    /// Distance in this segment (meters)
    let distance: Int?
}

// MARK: - Body Composition Payload

/// Body composition measurement payload
struct BodyCompositionPayload: ReadingPayload {
    static var typeIdentifier: String { "bodyComposition" }
    
    /// BMI
    let bmi: Double
    
    /// Body fat percentage
    let bodyFatRate: Double
    
    /// Muscle mass in kg
    let muscleMass: Double
    
    /// Skeletal muscle mass in kg
    let skeletalMuscleMass: Double?
    
    /// Hydration in kg
    let hydration: Double?
    
    /// Hydration percentage
    let hydrationRate: Double?
    
    /// Protein mass in kg
    let proteinMass: Double?
    
    /// Protein percentage
    let proteinMassPercentage: Double?
    
    /// Bone salt mass in kg
    let boneSaltMass: Double?
    
    /// Basal metabolic rate
    let basalMetabolicRate: Int?
    
    /// Standard weight in kg
    let standardWeight: Double?
    
    /// Visceral fat level
    let visceralFatLevel: Int?
}

// MARK: - Blood Glucose Payload

/// Blood glucose measurement payload
struct BloodGlucosePayload: ReadingPayload {
    static var typeIdentifier: String { "bloodGlucose" }
    
    /// Glucose value in mmol/L
    let glucoseValue: Double
    
    /// Risk level (0=normal, 1=low, 2=high)
    let riskLevel: Int
    
    /// Whether measurement was fasting
    let isFasting: Bool
    
    /// Insights text from cloud analysis
    let insights: String?
    
    /// Risk level display name
    var riskLevelName: String {
        switch riskLevel {
        case 0: return "正常"
        case 1: return "偏低"
        case 2: return "偏高"
        default: return "未知"
        }
    }
}

// MARK: - Emotion Payload

/// Emotion/PPI analysis payload
struct EmotionPayload: ReadingPayload {
    static var typeIdentifier: String { "emotion" }
    
    /// Emotion type code (1-11)
    let emotionType: Int
    
    /// Stress score (1-100)
    let stressScore: Int
    
    /// Fatigue level (1-5)
    let fatigueLevel: Int?
    
    /// Valence score (positive/negative)
    let valence: Double?
    
    /// Emotion type display name
    var emotionName: String {
        switch emotionType {
        case 1: return "焦虑"
        case 2: return "悲伤"
        case 3: return "不愉快"
        case 4: return "紧张"
        case 5: return "挑战"
        case 6: return "困惑"
        case 7: return "平静"
        case 8: return "禅意"
        case 9: return "愉悦"
        case 10: return "快乐"
        case 11: return "兴奋"
        default: return "未知"
        }
    }
    
    /// Emotion category
    var category: String {
        switch emotionType {
        case 1, 2, 3: return "negative"
        case 4, 5, 6: return "neutral"
        case 7, 8, 9, 10, 11: return "positive"
        default: return "unknown"
        }
    }
}

// MARK: - Blood Pressure Payload

/// Blood pressure measurement payload
struct BloodPressurePayload: ReadingPayload {
    static var typeIdentifier: String { "bloodPressure" }
    
    /// Systolic pressure (mmHg)
    let systolic: Int
    
    /// Diastolic pressure (mmHg)
    let diastolic: Int
    
    /// Mean arterial pressure
    let meanArterialPressure: Int?
    
    /// Pulse pressure
    let pulsePressure: Int?
    
    /// Classification
    var classification: String {
        if systolic < 120 && diastolic < 80 {
            return "正常"
        } else if systolic < 140 && diastolic < 90 {
            return "正常高值"
        } else if systolic < 160 || diastolic < 100 {
            return "轻度高血压"
        } else if systolic < 180 || diastolic < 110 {
            return "中度高血压"
        } else {
            return "重度高血压"
        }
    }
}
