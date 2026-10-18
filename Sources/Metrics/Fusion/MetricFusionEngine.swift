import Foundation
import Combine

/// Engine for fusing multiple raw readings into a single display value.
/// Applies configurable fusion strategies per metric type.
final class MetricFusionEngine {
    
    // MARK: - Singleton
    
    static let shared = MetricFusionEngine()
    
    // MARK: - Properties
    
    /// Health metric store
    private let store: HealthMetricStore
    
    /// Cached policies (loaded from DB on init)
    private var policies: [HealthMetricType: FusionPolicy] = [:]
    
    /// Notification when a fused metric is updated
    let fusedMetricUpdated = PassthroughSubject<FusedMetric, Never>()
    
    // MARK: - Initialization
    
    init(store: HealthMetricStore = .shared) {
        self.store = store
    }
    
    // MARK: - Fusion
    
    /// Fuse readings for a specific metric and profile.
    /// Returns the best single FusedMetric based on the active policy.
    func fuse(
        readings: [RawReading],
        for metric: HealthMetricType
    ) -> FusedMetric? {
        guard !readings.isEmpty else { return nil }
        
        // Single source — no fusion needed
        if readings.count == 1, let reading = readings.first {
            return FusedMetric.from(reading: reading)
        }
        
        let policy = self.policy(for: metric)
        
        switch policy.strategy {
        case .highestAccuracy:
            return fuseByHighestAccuracy(readings: readings, policy: policy)
        case .mostRecent:
            return fuseByMostRecent(readings: readings, policy: policy)
        case .average:
            return fuseByAverage(readings: readings, policy: policy)
        case .userPreferred:
            return fuseByUserPreferred(readings: readings, policy: policy)
        }
    }
    
    /// Fuse latest readings for a metric and profile from the store
    func fuseLatest(
        for metric: HealthMetricType,
        profileId: String,
        windowMinutes: Int = 30
    ) -> FusedMetric? {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-Double(windowMinutes) * 60)
        
        guard let readings = try? store.readings(
            for: metric,
            profileId: profileId,
            from: startDate,
            to: endDate
        ), !readings.isEmpty else {
            // Fallback to latest single reading
            guard let latest = try? store.latestReading(for: metric, profileId: profileId) else {
                return nil
            }
            return FusedMetric.from(reading: latest)
        }
        
        return fuse(readings: readings, for: metric)
    }
    
    /// Fuse all metrics for a profile's daily view
    func fuseDailyMetrics(date: Date, profileId: String) -> [FusedMetric] {
        guard let readings = try? store.dailyReadings(date: date, profileId: profileId) else {
            return []
        }
        
        // Group by metric type
        let grouped = Dictionary(grouping: readings, by: { $0.metricType })
        
        var results: [FusedMetric] = []
        for (metric, metricReadings) in grouped {
            if let fused = fuse(readings: metricReadings, for: metric) {
                results.append(fused)
            }
        }
        
        return results
    }
    
    // MARK: - Strategy Implementations
    
    /// Pick the reading with the highest accuracy; ties go to most recent
    private func fuseByHighestAccuracy(readings: [RawReading], policy: FusionPolicy) -> FusedMetric? {
        let sorted = readings.sorted { a, b in
            if a.accuracy != b.accuracy {
                return a.accuracy > b.accuracy
            }
            return a.timestamp > b.timestamp
        }
        
        guard let best = sorted.first else { return nil }
        return FusedMetric.from(readings: readings, strategy: policy.strategy, selectedReading: best)
    }
    
    /// Pick the most recent reading by timestamp
    private func fuseByMostRecent(readings: [RawReading], policy: FusionPolicy) -> FusedMetric? {
        let sorted = readings.sorted { $0.timestamp > $1.timestamp }
        guard let best = sorted.first else { return nil }
        return FusedMetric.from(readings: readings, strategy: policy.strategy, selectedReading: best)
    }
    
    /// Average all readings' values
    private func fuseByAverage(readings: [RawReading], policy: FusionPolicy) -> FusedMetric? {
        guard !readings.isEmpty else { return nil }
        
        let avgValue = readings.map { $0.value }.reduce(0, +) / Double(readings.count)
        let mostRecent = readings.sorted { $0.timestamp > $1.timestamp }.first!
        
        return FusedMetric(
            id: UUID().uuidString,
            profileId: mostRecent.profileId,
            metricType: mostRecent.metricType,
            value: avgValue,
            unit: mostRecent.unit,
            timestamp: mostRecent.timestamp,
            source: mostRecent.source,
            sourceName: "多来源平均",
            accuracy: mostRecent.accuracy,
            allReadings: readings,
            fusionStrategy: policy.strategy
        )
    }
    
    /// Pick the reading from the user's preferred source
    private func fuseByUserPreferred(readings: [RawReading], policy: FusionPolicy) -> FusedMetric? {
        // Try user-preferred source first
        if let preferred = policy.preferredSource {
            let fromPreferred = readings.filter { $0.source == preferred }
            if let best = fromPreferred.sorted(by: { $0.timestamp > $1.timestamp }).first {
                return FusedMetric.from(readings: readings, strategy: policy.strategy, selectedReading: best)
            }
        }
        
        // Fallback to highest accuracy
        return fuseByHighestAccuracy(readings: readings, policy: policy)
    }
    
    // MARK: - Policy Management
    
    /// Get the fusion policy for a metric type
    func policy(for metric: HealthMetricType) -> FusionPolicy {
        // Check cache first
        if let cached = policies[metric] {
            return cached
        }
        
        // Try loading from database
        if let dbPolicy = try? store.fusionPolicy(for: metric) {
            policies[metric] = dbPolicy
            return dbPolicy
        }
        
        // Return default
        return FusionPolicy.default(for: metric)
    }
    
    /// Set the fusion policy for a metric type
    func setPolicy(_ policy: FusionPolicy, for metric: HealthMetricType) {
        policies[metric] = policy
        try? store.saveFusionPolicy(policy)
    }
    
    /// Reset policy to default for a metric
    func resetPolicy(for metric: HealthMetricType) {
        let defaultPolicy = FusionPolicy.default(for: metric)
        setPolicy(defaultPolicy, for: metric)
    }
    
    /// Reset all policies to defaults
    func resetAllPolicies() {
        policies.removeAll()
        for metric in HealthMetricType.allCases {
            resetPolicy(for: metric)
        }
    }
    
    /// Reload policies from database
    func reloadPolicies() {
        policies.removeAll()
        for metric in HealthMetricType.allCases {
            _ = policy(for: metric)
        }
    }
}
