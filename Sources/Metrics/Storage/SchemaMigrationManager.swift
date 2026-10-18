import Foundation

/// Manages database schema versioning and migrations
final class SchemaMigrationManager {
    
    // MARK: - Properties
    
    /// Current schema version
    static let currentVersion = 2
    
    /// Database reference
    private let db: SQLiteDatabase
    
    // MARK: - Initialization
    
    init(database: SQLiteDatabase = .shared) {
        self.db = database
    }
    
    // MARK: - Version Management
    
    /// Get current schema version from database
    func currentSchemaVersion() -> Int {
        do {
            let rows = try db.query("SELECT MAX(version) as version FROM schema_version") { stmt in
                SQLiteDatabase.int(stmt, 0)
            }
            return rows.first ?? 0
        } catch {
            print("[Migration] Error getting version: \(error)")
            return 0
        }
    }
    
    /// Check if database needs migration
    func needsMigration() -> Bool {
        currentSchemaVersion() < Self.currentVersion
    }
    
    /// Run all pending migrations
    func runMigrations() throws {
        let current = currentSchemaVersion()
        let target = Self.currentVersion
        
        guard current < target else {
            print("[Migration] Database is up to date (version \(current))")
            return
        }
        
        print("[Migration] Migrating from version \(current) to \(target)")
        
        // Run migrations in order
        for version in (current + 1)...target {
            try migrate(to: version)
        }
        
        print("[Migration] Migration complete")
    }
    
    /// Initialize database with schema
    func initializeSchema() throws {
        // Create schema_version table first
        try db.execute("""
            CREATE TABLE IF NOT EXISTS schema_version (
                version     INTEGER PRIMARY KEY,
                applied_at  TEXT NOT NULL,
                description TEXT
            );
        """)
        
        // Run migrations if needed
        try runMigrations()
    }
    
    // MARK: - Migrations
    
    /// Migrate to a specific version
    private func migrate(to version: Int) throws {
        switch version {
        case 1:
            try migrateToV1()
        case 2:
            try migrateToV2()
        default:
            throw MigrationError.unknownVersion(version)
        }
    }
    
    /// Version 1: Initial schema
    private func migrateToV1() throws {
        let sql = """
        -- Raw readings table (core table, append-only)
        CREATE TABLE IF NOT EXISTS raw_readings (
            id              TEXT PRIMARY KEY,
            schema_version  INTEGER NOT NULL DEFAULT 1,
            profile_id      TEXT NOT NULL,
            metric_type     TEXT NOT NULL,
            source          TEXT NOT NULL,
            source_name     TEXT NOT NULL,
            source_version  TEXT,
            timestamp       REAL NOT NULL,
            received_at     REAL NOT NULL,
            value           REAL NOT NULL,
            unit            TEXT NOT NULL,
            accuracy        INTEGER NOT NULL,
            payload_type    TEXT,
            payload_json    TEXT,
            created_at      REAL NOT NULL DEFAULT (strftime('%s','now')),
            sync_status     INTEGER NOT NULL DEFAULT 0,
            sync_id         TEXT,
            synced_at       REAL,
            sync_retry_count INTEGER DEFAULT 0
        );
        
        -- Indexes for raw_readings
        CREATE INDEX IF NOT EXISTS idx_readings_profile_metric_time
            ON raw_readings(profile_id, metric_type, timestamp DESC);
        
        CREATE INDEX IF NOT EXISTS idx_readings_profile_time
            ON raw_readings(profile_id, timestamp DESC);
        
        CREATE INDEX IF NOT EXISTS idx_readings_metric_source
            ON raw_readings(metric_type, source, timestamp DESC);
        
        CREATE INDEX IF NOT EXISTS idx_readings_sync
            ON raw_readings(sync_status, received_at);
        
        -- Family profiles table
        CREATE TABLE IF NOT EXISTS profiles (
            id              TEXT PRIMARY KEY,
            name            TEXT NOT NULL,
            avatar          TEXT,
            relationship    TEXT NOT NULL,
            birth_year      INTEGER,
            gender          TEXT,
            created_at      REAL NOT NULL DEFAULT (strftime('%s','now')),
            updated_at      REAL NOT NULL DEFAULT (strftime('%s','now'))
        );
        
        -- Device bindings table
        CREATE TABLE IF NOT EXISTS device_bindings (
            device_type         TEXT NOT NULL,
            device_name         TEXT NOT NULL,
            primary_profile_id  TEXT NOT NULL REFERENCES profiles(id),
            created_at          REAL NOT NULL DEFAULT (strftime('%s','now')),
            PRIMARY KEY (device_type)
        );
        
        -- Fusion policies table
        CREATE TABLE IF NOT EXISTS fusion_policies (
            metric_type         TEXT PRIMARY KEY,
            strategy            TEXT NOT NULL DEFAULT 'highestAccuracy',
            preferred_source    TEXT,
            updated_at          REAL NOT NULL DEFAULT (strftime('%s','now'))
        );
        """
        
        try db.execute(sql)
        
        // Record migration
        try recordMigration(version: 1, description: "Initial schema with raw_readings, profiles, device_bindings, fusion_policies")
    }

    /// Version 2: Extend profiles with owner/source-of-truth fields
    private func migrateToV2() throws {
        let sql = """
        ALTER TABLE profiles ADD COLUMN height_cm REAL;
        ALTER TABLE profiles ADD COLUMN weight_kg REAL;
        ALTER TABLE profiles ADD COLUMN blood_type TEXT;
        """

        for statement in sql.split(separator: ";") {
            let trimmed = statement.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            do {
                try db.execute(trimmed + ";")
            } catch {
                let message = error.localizedDescription.lowercased()
                if message.contains("duplicate column") || message.contains("already exists") {
                    continue
                }
                throw error
            }
        }

        try recordMigration(version: 2, description: "Extend profiles with height_cm, weight_kg, blood_type")
    }
    
    /// Record a completed migration
    private func recordMigration(version: Int, description: String) throws {
        let appliedAt = ISO8601DateFormatter().string(from: Date())
        try db.insert(table: "schema_version", values: [
            "version": version,
            "applied_at": appliedAt,
            "description": description
        ])
        
        print("[Migration] Applied version \(version): \(description)")
    }
}

// MARK: - Error

enum MigrationError: Error, LocalizedError {
    case unknownVersion(Int)
    case migrationFailed(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .unknownVersion(let v): return "Unknown schema version: \(v)"
        case .migrationFailed(let v, let msg): return "Migration to v\(v) failed: \(msg)"
        }
    }
}

// MARK: - Convenience

extension SQLiteDatabase {
    /// Initialize database with schema
    func initialize() throws {
        try open()
        let manager = SchemaMigrationManager(database: self)
        try manager.initializeSchema()
    }
}
