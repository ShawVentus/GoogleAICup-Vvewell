import Foundation
import Combine
import Network

/// Engine for synchronizing local health data to the cloud.
/// Manages batch uploads, retry logic, and sync scheduling.
final class SyncEngine {
    
    // MARK: - Singleton
    
    static let shared = SyncEngine()
    
    // MARK: - Properties
    
    /// Sync policy configuration
    var policy: SyncPolicy
    
    /// Health metric store
    private let store: HealthMetricStore
    
    /// Sync timer
    private var syncTimer: Timer?
    
    /// Whether sync is currently in progress
    private(set) var isSyncing = false
    
    /// Publisher for sync results
    let syncCompleted = PassthroughSubject<SyncResult, Never>()
    
    /// Publisher for sync errors
    let syncError = PassthroughSubject<Error, Never>()

    /// Publisher for sync-status changes that do not necessarily correspond to terminal sync results
    let syncStatusChanged = PassthroughSubject<Void, Never>()
    
    /// Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Serial queue for sync operations
    private let syncQueue = DispatchQueue(label: "com.vvewell.health.sync", qos: .utility)
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "com.vvewell.health.sync.network", qos: .utility)
    private let networkSnapshotLock = NSLock()
    private var networkSnapshot = SyncNetworkSnapshot.unknown
    private let lastSyncDefaultsKey = "sync_engine_last_sync_date"
    
    // MARK: - Initialization
    
    init(store: HealthMetricStore = .shared, policy: SyncPolicy = .default) {
        self.store = store
        self.policy = policy
        startNetworkMonitor()
        NotificationCenter.default.addObserver(
            forName: .authTokenDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleAuthTokenChange()
        }
    }
    
    // MARK: - Start / Stop
    
    /// Start automatic sync scheduling
    func start() {
        guard syncTimer == nil else { return }
        
        debugLog("[Sync] Starting sync engine (interval: \(policy.syncInterval)s)")
        
        // Schedule periodic sync
        syncTimer = Timer.scheduledTimer(
            withTimeInterval: policy.syncInterval,
            repeats: true
        ) { [weak self] _ in
            self?.performSyncIfNeeded()
        }
        
        // Also subscribe to new readings for real-time mode
        if policy.mode == .realtime {
            store.readingSaved
                .debounce(for: .seconds(2), scheduler: syncQueue)
                .sink { [weak self] _ in
                    self?.performSyncIfNeeded()
                }
                .store(in: &cancellables)
        }
        
        // Initial sync
        performSyncIfNeeded()
    }
    
    /// Stop automatic sync
    func stop() {
        syncTimer?.invalidate()
        syncTimer = nil
        cancellables.removeAll()
        debugLog("[Sync] Sync engine stopped")
    }
    
    /// Manually trigger a sync
    func syncNow(completion: ((SyncResult?) -> Void)? = nil) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            let result = self.performSync()
            DispatchQueue.main.async {
                self.syncStatusChanged.send(())
                completion?(result)
            }
        }
    }

    /// Record a successful cloud refresh / reconciliation even when no local upload batch ran.
    func recordManualRefresh() {
        lastSyncDate = Date()
        DispatchQueue.main.async { [weak self] in
            self?.syncStatusChanged.send(())
        }
    }
    
    // MARK: - Sync Logic
    
    /// Check if sync is needed and perform if so
    private func performSyncIfNeeded() {
        syncQueue.async { [weak self] in
            guard let self = self, !self.isSyncing else { return }
            
            // Check if there are pending readings
            guard let pendingCount = try? self.store.pendingCount(), pendingCount > 0 else {
                return
            }

            let network = self.currentNetworkSnapshot()
            guard network.isReachable else { return }
            
            // Check WiFi-only constraint
            if (self.policy.wifiOnly || self.policy.mode == .wifiOnly), !network.isOnWiFi {
                return
            }
            
            _ = self.performSync()
        }
    }
    
    /// Perform a single sync cycle
    private func performSync() -> SyncResult? {
        guard !isSyncing else { return nil }
        let initialPending = (try? store.pendingCount()) ?? 0
        if Config.useRelay, !AuthTokenManager.shared.isLoggedIn {
            return SyncResult(
                uploaded: 0,
                failed: 0,
                pendingRemaining: initialPending,
                duration: 0,
                blockedReason: .requiresLogin
            )
        }
        let network = currentNetworkSnapshot()

        if !network.isReachable {
            return SyncResult(
                uploaded: 0,
                failed: 0,
                pendingRemaining: initialPending,
                duration: 0,
                blockedReason: .networkUnavailable
            )
        }

        if (policy.wifiOnly || policy.mode == .wifiOnly), !network.isOnWiFi {
            return SyncResult(
                uploaded: 0,
                failed: 0,
                pendingRemaining: initialPending,
                duration: 0,
                blockedReason: .waitingForWiFi
            )
        }

        isSyncing = true
        defer { isSyncing = false }
        
        let startTime = Date()
        var totalUploaded = 0
        var totalFailed = 0
        
        // Mark local readings as pending
        try? store.markAllAsPending()
        
        // Process in batches
        while true {
            guard let pending = try? store.readings(syncStatus: .pending, limit: policy.batchSize),
                  !pending.isEmpty else {
                break
            }
            
            // Mark as uploading
            let ids = pending.map { $0.id }
            try? store.updateSyncStatus(ids: ids, status: .uploading)
            
            // Build batch request
            let batch = BatchUploadRequest(readings: pending)
            
            // Upload (synchronous for simplicity in sync queue)
            let uploadResult = uploadBatch(batch)
            
            switch uploadResult {
            case .success(let response):
                // Process individual results
                for result in response.results {
                    if result.status == "accepted" {
                        try? store.updateSyncStatus(
                            ids: [result.id],
                            status: .synced,
                            syncId: result.syncId
                        )
                        totalUploaded += 1
                    } else {
                        try? store.updateSyncStatus(
                            ids: [result.id],
                            status: .failed,
                            incrementRetry: true
                        )
                        totalFailed += 1
                    }
                }
                
            case .failure(let error):
                // Mark all as failed
                try? store.updateSyncStatus(
                    ids: ids,
                    status: .failed,
                    incrementRetry: true
                )
                totalFailed += ids.count
                
                debugLog("[Sync] Batch upload failed: \(error.localizedDescription)")
                syncError.send(error)
                break  // Stop syncing on error
            }
        }
        
        // Handle retries for failed readings
        retryFailedReadings()
        
        let pendingRemaining = (try? store.pendingCount()) ?? 0
        let duration = Date().timeIntervalSince(startTime)
        
        let result = SyncResult(
            uploaded: totalUploaded,
            failed: totalFailed,
            pendingRemaining: pendingRemaining,
            duration: duration,
            blockedReason: nil
        )

        if totalUploaded > 0 || (totalFailed == 0 && pendingRemaining == 0) {
            lastSyncDate = Date()
        }
        
        if totalUploaded > 0 || totalFailed > 0 {
            debugLog("[Sync] Completed: \(totalUploaded) uploaded, \(totalFailed) failed, \(pendingRemaining) pending")
            syncCompleted.send(result)
        }

        syncStatusChanged.send(())
        
        return result
    }
    
    // MARK: - Upload
    
    /// Upload a batch to the relay server via HTTPS POST.
    private func uploadBatch(_ batch: BatchUploadRequest) -> Result<BatchUploadResponse, Error> {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        guard let jsonData = try? encoder.encode(batch) else {
            return .failure(SyncError.encodingFailed)
        }
        
        if jsonData.count > policy.maxPayloadSize {
            return .failure(SyncError.payloadTooLarge(jsonData.count))
        }
        
        let baseURL = Config.apiBaseURL
        guard let url = URL(string: "\(baseURL)/api/v1/health/readings/batch") else {
            return .failure(SyncError.encodingFailed)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        AuthTokenManager.shared.authorizeRequest(&request)
        request.httpBody = jsonData
        
        debugLog("[Sync] Uploading batch \(batch.batchId): \(batch.readings.count) readings, \(jsonData.count) bytes")
        
        // Synchronous network call (executed on syncQueue background thread)
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<BatchUploadResponse, Error> = .failure(SyncError.encodingFailed)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                result = .failure(error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                result = .failure(SyncError.encodingFailed)
                return
            }
            
            guard httpResponse.statusCode == 200, let data = data else {
                result = .failure(SyncError.uploadFailed(httpResponse.statusCode))
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                let batchResponse = try decoder.decode(BatchUploadResponse.self, from: data)
                result = .success(batchResponse)
            } catch {
                result = .failure(SyncError.encodingFailed)
            }
        }
        task.resume()
        semaphore.wait()
        
        return result
    }
    
    // MARK: - Retry
    
    /// Retry failed readings that haven't exceeded retry limit
    private func retryFailedReadings() {
        guard let failed = try? store.readings(syncStatus: .failed, limit: policy.batchSize) else {
            return
        }
        
        // Filter by retry count
        let retryable = failed.filter { $0.syncRetryCount < policy.retryLimit }
        
        if retryable.isEmpty { return }
        
        // Calculate backoff delay
        let maxRetryCount = retryable.map { $0.syncRetryCount }.max() ?? 0
        let backoffIndex = min(maxRetryCount, policy.retryBackoff.count - 1)
        let delay = policy.retryBackoff[backoffIndex]
        
        debugLog("[Sync] Scheduling retry for \(retryable.count) readings in \(delay)s")
        
        // Schedule retry after backoff
        syncQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            let ids = retryable.map { $0.id }
            try? self.store.updateSyncStatus(ids: ids, status: .pending)
        }
    }
    
    // MARK: - Status
    
    /// Get current sync status summary
    func statusSummary() -> SyncStatusSummary {
        let localCount = (try? store.count(syncStatuses: [.local])) ?? 0
        let pendingCount = (try? store.count(syncStatuses: [.pending])) ?? 0
        let failedCount = (try? store.count(syncStatuses: [.failed])) ?? 0
        let uploadingCount = (try? store.count(syncStatuses: [.uploading])) ?? 0
        let blockedReason: SyncBlockReason?
        let unsyncedCount = localCount + pendingCount + failedCount + uploadingCount
        let network = currentNetworkSnapshot()
        if Config.useRelay, !AuthTokenManager.shared.isLoggedIn, unsyncedCount > 0 {
            blockedReason = .requiresLogin
        } else if !network.isReachable {
            blockedReason = .networkUnavailable
        } else if (policy.wifiOnly || policy.mode == .wifiOnly), !network.isOnWiFi {
            blockedReason = .waitingForWiFi
        } else {
            blockedReason = nil
        }
        
        return SyncStatusSummary(
            isSyncing: isSyncing,
            localCount: localCount,
            pendingCount: pendingCount,
            failedCount: failedCount,
            uploadingCount: uploadingCount,
            lastSyncDate: lastSyncDate,
            mode: policy.mode,
            blockedReason: blockedReason
        )
    }

    private func startNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.updateNetworkSnapshot(SyncNetworkSnapshot(path: path))
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    private func handleAuthTokenChange() {
        DispatchQueue.main.async { [weak self] in
            self?.syncStatusChanged.send(())
        }

        guard Config.useRelay, AuthTokenManager.shared.isLoggedIn else { return }
        performSyncIfNeeded()
    }

    private func currentNetworkSnapshot() -> SyncNetworkSnapshot {
        networkSnapshotLock.lock()
        defer { networkSnapshotLock.unlock() }
        return networkSnapshot
    }

    private func updateNetworkSnapshot(_ snapshot: SyncNetworkSnapshot) {
        networkSnapshotLock.lock()
        let changed = networkSnapshot.isReachable != snapshot.isReachable || networkSnapshot.isOnWiFi != snapshot.isOnWiFi
        networkSnapshot = snapshot
        networkSnapshotLock.unlock()
        if changed {
            DispatchQueue.main.async { [weak self] in
                self?.syncStatusChanged.send(())
            }
        }
    }

    private var lastSyncDate: Date? {
        get {
            UserDefaults.standard.object(forKey: lastSyncDefaultsKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastSyncDefaultsKey)
        }
    }

    private func debugLog(_ message: @autoclosure () -> String) {
#if DEBUG
        print(message())
#endif
    }
}

// MARK: - Sync Status Summary

struct SyncStatusSummary {
    let isSyncing: Bool
    let localCount: Int
    let pendingCount: Int
    let failedCount: Int
    let uploadingCount: Int
    let lastSyncDate: Date?
    let mode: SyncMode
    let blockedReason: SyncBlockReason?

    var unsyncedCount: Int {
        localCount + pendingCount + failedCount + uploadingCount
    }
    
    var displayText: String {
        if isSyncing {
            return t(.syncStatusSyncing)
        } else if let blockedReason {
            return blockedReason.displayText
        } else if failedCount > 0 {
            let pendingAfterFailures = max(unsyncedCount - failedCount, 0)
            if pendingAfterFailures > 0 {
                return String(format: t(.syncStatusFailedPendingFormat), failedCount, pendingAfterFailures)
            }
            return "\(t(.syncStatusFailed)) · \(failedCount)"
        } else if unsyncedCount > 0 {
            return "\(t(.syncStatusPending)) · \(unsyncedCount)"
        } else {
            return t(.syncStatusDone)
        }
    }
}

enum SyncBlockReason {
    case requiresLogin
    case networkUnavailable
    case waitingForWiFi

    var displayText: String {
        switch self {
        case .requiresLogin:
            return t(.syncStatusRequiresLogin)
        case .networkUnavailable:
            return t(.syncStatusWaitingForNetwork)
        case .waitingForWiFi:
            return t(.syncStatusWaitingForWiFi)
        }
    }
}

private struct SyncNetworkSnapshot {
    let isReachable: Bool
    let isOnWiFi: Bool

    static let unknown = SyncNetworkSnapshot(isReachable: true, isOnWiFi: true)

    init(isReachable: Bool, isOnWiFi: Bool) {
        self.isReachable = isReachable
        self.isOnWiFi = isOnWiFi
    }

    init(path: NWPath) {
        isReachable = path.status == .satisfied
        isOnWiFi = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
    }
}

// MARK: - Errors

enum SyncError: Error, LocalizedError {
    case encodingFailed
    case payloadTooLarge(Int)
    case networkUnavailable
    case serverError(Int, String)
    case uploadFailed(Int)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return t(.syncErrorEncodingFailed)
        case .payloadTooLarge(let size):
            return String(format: t(.syncErrorPayloadTooLargeFormat), size)
        case .networkUnavailable:
            return t(.syncErrorNetworkUnavailable)
        case .serverError(let code, let msg):
            return String(format: t(.syncErrorServerFormat), code, msg)
        case .uploadFailed(let code):
            return String(format: t(.syncErrorUploadFailedFormat), code)
        }
    }
}
