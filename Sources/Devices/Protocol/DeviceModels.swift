import Foundation

// MARK: - Device Types

enum DeviceType: String, CaseIterable, Codable {
    case ring
    case watch
    case band
    case robot
    case radar
    case thermalCamera
}

// MARK: - Connection State

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case authSuccess
    case authFailed(reason: String)
}

// MARK: - Discovered Device

struct DiscoveredDevice {
    let uuid: String
    let name: String
    let macAddress: String
    let rssi: Int
    let deviceType: DeviceType
    let rawDevice: Any
}

// MARK: - Device Info

struct DeviceInfo {
    let name: String
    let macAddress: String
    let firmwareVersion: String
    let hardwareVersion: String
    let serialNumber: String
}

// MARK: - Measurement

enum MeasureType: String {
    case heartRate
    case spo2
    case bloodPressure
    case temperature
    case stress
    case bodyComposition
    case uv
}

struct MeasureResult {
    let type: MeasureType
    let value: Float
    let timestamp: Date
    let bodyComposition: BodyCompositionData?

    init(type: MeasureType, value: Float, timestamp: Date = Date(), bodyComposition: BodyCompositionData? = nil) {
        self.type = type
        self.value = value
        self.timestamp = timestamp
        self.bodyComposition = bodyComposition
    }
}

struct BodyCompositionData {
    let bmi: Float
    let bodyFatRate: Float
    let muscleMass: Float
    let hydration: Float
    let boneMass: Float
    let bmr: Float
    let visceralFat: Float
    let subcutaneousFat: Float
    let proteinRate: Float
    let bodyAge: Int
    let weight: Float
}

// MARK: - ECG

enum ECGEvent {
    case started
    case packet(ECGPacketData)
    case diagnosis(ECGReport)
    case completed
    case failed(Error)
}

struct ECGPacketData {
    let values: [Float]
    let sampleRate: Int
    let packetNumber: Int
    let timestamp: Date
}

struct ECGReport {
    let waveform: [Float]
    let sampleRate: Int
    let minHeartRate: Int
    let avgHeartRate: Int
    let maxHeartRate: Int
    let rhythmType: Int
    let confidence: Int
    let duration: TimeInterval
}

// MARK: - Blood Glucose

enum GluEvent {
    case measuring(progress: Float)
    case uploading
    case analyzing
    case report(GluReport)
    case failed(Error)
}

struct GluReport {
    let glucoseValue: Float
    let riskLevel: Int
    let timestamp: Date
    let rawData: [String: Any]
}

// MARK: - Emotion / PPI

enum EmotionMeasureMode: Int {
    case appControl = 1
    case timer = 2
}

enum EmotionEvent {
    case started
    case ppiData(PPIData)
    case result(EmotionResult)
    case completed
    case failed(Error)
}

struct PPIData {
    let ppiValues: [Int]
    let timestamp: Date
}

struct EmotionResult {
    let emotionType: Int
    let emotionCategory: String
    let valence: Float
    let stressScore: Int
    let fatigueLevel: Int
    let timestamp: Date
}

// MARK: - Sleep

struct SleepData {
    let summary: SleepSummary
    let details: [SleepDetail]
}

struct SleepSummary {
    let totalSleep: Int
    let deepSleep: Int
    let lightSleep: Int
    let remSleep: Int
    let awakeDuration: Int
    let awakeCount: Int
    let startTimestamp: TimeInterval
    let endTimestamp: TimeInterval
}

struct SleepDetail {
    let mode: SleepMode
    let startTimestamp: TimeInterval
    let duration: Int
}

enum SleepMode: Int {
    case light = 1
    case deep = 2
    case awake = 3
    case notWorn = 4
    case rem = 5
    case shutdown = 7
}

// MARK: - Sport

enum SportType: Int {
    case indoorWalk = 0x05
    case indoorBike = 0x07
    case indoorRun = 0x08
    case outdoorWalk = 0x09
    case outdoorRun = 0x0A
    case outdoorBike = 0x0B
}

enum SportEvent {
    case started
    case paused
    case resumed
    case stopped
    case realTimeData(SportRealTimeData)
    case summary(SportSummary)
    case detail([SportDetail])
    case failed(Error)
}

struct SportRealTimeData {
    let heartRate: Int
    let calories: Int
    let steps: Int
    let distance: Int
    let pace: Int
    let cadence: Int
    let temperature: Float
}

struct SportSummary {
    let sportType: SportType
    let duration: Int
    let calories: Int
    let steps: Int
    let distance: Int
    let avgHeartRate: Int
    let avgPace: Int
}

struct SportDetail {
    let sportType: SportType
    let calories: Int
    let steps: Int
    let distance: Int
    let heartRate: Int
    let temperature: Float
    let pace: Int
    let speed: Int
    let cadence: Int
}

// MARK: - OTA

enum OTAEvent {
    case checking
    case available(OTAInfo)
    case notAvailable
    case downloading(progress: Float)
    case installing(progress: Float)
    case completed
    case failed(Error)
}

struct OTAInfo {
    let currentVersion: String
    let latestVersion: String
    let fileURL: URL?
}

// MARK: - Health Data (historical)

struct HealthData {
    let heartRates: [Int]
    let hrv: Int
    let spo2Values: [Int]
    let stressValues: [Int]
    let steps: Int
    let distance: Int
    let calories: Int
    let temperatures: [Float]
    let date: Date
}

// MARK: - Health Score

struct HealthScore {
    let sleepScore: Int
    let activityScore: Int
    let readinessScore: Int
    let overallScore: Int
}

// MARK: - Ring Errors

enum RingError: LocalizedError {
    case measurementStartFailed
    case dataFetchFailed
    case ecgNotSupported
    case ecgAuthFailed
    case gluMeasurementFailed
    case gluUploadFailed
    case gluAnalysisFailed
    case emotionStartFailed
    case sportOperationFailed
    case otaCheckFailed
    case otaUpgradeFailed
    case notConnected
    case timeout

    var errorDescription: String? {
        switch self {
        case .measurementStartFailed: return "Failed to start measurement"
        case .dataFetchFailed: return "Failed to fetch data"
        case .ecgNotSupported: return "ECG not supported on this device"
        case .ecgAuthFailed: return "ECG server authorization failed"
        case .gluMeasurementFailed: return "Glucose measurement failed"
        case .gluUploadFailed: return "Glucose data upload failed"
        case .gluAnalysisFailed: return "Glucose analysis failed"
        case .emotionStartFailed: return "Emotion measurement start failed"
        case .sportOperationFailed: return "Sport operation failed"
        case .otaCheckFailed: return "OTA check failed"
        case .otaUpgradeFailed: return "OTA upgrade failed"
        case .notConnected: return "Device not connected"
        case .timeout: return "Operation timed out"
        }
    }
}
