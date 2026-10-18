import Foundation

protocol HealthRemoteServing: RemoteOcrReportsFetching {
    func uploadOcrReport(imageData: Data) async throws -> OcrReportAPIResponse
    func deleteOcrReport(id: String) async throws
    func fetchCloudReadingsCount(limit: Int) async throws -> Int
    func fetchCloudReadings(limit: Int) async throws -> CloudReadingsResponse
}

struct LiveHealthRemoteService: HealthRemoteServing {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchOcrReports(limit: Int) async throws -> [RemoteOcrReport] {
        try await apiClient.fetchOcrReports(limit: limit)
    }

    func uploadOcrReport(imageData: Data) async throws -> OcrReportAPIResponse {
        try await apiClient.uploadOcrReport(imageData: imageData)
    }

    func deleteOcrReport(id: String) async throws {
        try await apiClient.deleteOcrReport(id: id)
    }

    func fetchCloudReadingsCount(limit: Int) async throws -> Int {
        try await apiClient.fetchCloudReadingsCount(limit: limit)
    }

    func fetchCloudReadings(limit: Int) async throws -> CloudReadingsResponse {
        try await apiClient.fetchCloudReadings(limit: limit)
    }
}
