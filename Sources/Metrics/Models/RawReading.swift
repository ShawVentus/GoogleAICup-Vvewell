import Foundation

/// Raw health reading from any device source.
/// All readings are preserved (append-only) for fusion and history.
struct RawReading: Identifiable, Codable {
    // MARK: - Core Fields
    
    /// Unique identifier (UUID)
    let id: String
    
    /// Schema version for migration support
    var schemaVersion: Int = 1
    
    /// Owner profile ID (family member)
    let profileId: String
    
    /// Type of health metric
    let metricType: HealthMetricType
    
    /// Device source
    let source: MetricSourceDevice
    
    /// Device display name (e.g., "Vvewell Ring")
    let sourceName: String
    
    /// Device firmware/software version
    let sourceVersion: String?
    
    /// Measurement timestamp (device time, Unix timestamp)
    let timestamp: Double
    
    /// Reception timestamp (phone time, Unix timestamp)
    let receivedAt: Double
    
    /// Primary value (meaning depends on metricType)
    let value: Double
    
    /// Unit string
    let unit: String
    
    /// Accuracy level
    let accuracy: ReadingAccuracy
    
    /// Payload type (for complex data)
    let payloadType: String?
    
    /// JSON-encoded payload data
    let payloadJson: String?
    
    // MARK: - Sync Fields
    
    /// Sync status (0=local, 1=pending, 2=uploading, 3=synced, 4=failed)
    var syncStatus: SyncStatus = .local
    
    /// Cloud-assigned ID after sync
    var syncId: String?
    
    /// Timestamp of successful sync
    var syncedAt: Double?
    
    /// Number of sync retry attempts
    var syncRetryCount: Int = 0
    
    // MARK: - Metadata
    
    /// Record creation timestamp
    let createdAt: Double
}

// MARK: - Initialization

extension RawReading {
    /// Create a new raw reading
    init(
        id: String = UUID().uuidString,
        profileId: String,
        metricType: HealthMetricType,
        source: MetricSourceDevice,
        sourceName: String,
        sourceVersion: String? = nil,
        timestamp: Date = Date(),
        value: Double,
        unit: String? = nil,
        accuracy: ReadingAccuracy? = nil,
        payload: ReadingPayload? = nil
    ) {
        self.id = id
        self.profileId = profileId
        self.metricType = metricType
        self.source = source
        self.sourceName = sourceName
        self.sourceVersion = sourceVersion
        self.timestamp = timestamp.timeIntervalSince1970
        self.receivedAt = Date().timeIntervalSince1970
        self.value = value
        self.unit = unit ?? metricType.defaultUnit
        self.accuracy = accuracy ?? source.defaultAccuracy
        self.payloadType = payload?.type
        self.payloadJson = payload?.toJsonString()
        self.createdAt = Date().timeIntervalSince1970
    }
    
    /// Create from Ring SDK measurement result
    init(
        from sdkResult: [String: Any],
        profileId: String,
        sourceName: String = "Vvewell Ring",
        sourceVersion: String? = nil
    ) {
        self.id = (sdkResult["id"] as? String) ?? UUID().uuidString
        self.profileId = profileId
        
        // Map SDK measurement type
        if let typeCode = sdkResult["measureType"] as? UInt8,
           let metricType = HealthMetricType.from(ringSDKCode: typeCode) {
            self.metricType = metricType
        } else if let typeString = sdkResult["metricType"] as? String,
                  let metricType = HealthMetricType(rawValue: typeString) {
            self.metricType = metricType
        } else {
            self.metricType = .heartRate // fallback
        }
        
        self.source = .ring
        self.sourceName = sourceName
        self.sourceVersion = sourceVersion
        
        // Timestamp
        if let time = sdkResult["measurementTime"] as? Date {
            self.timestamp = time.timeIntervalSince1970
        } else if let timeInterval = sdkResult["timestamp"] as? Double {
            self.timestamp = timeInterval
        } else {
            self.timestamp = Date().timeIntervalSince1970
        }
        self.receivedAt = Date().timeIntervalSince1970
        
        // Value
        if let floatValue = sdkResult["measurementResult"] as? Float {
            self.value = Double(floatValue)
        } else if let doubleValue = sdkResult["value"] as? Double {
            self.value = doubleValue
        } else {
            self.value = 0
        }
        
        self.unit = metricType.defaultUnit
        self.accuracy = .consumer
        self.payloadType = nil
        self.payloadJson = nil
        self.createdAt = Date().timeIntervalSince1970
    }
}

// MARK: - Date Helpers

extension RawReading {
    /// Measurement date
    var date: Date {
        Date(timeIntervalSince1970: timestamp)
    }
    
    /// Reception date
    var receivedDate: Date {
        Date(timeIntervalSince1970: receivedAt)
    }
    
    /// Creation date
    var createdDate: Date {
        Date(timeIntervalSince1970: createdAt)
    }
}

// MARK: - Payload Access

extension RawReading {
    /// Decode payload to specific type
    func payload<T: ReadingPayload>() -> T? {
        guard let json = payloadJson else { return nil }
        return T.fromJsonString(json)
    }
    
    /// Whether this reading has a payload
    var hasPayload: Bool {
        payloadJson != nil
    }
}

// MARK: - Sync Status

/// Sync status for cloud synchronization
enum SyncStatus: Int, Codable {
    case local = 0      // Local only, not synced
    case pending = 1    // Waiting for sync
    case uploading = 2  // Currently uploading
    case synced = 3     // Successfully synced
    case failed = 4     // Sync failed
}

// MARK: - Database Mapping

extension RawReading {
    /// Create from database row
    init?(from row: [String: Any]) {
        guard let id = row["id"] as? String,
              let profileId = row["profile_id"] as? String,
              let metricTypeString = row["metric_type"] as? String,
              let metricType = HealthMetricType(rawValue: metricTypeString),
              let sourceString = row["source"] as? String,
              let source = MetricSourceDevice(rawValue: sourceString),
              let sourceName = row["source_name"] as? String,
              let timestamp = row["timestamp"] as? Double,
              let receivedAt = row["received_at"] as? Double,
              let value = row["value"] as? Double,
              let unit = row["unit"] as? String,
              let accuracyInt = row["accuracy"] as? Int,
              let accuracy = ReadingAccuracy(rawValue: accuracyInt),
              let createdAt = row["created_at"] as? Double else {
            return nil
        }
        
        self.id = id
        self.schemaVersion = (row["schema_version"] as? Int) ?? 1
        self.profileId = profileId
        self.metricType = metricType
        self.source = source
        self.sourceName = sourceName
        self.sourceVersion = row["source_version"] as? String
        self.timestamp = timestamp
        self.receivedAt = receivedAt
        self.value = value
        self.unit = unit
        self.accuracy = accuracy
        self.payloadType = row["payload_type"] as? String
        self.payloadJson = row["payload_json"] as? String
        self.createdAt = createdAt
        
        // Sync status
        if let syncStatusInt = row["sync_status"] as? Int,
           let status = SyncStatus(rawValue: syncStatusInt) {
            self.syncStatus = status
        }
        self.syncId = row["sync_id"] as? String
        self.syncedAt = row["synced_at"] as? Double
        self.syncRetryCount = (row["sync_retry_count"] as? Int) ?? 0
    }
    
    /// Convert to dictionary for database insertion
    func toDatabaseRow() -> [String: Any] {
        var row: [String: Any] = [
            "id": id,
            "schema_version": schemaVersion,
            "profile_id": profileId,
            "metric_type": metricType.rawValue,
            "source": source.rawValue,
            "source_name": sourceName,
            "timestamp": timestamp,
            "received_at": receivedAt,
            "value": value,
            "unit": unit,
            "accuracy": accuracy.rawValue,
            "created_at": createdAt,
            "sync_status": syncStatus.rawValue,
            "sync_retry_count": syncRetryCount
        ]
        
        if let version = sourceVersion {
            row["source_version"] = version
        }
        if let type = payloadType {
            row["payload_type"] = type
        }
        if let json = payloadJson {
            row["payload_json"] = json
        }
        if let syncId = syncId {
            row["sync_id"] = syncId
        }
        if let syncedAt = syncedAt {
            row["synced_at"] = syncedAt
        }
        
        return row
    }
}
