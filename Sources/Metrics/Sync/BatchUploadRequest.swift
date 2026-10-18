import Foundation
import UIKit

/// Batch upload request model for cloud sync
struct BatchUploadRequest: Codable {
    /// Device identifier
    let deviceId: String
    
    /// App version
    let appVersion: String
    
    /// Unique batch identifier
    let batchId: String
    
    /// Readings to upload
    let readings: [BatchReading]
    
    /// Create from raw readings
    init(readings: [RawReading], deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? "unknown", appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") {
        self.deviceId = deviceId
        self.appVersion = appVersion
        self.batchId = UUID().uuidString
        self.readings = readings.map { BatchReading(from: $0) }
    }
}

/// Single reading in a batch upload
struct BatchReading: Codable {
    let id: String
    let schemaVersion: Int
    let profileId: String
    let metricType: String
    let source: String
    let sourceName: String
    let sourceVersion: String?
    let timestamp: Double
    let receivedAt: Double
    let value: Double
    let unit: String
    let accuracy: Int
    let payloadType: String?
    let payload: String?
    
    /// Create from RawReading
    init(from reading: RawReading) {
        self.id = reading.id
        self.schemaVersion = reading.schemaVersion
        self.profileId = reading.profileId
        self.metricType = reading.metricType.rawValue
        self.source = reading.source.rawValue
        self.sourceName = reading.sourceName
        self.sourceVersion = reading.sourceVersion
        self.timestamp = reading.timestamp
        self.receivedAt = reading.receivedAt
        self.value = reading.value
        self.unit = reading.unit
        self.accuracy = reading.accuracy.rawValue
        self.payloadType = reading.payloadType
        self.payload = reading.payloadJson
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion = "schema_version"
        case profileId = "profile_id"
        case metricType = "metric_type"
        case source
        case sourceName = "source_name"
        case sourceVersion = "source_version"
        case timestamp
        case receivedAt = "received_at"
        case value
        case unit
        case accuracy
        case payloadType = "payload_type"
        case payload
    }
}

/// Batch upload response from cloud
struct BatchUploadResponse: Codable {
    let status: String       // "ok" or "partial"
    let batchId: String
    let accepted: Int
    let rejected: Int
    let results: [BatchResult]
    
    enum CodingKeys: String, CodingKey {
        case status
        case batchId = "batch_id"
        case accepted
        case rejected
        case results
    }
}

/// Individual reading result in batch response
struct BatchResult: Codable {
    let id: String
    let syncId: String?
    let status: String       // "accepted" or "rejected"
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case syncId = "sync_id"
        case status
        case reason
    }
}

/// Sync result summary
struct SyncResult {
    let uploaded: Int
    let failed: Int
    let pendingRemaining: Int
    let duration: TimeInterval
    let blockedReason: SyncBlockReason?
}
