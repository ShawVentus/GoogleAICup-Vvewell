import Foundation

protocol OcrHistoryLoading {
    func refresh(limit: Int) async throws -> [OcrReport]
}

protocol RemoteOcrReportsFetching {
    func fetchOcrReports(limit: Int) async throws -> [RemoteOcrReport]
}

extension APIClient: RemoteOcrReportsFetching {}

struct OcrHistoryLoader: OcrHistoryLoading {
    private let remoteFetcher: RemoteOcrReportsFetching
    private let repository: OcrReportRepository
    private let relayEnabled: Bool
    private let authenticationRequired: Bool

    init(
        remoteFetcher: RemoteOcrReportsFetching = LiveHealthRemoteService(),
        repository: OcrReportRepository = .shared,
        relayEnabled: Bool = Config.useRelay,
        authenticationRequired: Bool = true
    ) {
        self.remoteFetcher = remoteFetcher
        self.repository = repository
        self.relayEnabled = relayEnabled
        self.authenticationRequired = authenticationRequired
    }

    func refresh(limit: Int = 20) async throws -> [OcrReport] {
        guard relayEnabled, (!authenticationRequired || AuthTokenManager.shared.isLoggedIn) else {
            return repository.fetchAll()
        }

        let remoteReports = try await remoteFetcher.fetchOcrReports(limit: limit).map { $0.asLocalModel() }
        repository.replaceReports(remoteReports, for: .cloud)
        return repository.fetchAll()
    }
}
