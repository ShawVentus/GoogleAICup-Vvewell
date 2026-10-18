import Foundation

struct HealthRecord: Codable, Identifiable {
    let id: String
    let date: Date
    let profileId: String?
    let hr: Double?
    let hrStatus: String?
    let rr: Double?
    let rrStatus: String?
    let spo2: Double?
    let spo2Status: String?
    let stressScore: Double?
    let stressLevel: String?
    let sqi: Double?
    let confidence: String?
    let skinLabel: String?
    let skinI18n: [String: String]?

    init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        profileId: String? = nil,
        hr: Double?,
        hrStatus: String?,
        rr: Double?,
        rrStatus: String?,
        spo2: Double?,
        spo2Status: String?,
        stressScore: Double?,
        stressLevel: String?,
        sqi: Double?,
        confidence: String?,
        skinLabel: String?,
        skinI18n: [String: String]?
    ) {
        self.id = id
        self.date = date
        self.profileId = profileId
        self.hr = hr
        self.hrStatus = hrStatus
        self.rr = rr
        self.rrStatus = rrStatus
        self.spo2 = spo2
        self.spo2Status = spo2Status
        self.stressScore = stressScore
        self.stressLevel = stressLevel
        self.sqi = sqi
        self.confidence = confidence
        self.skinLabel = skinLabel
        self.skinI18n = skinI18n
    }

    init(from response: AnalyzeResponse, profileId: String? = nil) {
        self.id = UUID().uuidString
        self.date = Date()
        self.profileId = profileId
        self.hr = response.hr
        self.hrStatus = response.hrStatus
        self.rr = response.rr
        self.rrStatus = response.rrStatus
        self.spo2 = response.spo2
        self.spo2Status = response.spo2Status
        self.stressScore = response.stressScore
        self.stressLevel = response.stressLevel
        self.sqi = response.sqi
        self.confidence = response.confidence
        self.skinLabel = response.skinLabel
        self.skinI18n = response.skinI18n
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case profileId
        case hr
        case hrStatus
        case rr
        case rrStatus
        case spo2
        case spo2Status
        case stressScore
        case stressLevel
        case sqi
        case confidence
        case skinLabel
        case skinI18n
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        profileId = try container.decodeIfPresent(String.self, forKey: .profileId)
        hr = try container.decodeIfPresent(Double.self, forKey: .hr)
        hrStatus = try container.decodeIfPresent(String.self, forKey: .hrStatus)
        rr = try container.decodeIfPresent(Double.self, forKey: .rr)
        rrStatus = try container.decodeIfPresent(String.self, forKey: .rrStatus)
        spo2 = try container.decodeIfPresent(Double.self, forKey: .spo2)
        spo2Status = try container.decodeIfPresent(String.self, forKey: .spo2Status)
        stressScore = try container.decodeIfPresent(Double.self, forKey: .stressScore)
        stressLevel = try container.decodeIfPresent(String.self, forKey: .stressLevel)
        sqi = try container.decodeIfPresent(Double.self, forKey: .sqi)
        confidence = try container.decodeIfPresent(String.self, forKey: .confidence)
        skinLabel = try container.decodeIfPresent(String.self, forKey: .skinLabel)
        skinI18n = try container.decodeIfPresent([String: String].self, forKey: .skinI18n)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(profileId, forKey: .profileId)
        try container.encodeIfPresent(hr, forKey: .hr)
        try container.encodeIfPresent(hrStatus, forKey: .hrStatus)
        try container.encodeIfPresent(rr, forKey: .rr)
        try container.encodeIfPresent(rrStatus, forKey: .rrStatus)
        try container.encodeIfPresent(spo2, forKey: .spo2)
        try container.encodeIfPresent(spo2Status, forKey: .spo2Status)
        try container.encodeIfPresent(stressScore, forKey: .stressScore)
        try container.encodeIfPresent(stressLevel, forKey: .stressLevel)
        try container.encodeIfPresent(sqi, forKey: .sqi)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(skinLabel, forKey: .skinLabel)
        try container.encodeIfPresent(skinI18n, forKey: .skinI18n)
    }
}

extension Notification.Name {
    static let healthRecordsDidUpdate = Notification.Name("healthRecordsDidUpdate")
}
