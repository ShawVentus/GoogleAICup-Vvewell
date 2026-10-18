import Foundation

/// Configuration for cloud sync behavior
struct SyncPolicy {
    /// Sync mode
    var mode: SyncMode = .batch
    
    /// Max readings per batch
    var batchSize: Int = 50
    
    /// Max payload size per batch (bytes)
    var maxPayloadSize: Int = 512_000  // 500 KB
    
    /// Interval between automatic syncs (seconds)
    var syncInterval: TimeInterval = 300  // 5 minutes
    
    /// Whether to sync only on WiFi
    var wifiOnly: Bool = false
    
    /// Max retry attempts per reading
    var retryLimit: Int = 3
    
    /// Retry backoff intervals (seconds)
    var retryBackoff: [TimeInterval] = [2, 4, 8]
    
    /// Default policy
    static let `default` = SyncPolicy()
}

/// Sync mode
enum SyncMode: String, Codable {
    /// Real-time: sync immediately after data write (WiFi only)
    case realtime
    
    /// Batch: periodic batch sync (default)
    case batch
    
    /// Manual: user-triggered only
    case manual
    
    /// WiFi only: pause sync on cellular
    case wifiOnly
}
