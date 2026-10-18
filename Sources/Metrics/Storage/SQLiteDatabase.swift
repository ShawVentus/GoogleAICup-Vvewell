import Foundation
import SQLite3

/// Lightweight SQLite database wrapper for health data storage
final class SQLiteDatabase {
    
    // MARK: - Singleton
    
    static let shared = SQLiteDatabase()
    
    // MARK: - Properties
    
    /// Database file name
    static let databaseFileName = "vvewell_health.db"
    
    /// Database connection handle
    private var db: OpaquePointer?
    
    /// Serial queue for thread-safe database operations
    private let queue = DispatchQueue(label: "com.vvewell.health.sqlite", qos: .userInitiated)
    
    /// Database file URL
    private var databaseURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(Self.databaseFileName)
    }
    
    /// Whether database is open
    private(set) var isOpen = false
    
    // MARK: - Initialization
    
    private init() {}
    
    deinit {
        close()
    }
    
    // MARK: - Open / Close
    
    /// Open database connection
    func open() throws {
        guard !isOpen else { return }
        
        // Create database file if needed
        if !FileManager.default.fileExists(atPath: databaseURL.path) {
            FileManager.default.createFile(atPath: databaseURL.path, contents: nil, attributes: nil)
        }
        
        // Open connection
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        let result = sqlite3_open_v2(databaseURL.path, &db, flags, nil)
        
        guard result == SQLITE_OK, let db = db else {
            throw SQLiteError.openFailed(result)
        }
        
        // Enable foreign keys
        let pragma = "PRAGMA foreign_keys = ON;"
        if sqlite3_exec(db, pragma, nil, nil, nil) != SQLITE_OK {
            print("[SQLite] Warning: Failed to enable foreign keys")
        }
        
        // Enable WAL mode for better concurrency
        let walPragma = "PRAGMA journal_mode = WAL;"
        if sqlite3_exec(db, walPragma, nil, nil, nil) != SQLITE_OK {
            print("[SQLite] Warning: Failed to enable WAL mode")
        }
        
        isOpen = true
        print("[SQLite] Database opened at: \(databaseURL.path)")
    }
    
    /// Close database connection
    func close() {
        guard isOpen, let db = db else { return }
        
        sqlite3_close(db)
        self.db = nil
        isOpen = false
        print("[SQLite] Database closed")
    }
    
    // MARK: - Execute
    
    /// Execute a SQL statement (no results)
    @discardableResult
    func execute(_ sql: String) throws -> Bool {
        guard isOpen, let db = db else {
            throw SQLiteError.notOpen
        }
        
        var errMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)
        
        if result != SQLITE_OK {
            let message = errMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errMsg)
            throw SQLiteError.executeFailed(result, message)
        }
        
        return true
    }
    
    /// Execute a query and map results
    func query<T>(_ sql: String, _ mapper: (OpaquePointer) -> T?) throws -> [T] {
        guard isOpen, let db = db else {
            throw SQLiteError.notOpen
        }
        
        var stmt: OpaquePointer?
        var results: [T] = []
        
        // Prepare statement
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        guard let stmt else { throw SQLiteError.prepareFailed }
        
        // Step through results
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let value = mapper(stmt) {
                results.append(value)
            }
        }
        
        return results
    }
    
    /// Execute a query with parameters
    func query<T>(_ sql: String, params: [Any], _ mapper: (OpaquePointer) -> T?) throws -> [T] {
        guard isOpen, let db = db else {
            throw SQLiteError.notOpen
        }
        
        var stmt: OpaquePointer?
        var results: [T] = []
        
        // Prepare statement
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        guard let stmt else { throw SQLiteError.prepareFailed }
        
        // Bind parameters
        for (index, param) in params.enumerated() {
            bind(param, to: stmt, at: Int32(index + 1))
        }
        
        // Step through results
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let value = mapper(stmt) {
                results.append(value)
            }
        }
        
        return results
    }
    
    // MARK: - Insert / Update
    
    /// Insert a row and return the row ID
    @discardableResult
    func insert(table: String, values: [String: Any]) throws -> Int64 {
        guard isOpen, let db = db else {
            throw SQLiteError.notOpen
        }
        
        let columns = values.keys.sorted()
        let placeholders = columns.map { _ in "?" }.joined(separator: ", ")
        let sql = "INSERT INTO \(table) (\(columns.joined(separator: ", "))) VALUES (\(placeholders));"
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        guard let stmt else { throw SQLiteError.prepareFailed }
        
        // Bind values
        for (index, column) in columns.enumerated() {
            bind(values[column]!, to: stmt, at: Int32(index + 1))
        }
        
        // Execute
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.executeFailed(sqlite3_errcode(db), "Insert failed")
        }
        
        return sqlite3_last_insert_rowid(db)
    }
    
    /// Update rows matching condition
    @discardableResult
    func update(table: String, values: [String: Any], where condition: String, params: [Any] = []) throws -> Int {
        guard isOpen, let db = db else {
            throw SQLiteError.notOpen
        }

        let sortedKeys = values.keys.sorted()
        let setClause = sortedKeys.map { "\($0) = ?" }.joined(separator: ", ")
        let sql = "UPDATE \(table) SET \(setClause) WHERE \(condition);"
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        guard let stmt else { throw SQLiteError.prepareFailed }
        
        // Bind values
        var bindIndex: Int32 = 1
        for column in sortedKeys {
            bind(values[column]!, to: stmt, at: bindIndex)
            bindIndex += 1
        }
        
        // Bind where params
        for param in params {
            bind(param, to: stmt, at: bindIndex)
            bindIndex += 1
        }
        
        // Execute
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.executeFailed(sqlite3_errcode(db), "Update failed")
        }
        
        return Int(sqlite3_changes(db))
    }
    
    /// Delete rows matching condition
    @discardableResult
    func delete(from table: String, where condition: String, params: [Any] = []) throws -> Int {
        guard isOpen, let db = db else {
            throw SQLiteError.notOpen
        }
        
        let sql = "DELETE FROM \(table) WHERE \(condition);"
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        guard let stmt else { throw SQLiteError.prepareFailed }
        
        // Bind params
        for (index, param) in params.enumerated() {
            bind(param, to: stmt, at: Int32(index + 1))
        }
        
        // Execute
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.executeFailed(sqlite3_errcode(db), "Delete failed")
        }
        
        return Int(sqlite3_changes(db))
    }
    
    // MARK: - Transaction
    
    /// Begin transaction
    func beginTransaction() throws {
        try execute("BEGIN TRANSACTION;")
    }
    
    /// Commit transaction
    func commit() throws {
        try execute("COMMIT;")
    }
    
    /// Rollback transaction
    func rollback() throws {
        try execute("ROLLBACK;")
    }
    
    /// Execute block in transaction
    func inTransaction<T>(_ block: () throws -> T) throws -> T {
        try beginTransaction()
        do {
            let result = try block()
            try commit()
            return result
        } catch {
            try? rollback()
            throw error
        }
    }
    
    // MARK: - Helpers
    
    /// Bind a value to a statement parameter
    private func bind(_ value: Any, to stmt: OpaquePointer, at index: Int32) {
        switch value {
        case let v as String:
            sqlite3_bind_text(stmt, index, (v as NSString).utf8String, -1, nil)
        case let v as Int:
            sqlite3_bind_int64(stmt, index, Int64(v))
        case let v as Int64:
            sqlite3_bind_int64(stmt, index, v)
        case let v as Double:
            sqlite3_bind_double(stmt, index, v)
        case let v as Float:
            sqlite3_bind_double(stmt, index, Double(v))
        case let v as Bool:
            sqlite3_bind_int(stmt, index, v ? 1 : 0)
        case let v as Data:
            sqlite3_bind_blob(stmt, index, (v as NSData).bytes, Int32(v.count), nil)
        case is NSNull:
            sqlite3_bind_null(stmt, index)
        default:
            sqlite3_bind_text(stmt, index, ("\(value)" as NSString).utf8String, -1, nil)
        }
    }
    
    /// Get string value from statement column
    static func string(_ stmt: OpaquePointer, _ column: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, column) else { return nil }
        return String(cString: cString)
    }
    
    /// Get integer value from statement column
    static func int(_ stmt: OpaquePointer, _ column: Int32) -> Int {
        Int(sqlite3_column_int64(stmt, column))
    }
    
    /// Get double value from statement column
    static func double(_ stmt: OpaquePointer, _ column: Int32) -> Double {
        sqlite3_column_double(stmt, column)
    }
    
    /// Get data value from statement column
    static func data(_ stmt: OpaquePointer, _ column: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(stmt, column) else { return nil }
        let count = sqlite3_column_bytes(stmt, column)
        return Data(bytes: bytes, count: Int(count))
    }
    
    /// Run on serial queue
    func run<T>(_ work: () throws -> T) throws -> T {
        try queue.sync { try work() }
    }
    
    /// Run async on serial queue
    func runAsync(_ work: @escaping () throws -> Void) {
        queue.async {
            do { try work() } catch {
                print("[SQLite] Error: \(error)")
            }
        }
    }
}

// MARK: - Error

enum SQLiteError: Error, LocalizedError {
    case notOpen
    case openFailed(Int32)
    case prepareFailed
    case executeFailed(Int32, String)
    case bindingFailed
    case rowMappingFailed
    
    var errorDescription: String? {
        switch self {
        case .notOpen: return "Database is not open"
        case .openFailed(let code): return "Failed to open database (code: \(code))"
        case .prepareFailed: return "Failed to prepare SQL statement"
        case .executeFailed(let code, let msg): return "SQL execution failed (\(code)): \(msg)"
        case .bindingFailed: return "Failed to bind parameter"
        case .rowMappingFailed: return "Failed to map database row"
        }
    }
}
