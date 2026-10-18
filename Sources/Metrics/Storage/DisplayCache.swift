import Foundation
import Combine

/// L4 in-memory display cache for fast UI access.
/// Caches fused metrics for the active profile's recent data (hot tier: 0-7 days).
final class DisplayCache {
    
    // MARK: - Singleton
    
    static let shared = DisplayCache()
    
    // MARK: - Properties
    
    /// Cached fused metrics keyed by (profileId, metricType)
    private var latestMetrics: [String: FusedMetric] = [:]
    
    /// Cached daily metrics keyed by (profileId, dateString)
    private var dailyMetrics: [String: [FusedMetric]] = [:]
    
    /// Cached trend data keyed by (profileId, metricType, days)
    private var trendData: [String: [RawReading]] = [:]
    
    /// Cache expiration interval (5 minutes)
    private let cacheExpiration: TimeInterval = 300
    
    /// Timestamps of last cache updates
    private var lastUpdated: [String: Date] = [:]
    
    /// Serial queue for thread safety
    private let queue = DispatchQueue(label: "com.vvewell.health.displaycache", qos: .userInitiated)
    
    /// Publisher for latest metric updates
    let latestMetricUpdated = PassthroughSubject<FusedMetric, Never>()
    
    /// Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Dependencies
    private let store: HealthMetricStore
    private let fusionEngine: MetricFusionEngine
    
    // MARK: - Initialization
    
    init(store: HealthMetricStore = .shared, fusionEngine: MetricFusionEngine = .shared) {
        self.store = store
        self.fusionEngine = fusionEngine
        
        // Subscribe to new readings
        store.readingSaved
            .sink { [weak self] reading in
                self?.handleNewReading(reading)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Read
    
    /// Get latest fused metric for a profile and metric type
    func latestMetric(profileId: String, metric: HealthMetricType) -> FusedMetric? {
        let key = cacheKey(profileId: profileId, metric: metric)
        
        return queue.sync {
            // Check cache validity
            if let cached = latestMetrics[key], isCacheValid(for: key) {
                return cached
            }
            
            // Refresh from fusion engine
            guard let fused = fusionEngine.fuseLatest(for: metric, profileId: profileId) else {
                return nil
            }
            
            latestMetrics[key] = fused
            lastUpdated[key] = Date()
            return fused
        }
    }
    
    /// Get all latest fused metrics for a profile (dashboard)
    func allLatestMetrics(profileId: String) -> [FusedMetric] {
        HealthMetricType.allCases.compactMap { metric in
            latestMetric(profileId: profileId, metric: metric)
        }
    }
    
    /// Get daily fused metrics for a profile
    func dailyMetrics(profileId: String, date: Date) -> [FusedMetric] {
        let dateString = Self.dateFormatter.string(from: date)
        let key = "\(profileId):\(dateString)"
        
        return queue.sync {
            if let cached = dailyMetrics[key], isCacheValid(for: key) {
                return cached
            }
            
            let fused = fusionEngine.fuseDailyMetrics(date: date, profileId: profileId)
            dailyMetrics[key] = fused
            lastUpdated[key] = Date()
            return fused
        }
    }
    
    /// Get trend data for a metric
    func trend(profileId: String, metric: HealthMetricType, days: Int) -> [RawReading] {
        let key = "\(profileId):\(metric.rawValue):\(days)"
        
        let readings: [RawReading] = queue.sync {
            if let cached = trendData[key], isCacheValid(for: key) {
                return cached
            }
            
            guard let readings = try? store.trend(for: metric, profileId: profileId, days: days) else {
                return []
            }
            
            trendData[key] = readings
            lastUpdated[key] = Date()
            return readings
        }

        return readings
    }
    
    // MARK: - Invalidation
    
    /// Invalidate all caches for a profile
    func invalidate(profileId: String) {
        queue.sync {
            latestMetrics = latestMetrics.filter { !$0.key.hasPrefix(profileId) }
            dailyMetrics = dailyMetrics.filter { !$0.key.hasPrefix(profileId) }
            trendData = trendData.filter { !$0.key.hasPrefix(profileId) }
            lastUpdated = lastUpdated.filter { !$0.key.hasPrefix(profileId) }
        }
    }
    
    /// Invalidate cache for a specific metric
    func invalidate(profileId: String, metric: HealthMetricType) {
        let key = cacheKey(profileId: profileId, metric: metric)
        queue.sync {
            latestMetrics.removeValue(forKey: key)
            lastUpdated.removeValue(forKey: key)
            
            // Also invalidate daily and trend caches for this metric
            let prefix = "\(profileId):\(metric.rawValue)"
            trendData = trendData.filter { !$0.key.hasPrefix(prefix) }
        }
    }
    
    /// Clear all caches
    func clearAll() {
        queue.sync {
            latestMetrics.removeAll()
            dailyMetrics.removeAll()
            trendData.removeAll()
            lastUpdated.removeAll()
        }
    }
    
    // MARK: - Private
    
    /// Handle new reading by updating relevant caches
    private func handleNewReading(_ reading: RawReading) {
        // Invalidate affected caches
        invalidate(profileId: reading.profileId, metric: reading.metricType)
        
        // Re-fuse and cache
        if let fused = fusionEngine.fuseLatest(for: reading.metricType, profileId: reading.profileId) {
            let key = cacheKey(profileId: reading.profileId, metric: reading.metricType)
            queue.sync {
                latestMetrics[key] = fused
                lastUpdated[key] = Date()
            }
            latestMetricUpdated.send(fused)
        }
    }
    
    /// Generate cache key
    private func cacheKey(profileId: String, metric: HealthMetricType) -> String {
        "\(profileId):\(metric.rawValue)"
    }
    
    /// Check if cache entry is still valid
    private func isCacheValid(for key: String) -> Bool {
        guard let updated = lastUpdated[key] else { return false }
        return Date().timeIntervalSince(updated) < cacheExpiration
    }
    
    /// Date formatter for daily cache keys
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
