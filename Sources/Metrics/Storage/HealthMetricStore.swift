import Foundation
import Combine

/// Public API for health metric data storage and retrieval.
/// Wraps SQLite operations with a clean interface for the rest of the app.
final class HealthMetricStore {
    
    // MARK: - Singleton
    
    static let shared = HealthMetricStore()
    
    // MARK: - Properties
    
    /// Database reference
    private let db: SQLiteDatabase
    
    /// Notification when a new reading is saved
    let readingSaved = PassthroughSubject<RawReading, Never>()
    
    /// Notification when sync status changes
    let syncStatusChanged = PassthroughSubject<(ids: [String], status: SyncStatus), Never>()
    
    // MARK: - Initialization
    
    init(database: SQLiteDatabase = .shared) {
        self.db = database
    }
    
    /// Initialize the store (opens DB, runs migrations)
    func initialize() throws {
        try db.initialize()
    }
    
    // MARK: - Save
    
    /// Save a raw reading to the database
    func save(reading: RawReading) throws {
        // Deduplication check
        let existing = try db.query(
            "SELECT id FROM raw_readings WHERE id = ?",
            params: [reading.id]
        ) { stmt in
            SQLiteDatabase.string(stmt, 0)
        }
        
        guard existing.isEmpty else {
            print("[Store] Duplicate reading \(reading.id), skipping")
            return
        }
        
        // Insert
        let row = reading.toDatabaseRow()
        try db.insert(table: "raw_readings", values: row)
        
        // Notify
        readingSaved.send(reading)
        
        print("[Store] Saved reading: \(reading.metricType.rawValue) = \(reading.value) \(reading.unit)")
    }
    
    /// Save multiple readings in a transaction
    func save(readings: [RawReading]) throws {
        try db.inTransaction {
            for reading in readings {
                try save(reading: reading)
            }
        }
    }
    
    // MARK: - Query: By Metric Type
    
    /// Get readings for a specific metric, profile, and time range
    func readings(
        for metric: HealthMetricType,
        profileId: String,
        from startDate: Date,
        to endDate: Date,
        source: MetricSourceDevice? = nil,
        limit: Int? = nil
    ) throws -> [RawReading] {
        var sql = """
            SELECT * FROM raw_readings
            WHERE profile_id = ? AND metric_type = ?
              AND timestamp >= ? AND timestamp <= ?
        """
        var params: [Any] = [
            profileId,
            metric.rawValue,
            startDate.timeIntervalSince1970,
            endDate.timeIntervalSince1970
        ]
        
        if let source = source {
            sql += " AND source = ?"
            params.append(source.rawValue)
        }
        
        sql += " ORDER BY timestamp DESC"
        
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        
        return try db.query(sql, params: params) { stmt in
            readingFromStatement(stmt)
        }
    }
    
    /// Get latest reading for a metric and profile
    func latestReading(for metric: HealthMetricType, profileId: String) throws -> RawReading? {
        let sql = """
            SELECT * FROM raw_readings
            WHERE profile_id = ? AND metric_type = ?
            ORDER BY timestamp DESC
            LIMIT 1
        """
        
        let results = try db.query(sql, params: [profileId, metric.rawValue]) { stmt in
            readingFromStatement(stmt)
        }
        
        return results.first
    }
    
    /// Get latest readings for all metrics for a profile (for dashboard)
    func latestReadings(profileId: String) throws -> [HealthMetricType: RawReading] {
        let sql = """
            SELECT r.* FROM raw_readings r
            INNER JOIN (
                SELECT metric_type, MAX(timestamp) as max_ts
                FROM raw_readings
                WHERE profile_id = ?
                GROUP BY metric_type
            ) latest ON r.metric_type = latest.metric_type AND r.timestamp = latest.max_ts
            WHERE r.profile_id = ?
        """
        
        let results = try db.query(sql, params: [profileId, profileId]) { stmt in
            readingFromStatement(stmt)
        }
        
        var dict: [HealthMetricType: RawReading] = [:]
        for reading in results {
            dict[reading.metricType] = reading
        }
        return dict
    }
    
    // MARK: - Query: By Profile
    
    /// Get all readings for a profile within a time range (for export)
    func allReadings(
        profileId: String,
        from startDate: Date,
        to endDate: Date
    ) throws -> [RawReading] {
        let sql = """
            SELECT * FROM raw_readings
            WHERE profile_id = ? AND timestamp >= ? AND timestamp <= ?
            ORDER BY timestamp DESC
        """
        
        return try db.query(sql, params: [
            profileId,
            startDate.timeIntervalSince1970,
            endDate.timeIntervalSince1970
        ]) { stmt in
            readingFromStatement(stmt)
        }
    }
    
    /// Get reading count for a profile
    func readingCount(profileId: String) throws -> Int {
        let results = try db.query(
            "SELECT COUNT(*) FROM raw_readings WHERE profile_id = ?",
            params: [profileId]
        ) { stmt in
            SQLiteDatabase.int(stmt, 0)
        }
        return results.first ?? 0
    }
    
    // MARK: - Query: Daily
    
    /// Get all readings for a specific day
    func dailyReadings(date: Date, profileId: String) throws -> [RawReading] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return try allReadings(profileId: profileId, from: startOfDay, to: endOfDay)
    }
    
    // MARK: - Query: Trend
    
    /// Get trend data for a metric over N days
    func trend(
        for metric: HealthMetricType,
        profileId: String,
        days: Int,
        source: MetricSourceDevice? = nil
    ) throws -> [RawReading] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        
        return try readings(for: metric, profileId: profileId, from: startDate, to: endDate, source: source)
    }
    
    // MARK: - Sync Status
    
    /// Get readings by sync status
    func readings(syncStatus: SyncStatus, limit: Int = 50) throws -> [RawReading] {
        let sql = """
            SELECT * FROM raw_readings
            WHERE sync_status = ?
            ORDER BY received_at ASC
            LIMIT ?
        """
        
        return try db.query(sql, params: [syncStatus.rawValue, limit]) { stmt in
            readingFromStatement(stmt)
        }
    }
    
    /// Update sync status for readings
    func updateSyncStatus(
        ids: [String],
        status: SyncStatus,
        syncId: String? = nil,
        incrementRetry: Bool = false
    ) throws {
        guard !ids.isEmpty else { return }
        
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        
        var setClauses = ["sync_status = ?"]
        var params: [Any] = [status.rawValue]
        
        if let syncId = syncId {
            setClauses.append("sync_id = ?")
            params.append(syncId)
        }
        
        if status == .synced {
            setClauses.append("synced_at = ?")
            params.append(Date().timeIntervalSince1970)
        }
        
        if incrementRetry {
            setClauses.append("sync_retry_count = sync_retry_count + 1")
        }
        
        let sql = """
            UPDATE raw_readings
            SET \(setClauses.joined(separator: ", "))
            WHERE id IN (\(placeholders))
        """
        
        params.append(contentsOf: ids)
        
        // Use execute with manual parameter binding
        try db.execute(sql)
        
        syncStatusChanged.send((ids: ids, status: status))
    }
    
    /// Mark all local readings as pending (for initial sync)
    func markAllAsPending() throws {
        try db.execute("UPDATE raw_readings SET sync_status = 1 WHERE sync_status = 0")
    }
    
    /// Get count of pending readings
    func pendingCount() throws -> Int {
        let results = try db.query(
            "SELECT COUNT(*) FROM raw_readings WHERE sync_status IN (0, 1, 4)",
            params: []
        ) { stmt in
            SQLiteDatabase.int(stmt, 0)
        }
        return results.first ?? 0
    }

    /// Get count of readings for one or more sync statuses
    func count(syncStatuses: [SyncStatus]) throws -> Int {
        guard !syncStatuses.isEmpty else { return 0 }
        let placeholders = Array(repeating: "?", count: syncStatuses.count).joined(separator: ", ")
        let sql = "SELECT COUNT(*) FROM raw_readings WHERE sync_status IN (\(placeholders))"
        let params = syncStatuses.map(\.rawValue)
        let results = try db.query(sql, params: params) { stmt in
            SQLiteDatabase.int(stmt, 0)
        }
        return results.first ?? 0
    }
    
    // MARK: - Delete
    
    /// Delete readings older than a date
    func deleteReadings(olderThan date: Date) throws -> Int {
        try db.delete(
            from: "raw_readings",
            where: "timestamp < ? AND sync_status = ?",
            params: [date.timeIntervalSince1970, SyncStatus.synced.rawValue]
        )
    }
    
    /// Delete all readings for a profile
    func deleteReadings(profileId: String) throws -> Int {
        try db.delete(
            from: "raw_readings",
            where: "profile_id = ?",
            params: [profileId]
        )
    }
    
    // MARK: - Fusion Policies
    
    /// Get fusion policy for a metric
    func fusionPolicy(for metric: HealthMetricType) throws -> FusionPolicy {
        let results = try db.query(
            "SELECT * FROM fusion_policies WHERE metric_type = ?",
            params: [metric.rawValue]
        ) { stmt -> FusionPolicy? in
            let row: [String: Any] = [
                "metric_type": SQLiteDatabase.string(stmt, 0) as Any,
                "strategy": SQLiteDatabase.string(stmt, 1) as Any,
                "preferred_source": SQLiteDatabase.string(stmt, 2) as Any,
                "updated_at": SQLiteDatabase.double(stmt, 3)
            ]
            return FusionPolicy(from: row)
        }
        
        return results.first ?? FusionPolicy.default(for: metric)
    }
    
    /// Save fusion policy
    func saveFusionPolicy(_ policy: FusionPolicy) throws {
        let sql = """
            INSERT OR REPLACE INTO fusion_policies (metric_type, strategy, preferred_source, updated_at)
            VALUES (?, ?, ?, ?)
        """
        try db.execute(sql)
    }
    
    // MARK: - Private Helpers
    
    /// Map a SQLite statement to a RawReading
    private func readingFromStatement(_ stmt: OpaquePointer) -> RawReading? {
        let row: [String: Any] = [
            "id": SQLiteDatabase.string(stmt, 0) as Any,
            "schema_version": SQLiteDatabase.int(stmt, 1),
            "profile_id": SQLiteDatabase.string(stmt, 2) as Any,
            "metric_type": SQLiteDatabase.string(stmt, 3) as Any,
            "source": SQLiteDatabase.string(stmt, 4) as Any,
            "source_name": SQLiteDatabase.string(stmt, 5) as Any,
            "source_version": SQLiteDatabase.string(stmt, 6) as Any,
            "timestamp": SQLiteDatabase.double(stmt, 7),
            "received_at": SQLiteDatabase.double(stmt, 8),
            "value": SQLiteDatabase.double(stmt, 9),
            "unit": SQLiteDatabase.string(stmt, 10) as Any,
            "accuracy": SQLiteDatabase.int(stmt, 11),
            "payload_type": SQLiteDatabase.string(stmt, 12) as Any,
            "payload_json": SQLiteDatabase.string(stmt, 13) as Any,
            "created_at": SQLiteDatabase.double(stmt, 14),
            "sync_status": SQLiteDatabase.int(stmt, 15),
            "sync_id": SQLiteDatabase.string(stmt, 16) as Any,
            "synced_at": SQLiteDatabase.double(stmt, 17),
            "sync_retry_count": SQLiteDatabase.int(stmt, 18)
        ]
        
        return RawReading(from: row)
    }
}
