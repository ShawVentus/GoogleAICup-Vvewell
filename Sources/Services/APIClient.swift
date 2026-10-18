import Foundation

enum APIError: Error, LocalizedError {
    case networkError(Error)
    case serverError(Int)
    case decodingError(Error)
    case analysisTimeout
    case analysisFailed(String)
    case invalidResponse
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .networkError(let e):
            return String(format: t(.apiErrorNetworkFormat), e.localizedDescription)
        case .serverError(let code) where code == 413:
            return t(.apiErrorVideoTooLarge)
        case .serverError(let code) where code == 422:
            return t(.apiErrorAnalysisRetry)
        case .serverError(let code) where code == 503:
            return t(.apiErrorServiceUnavailable)
        case .serverError(let code):
            return String(format: t(.apiErrorServerCodeFormat), code)
        case .decodingError:
            return t(.apiErrorDecodingFailed)
        case .analysisTimeout:
            return t(.apiErrorAnalysisTimeout)
        case .analysisFailed(let msg):
            return String(format: t(.apiErrorAnalysisFailedFormat), msg)
        case .invalidResponse:
            return t(.apiErrorInvalidResponse)
        case .unauthorized:
            return t(.apiErrorUnauthorized)
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let session = URLSession.shared
    private var baseURL: String { Config.apiBaseURL }

    struct RelayLoginTokens {
        let accessToken: String
        let refreshToken: String
    }

    // MARK: - Auth-Aware Request Execution

    /// Execute a URLRequest with JWT auth header, auto-refreshing on 401.
    private func authData(for request: URLRequest) async throws -> (Data, URLResponse) {
        var req = request
        AuthTokenManager.shared.authorizeRequest(&req)

        let (data, response) = try await session.data(for: req)

        // If 401, attempt token refresh and retry once
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            let refreshed = await AuthTokenManager.shared.refreshAccessToken()
            guard refreshed else { throw APIError.unauthorized }

            var retryReq = request
            AuthTokenManager.shared.authorizeRequest(&retryReq)
            return try await session.data(for: retryReq)
        }

        return (data, response)
    }

    private func decodeResponse<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        response: URLResponse,
        validStatusCodes: Set<Int> = [200]
    ) throws -> T {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard validStatusCodes.contains(http.statusCode) else { throw APIError.serverError(http.statusCode) }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func validateStatus(
        _ response: URLResponse,
        validStatusCodes: Set<Int> = [200]
    ) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard validStatusCodes.contains(http.statusCode) else { throw APIError.serverError(http.statusCode) }
    }

    func loginWithRelay(email: String, password: String) async throws -> RelayLoginTokens {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard http.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["error"] as? String {
                throw NSError(
                    domain: "RelayLogin",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: detail]
                )
            }
            throw APIError.serverError(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String else {
            throw APIError.decodingError(
                NSError(
                    domain: "RelayLogin",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid login response"]
                )
            )
        }

        return RelayLoginTokens(accessToken: accessToken, refreshToken: refreshToken)
    }

    // MARK: - 上传视频并获取 task_id

    /// 上传视频文件到 /api/analyze，返回 task_id
    /// - Parameter fileURL: 本地视频文件 URL
    /// - Returns: 后端分析任务 ID
    func uploadVideo(fileURL: URL, language: String = "zh") async throws -> String {
        let url = URL(string: "\(baseURL)/api/analyze/tasks")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let filename = fileURL.lastPathComponent
        // language 字段
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(language)\r\n".data(using: .utf8)!)
        // video 字段
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await authData(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard http.statusCode == 200 || http.statusCode == 202 else { throw APIError.serverError(http.statusCode) }

        let task = try JSONDecoder().decode(AnalysisTaskResponse.self, from: data)
        return task.taskId
    }

    // MARK: - OCR / GlobalCare

    /// 上传 OCR 报告图片到 `/api/ocr/report`
    /// - Parameter imageData: JPEG 格式的报告图片数据
    /// - Returns: OCR 识别结果响应
    func uploadOcrReport(imageData: Data) async throws -> OcrReportAPIResponse {
        let url = URL(string: "\(baseURL)/api/ocr/report")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"report_image\"; filename=\"report.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await authData(for: request)
        return try decodeResponse(
            OcrReportAPIResponse.self,
            from: data,
            response: response,
            validStatusCodes: [200, 201]
        )
    }

    /// 提交 GlobalCare AI 预评估到 `/api/globalcare/assess`
    /// - Parameter draft: 用户填写的 GlobalCare 草稿
    /// - Returns: AI 预评估结果
    func assessGlobalCare(draft: GlobalCareDraft) async throws -> AIAssessmentResult {
        let url = URL(string: "\(baseURL)/api/globalcare/assess")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GlobalCareAssessmentRequest(
            symptoms: draft.symptoms,
            targetCountry: draft.targetCountry,
            medicalHistory: draft.medicalHistory,
            contact: draft.contactInfo
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await authData(for: request)
        let result = try decodeResponse(
            GlobalCareAssessmentAPIResponse.self,
            from: data,
            response: response
        )
        return AIAssessmentResult(
            riskLevel: result.riskLevel,
            recommendedDept: result.recommendedDept,
            matchedHospitals: result.matchedHospitals
        )
    }

    /// 提交 GlobalCare 订单到 `/api/globalcare/orders`
    /// - Parameters:
    ///   - draft: 用户填写的 GlobalCare 草稿
    ///   - package: 已选择的服务套餐
    ///   - assessment: AI 预评估结果
    /// - Returns: 订单提交响应
    func submitGlobalCareOrder(
        draft: GlobalCareDraft,
        package: GlobalCarePackage,
        assessment: AIAssessmentResult
    ) async throws -> GlobalCareOrderResponse {
        let url = URL(string: "\(baseURL)/api/globalcare/orders")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GlobalCareOrderRequest(
            symptoms: draft.symptoms,
            targetCountry: draft.targetCountry,
            medicalHistory: draft.medicalHistory,
            contact: draft.contactInfo,
            packageId: package.id,
            riskLevel: assessment.riskLevel,
            recommendedDept: assessment.recommendedDept
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await authData(for: request)
        return try decodeResponse(
            GlobalCareOrderResponse.self,
            from: data,
            response: response,
            validStatusCodes: [200, 201]
        )
    }

    /// 获取 GlobalCare 订单状态 `/api/globalcare/orders/{orderId}`
    /// - Parameter orderId: 订单 ID
    /// - Returns: 订单状态响应
    func fetchGlobalCareOrder(orderId: String) async throws -> GlobalCareOrderStatusResponse {
        let encodedOrderId = orderId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? orderId
        let url = URL(string: "\(baseURL)/api/globalcare/orders/\(encodedOrderId)")!
        let request = URLRequest(url: url)
        let (data, response) = try await authData(for: request)
        return try decodeResponse(GlobalCareOrderStatusResponse.self, from: data, response: response)
    }

    func makeAssistantStreamSession(
        message: String,
        history: [AssistantChatMessage],
        attachments: [AssistantAttachmentPayload] = [],
        language: String,
        onToken: @escaping (String) -> Void,
        onMeta: ((AssistantStreamMeta) -> Void)? = nil,
        onGrounding: (([AssistantCitation]) -> Void)? = nil,
        onError: ((String) -> Void)? = nil,
        onComplete: (() -> Void)? = nil
    ) throws -> AssistantStreamSession {
        let url = URL(string: "\(baseURL)/api/assistant/stream")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = AssistantRequestPayload(
            message: message,
            history: history,
            healthData: nil,
            reportData: nil,
            attachments: attachments.isEmpty ? nil : attachments,
            language: language
        )
        request.httpBody = try JSONEncoder().encode(body)
        AuthTokenManager.shared.authorizeRequest(&request)
        return AssistantStreamSession(
            request: request,
            onToken: onToken,
            onMeta: onMeta,
            onGrounding: onGrounding,
            onError: onError,
            onComplete: onComplete
        )
    }

    // MARK: - Chat History

    func saveChatHistory(
        clientSessionID: String? = nil,
        revision: Int? = nil,
        messages: [AssistantChatMessage]
    ) async throws -> ChatHistorySession {
        // `revision` follows the relay contract's next-revision semantics:
        // pass nil for server auto-increment, or pass the next revision to persist.
        let url = URL(string: "\(baseURL)/api/v1/chat/history")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatHistorySaveRequest(
                clientSessionID: clientSessionID,
                revision: revision,
                messages: messages
            )
        )

        let (data, response) = try await authData(for: request)
        return try decodeResponse(ChatHistorySession.self, from: data, response: response)
    }

    func fetchChatHistory(limit: Int = 20) async throws -> [ChatHistorySession] {
        var components = URLComponents(string: "\(baseURL)/api/v1/chat/history")!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = components.url else { throw APIError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response) = try await authData(for: request)
        let payload = try decodeResponse(ChatHistoryListResponse.self, from: data, response: response)
        return payload.sessions
    }

    func deleteChatHistory(id: String) async throws {
        let url = URL(string: "\(baseURL)/api/v1/chat/history/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30

        let (_, response) = try await authData(for: request)
        try validateStatus(response)
    }

    func deleteChatHistory(clientSessionID: String, revision: Int? = nil) async throws -> ChatHistoryDeleteResult {
        let encodedSessionID = clientSessionID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? clientSessionID
        var components = URLComponents(string: "\(baseURL)/api/v1/chat/history/session/\(encodedSessionID)")!
        if let revision {
            components.queryItems = [URLQueryItem(name: "revision", value: String(revision))]
        }
        guard let url = components.url else { throw APIError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30

        let (data, response) = try await authData(for: request)
        return try decodeResponse(
            ChatHistoryDeleteResult.self,
            from: data,
            response: response
        )
    }

    func sendChatHistoryFeedback(
        clientSessionID: String,
        messageID: String,
        versionID: String,
        feedback: ChatHistoryFeedbackType,
        revision: Int? = nil
    ) async throws -> ChatHistoryFeedbackResult {
        let encodedSessionID = clientSessionID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? clientSessionID
        let encodedMessageID = messageID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? messageID
        let encodedVersionID = versionID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? versionID
        let url = URL(
            string: "\(baseURL)/api/v1/chat/history/session/\(encodedSessionID)/messages/\(encodedMessageID)/versions/\(encodedVersionID)/feedback"
        )!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatHistoryFeedbackRequest(
                feedback: feedback,
                revision: revision
            )
        )

        let (data, response) = try await authData(for: request)
        return try decodeResponse(
            ChatHistoryFeedbackResult.self,
            from: data,
            response: response
        )
    }

    func fetchOcrReports(limit: Int = 20) async throws -> [RemoteOcrReport] {
        var components = URLComponents(string: "\(baseURL)/api/v1/ocr/reports")!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = components.url else { throw APIError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response) = try await authData(for: request)
        let payload = try decodeResponse(RemoteOcrReportListResponse.self, from: data, response: response)
        return payload.reports
    }

    func deleteOcrReport(id: String) async throws {
        let url = URL(string: "\(baseURL)/api/v1/ocr/reports/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30

        let _ = try await authData(for: request)
    }

    func syncProfiles(_ profiles: [HealthProfile]) async throws {
        let url = URL(string: "\(baseURL)/api/v1/profiles/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ProfileSyncRequest(profiles: profiles.map(ProfileSyncItem.init)))

        let _ = try await authData(for: request)
    }

    func fetchProfiles(limit: Int = 100) async throws -> [HealthProfile] {
        var components = URLComponents(string: "\(baseURL)/api/v1/profiles")!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = components.url else { throw APIError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response) = try await authData(for: request)
        let payload = try decodeResponse(ProfileListResponse.self, from: data, response: response)
        return payload.profiles.map { $0.asHealthProfile() }
    }

    func fetchCloudReadingsCount(limit: Int = 20) async throws -> Int {
        let response = try await fetchCloudReadings(limit: limit)
        return response.count
    }

    func fetchCloudReadings(limit: Int = 100) async throws -> CloudReadingsResponse {
        var components = URLComponents(string: "\(baseURL)/api/v1/health/readings")!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = components.url else { throw APIError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response) = try await authData(for: request)
        return try decodeResponse(CloudReadingsResponse.self, from: data, response: response)
    }

    func deleteProfile(id: String) async throws {
        let url = URL(string: "\(baseURL)/api/v1/profiles/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30

        let _ = try await authData(for: request)
    }

    // MARK: - 轮询分析任务结果

    /// 轮询 /api/analyze/task/{taskId} 直到完成或超时
    /// - Parameters:
    ///   - taskId: uploadVideo 返回的任务 ID
    ///   - onQueueUpdate: 排队位置回调（可选）
    /// - Returns: 分析结果
    func pollAnalysisTask(
        taskId: String,
        onQueueUpdate: ((Int) -> Void)? = nil
    ) async throws -> AnalyzeResponse {
        let maxAttempts = 60
        for attempt in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: attempt == 0 ? 1_000_000_000 : 2_000_000_000)

            let url = URL(string: "\(baseURL)/api/analyze/tasks/\(taskId)")!
            let pollReq = URLRequest(url: url)
            let (data, response) = try await authData(for: pollReq)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            guard http.statusCode == 200 else { throw APIError.serverError(http.statusCode) }

            let task = try JSONDecoder().decode(AnalysisTaskResponse.self, from: data)

            switch task.status {
            case "completed":
                guard let result = task.result else { throw APIError.analysisFailed("无结果数据") }
                return result
            case "failed":
                throw APIError.analysisFailed(task.error ?? "未知错误")
            case "queued":
                onQueueUpdate?(task.queuedAhead ?? 0)
            default:
                break
            }
        }
        throw APIError.analysisTimeout
    }
}

// MARK: - 响应模型（镜像后端 schema）

struct AnalyzeResponse: Codable {
    let hr: Double?
    let hrStatus: String?
    let rr: Double?
    let rrStatus: String?
    let spo2: Double?
    let spo2Status: String?
    let stressScore: Double?
    let stressLevel: String?
    let sqi: Double?
    let confidence: String?
    let skinLabel: String?
    let skinI18n: [String: String]?

    enum CodingKeys: String, CodingKey {
        case hr, rr, spo2, sqi, confidence
        case hrStatus = "hr_status"
        case rrStatus = "rr_status"
        case spo2Status = "spo2_status"
        case stressScore = "stress_score"
        case stressLevel = "stress_level"
        case skinLabel = "skin_label"
        case skinI18n = "skin_i18n"
    }
}

private struct CloudReadingsCountResponse: Codable {
    let count: Int
}

struct CloudReadingsResponse: Codable {
    let readings: [CloudReadingRecord]
    let count: Int
}

struct CloudReadingRecord: Codable {
    let id: String
    let userId: String
    let results: CloudReadingData
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case results
        case createdAt = "created_at"
    }

    /// Convert to a local RawReading (returns nil for profile records or invalid data)
    func toRawReading() -> RawReading? {
        let r = results
        // Skip profile records stored in the same table
        if r._type == "profile" { return nil }
        guard let profileId = r.profileId,
              let metricTypeStr = r.metricType,
              let metricType = HealthMetricType(rawValue: metricTypeStr),
              let sourceStr = r.source,
              let source = MetricSourceDevice(rawValue: sourceStr),
              let sourceName = r.sourceName,
              let timestamp = r.timestamp,
              let receivedAt = r.receivedAt,
              let value = r.value,
              let unit = r.unit,
              let accuracyInt = r.accuracy,
              let accuracy = ReadingAccuracy(rawValue: accuracyInt) else {
            return nil
        }
        var reading = RawReading(
            id: id,
            schemaVersion: r.schemaVersion ?? 1,
            profileId: profileId,
            metricType: metricType,
            source: source,
            sourceName: sourceName,
            sourceVersion: r.sourceVersion,
            timestamp: timestamp,
            receivedAt: receivedAt,
            value: value,
            unit: unit,
            accuracy: accuracy,
            payloadType: r.payloadType,
            payloadJson: r.payload,
            createdAt: timestamp
        )
        reading.syncStatus = .synced
        reading.syncId = id
        reading.syncedAt = Date().timeIntervalSince1970
        return reading
    }
}

struct CloudReadingData: Codable {
    let schemaVersion: Int?
    let profileId: String?
    let metricType: String?
    let source: String?
    let sourceName: String?
    let sourceVersion: String?
    let timestamp: Double?
    let receivedAt: Double?
    let value: Double?
    let unit: String?
    let accuracy: Int?
    let payloadType: String?
    let payload: String?
    let _type: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case profileId = "profile_id"
        case metricType = "metric_type"
        case source
        case sourceName = "source_name"
        case sourceVersion = "source_version"
        case timestamp
        case receivedAt = "received_at"
        case value
        case unit
        case accuracy
        case payloadType = "payload_type"
        case payload
        case _type
    }
}

struct AnalysisTaskResponse: Codable {
    let taskId: String
    let status: String
    let error: String?
    let result: AnalyzeResponse?
    let queuedAhead: Int?

    enum CodingKeys: String, CodingKey {
        case status, error, result
        case taskId = "task_id"
        case queuedAhead = "queued_ahead"
    }
}

struct AssistantMessageVersion: Codable {
    let versionID: String
    let content: String
    let displayContent: String?
    let citations: [AssistantCitation]?
    let feedback: ChatHistoryFeedbackType?

    enum CodingKeys: String, CodingKey {
        case content, feedback, citations
        case displayContent = "display_content"
        case versionID = "version_id"
    }
}

struct AssistantChatMessage: Codable {
    let role: String
    let content: String
    let displayContent: String?
    let messageID: String?
    let versionID: String?
    let activeVersionID: String?
    let versions: [AssistantMessageVersion]?

    init(
        role: String,
        content: String,
        displayContent: String? = nil,
        messageID: String? = nil,
        versionID: String? = nil,
        activeVersionID: String? = nil,
        versions: [AssistantMessageVersion]? = nil
    ) {
        self.role = role
        self.content = content
        self.displayContent = displayContent
        self.messageID = messageID
        self.versionID = versionID
        self.activeVersionID = activeVersionID
        self.versions = versions
    }

    enum CodingKeys: String, CodingKey {
        case role, content, versions
        case displayContent = "display_content"
        case messageID = "message_id"
        case versionID = "version_id"
        case activeVersionID = "active_version_id"
    }
}

private struct ChatHistorySaveRequest: Codable {
    let clientSessionID: String?
    let revision: Int?
    let messages: [AssistantChatMessage]

    enum CodingKeys: String, CodingKey {
        case revision, messages
        case clientSessionID = "client_session_id"
    }
}

struct ChatHistorySession: Codable {
    let id: String
    let clientSessionID: String?
    let revision: Int?
    let createdAt: String
    let updatedAt: String?
    let deletedAt: String?
    let messages: [AssistantChatMessage]

    enum CodingKeys: String, CodingKey {
        case id, revision, messages
        case clientSessionID = "client_session_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

private struct ChatHistoryListResponse: Codable {
    let sessions: [ChatHistorySession]
}

enum ChatHistoryFeedbackType: String, Codable {
    case up
    case down
}

private struct ChatHistoryFeedbackRequest: Codable {
    let feedback: ChatHistoryFeedbackType
    let revision: Int?
}

struct ChatHistoryFeedbackResult: Codable {
    let id: String
    let clientSessionID: String?
    let messageID: String
    let versionID: String
    let feedback: ChatHistoryFeedbackType
    let revision: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, feedback, revision
        case clientSessionID = "client_session_id"
        case messageID = "message_id"
        case versionID = "version_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ChatHistoryDeleteResult: Codable {
    let status: String
    let id: String
    let clientSessionID: String?
    let revision: Int?
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case status, id, revision
        case clientSessionID = "client_session_id"
        case deletedAt = "deleted_at"
    }
}

struct RemoteOcrReportListResponse: Codable {
    let reports: [RemoteOcrReport]
}

struct RemoteOcrReport: Codable {
    let id: String
    let reportDate: String?
    let createdAt: String?
    let payload: OcrReportAPIResponse

    enum CodingKeys: String, CodingKey {
        case id, payload
        case reportDate = "report_date"
        case createdAt = "created_at"
    }

    func asLocalModel() -> OcrReport {
        let formatter = ISO8601DateFormatter()
        let date = reportDate.flatMap { formatter.date(from: $0) }
            ?? createdAt.flatMap { formatter.date(from: $0) }
            ?? Date()

        return OcrReport(
            id: id,
            date: date,
            imageLocalPath: "",
            source: .cloud,
            items: payload.items.map { item in
                OcrReport.OcrItem(
                    name: item["name"] ?? "",
                    value: item["value"] ?? "",
                    reference: item["reference_range"] ?? item["reference"] ?? "",
                    isAbnormal: item["is_abnormal"] == "true"
                )
            }
        )
    }
}

private struct ProfileSyncRequest: Codable {
    let profiles: [ProfileSyncItem]
}

private struct ProfileSyncItem: Codable {
    let id: String
    let name: String
    let relationship: String
    let birthYear: Int?
    let gender: String?
    let heightCm: Double?
    let weightKg: Double?
    let bloodType: String?
    let updatedAt: Double

    enum CodingKeys: String, CodingKey {
        case id, name, relationship, gender
        case birthYear = "birth_year"
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case bloodType = "blood_type"
        case updatedAt = "updated_at"
    }

    init(from profile: HealthProfile) {
        id = profile.id
        name = profile.name
        relationship = profile.relationship.rawValue
        birthYear = profile.birthYear
        gender = profile.gender?.rawValue
        heightCm = profile.heightCm
        weightKg = profile.weightKg
        bloodType = profile.bloodType
        updatedAt = profile.updatedAt
    }
}

private struct ProfileListResponse: Codable {
    let profiles: [RemoteHealthProfile]
}

private struct RemoteHealthProfile: Codable {
    let id: String
    let name: String
    let relationship: String
    let birthYear: Int?
    let gender: String?
    let heightCm: Double?
    let weightKg: Double?
    let bloodType: String?
    let updatedAt: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, relationship, gender
        case birthYear = "birth_year"
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case bloodType = "blood_type"
        case updatedAt = "updated_at"
    }

    func asHealthProfile() -> HealthProfile {
        let fallbackRelationship = Relationship(rawValue: relationship) ?? .other
        var profile = HealthProfile(
            id: id,
            name: name,
            relationship: fallbackRelationship,
            birthYear: birthYear,
            gender: gender.flatMap(Gender.init(rawValue:)),
            heightCm: heightCm,
            weightKg: weightKg,
            bloodType: bloodType
        )
        if let updatedAt {
            profile.updatedAt = updatedAt
        }
        return profile
    }
}

private struct AssistantRequestPayload: Codable {
    let message: String
    let history: [AssistantChatMessage]
    let healthData: AnalyzeResponse?
    let reportData: [String: String]?
    let attachments: [AssistantAttachmentPayload]?
    let language: String

    enum CodingKeys: String, CodingKey {
        case message, history, language
        case healthData = "health_data"
        case reportData = "report_data"
        case attachments
    }
}

struct AssistantAttachmentPayload: Codable {
    let kind: String
    let name: String
    let mimeType: String
    let textContent: String

    enum CodingKeys: String, CodingKey {
        case kind, name
        case mimeType = "mime_type"
        case textContent = "text_content"
    }
}

struct AssistantStreamMeta: Decodable {
    let cleanReply: String?
    let doctors: [AssistantDoctor]?
    let choices: [AssistantChoice]?
    let confirm: String?
    let doctorHint: String?
    let citations: [AssistantCitation]?

    enum CodingKeys: String, CodingKey {
        case cleanReply = "clean_reply"
        case doctors, choices, confirm
        case doctorHint = "doctor_hint"
        case citations
    }
}

struct AssistantChoice: Codable {
    let question: String
    let options: [String]
}

struct AssistantDoctor: Codable {
    let id: String?
    let name: String?
    let title: String?
    let departmentName: String?
    let hospitalName: String?

    enum CodingKeys: String, CodingKey {
        case id, name, title
        case departmentName = "department_name"
        case hospitalName = "hospital_name"
    }
}

struct AssistantCitation: Codable, Hashable {
    let title: String?
    let url: String?
    let snippet: String?

    init(title: String?, url: String?, snippet: String?) {
        self.title = title
        self.url = url
        self.snippet = snippet
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)

        func decodeString(_ keys: [String]) -> String? {
            for key in keys {
                guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
                if let value = try? container.decode(String.self, forKey: codingKey),
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return value
                }
            }
            return nil
        }

        title = decodeString(["title", "name", "source_title", "display_title"])
        url = decodeString(["url", "source_url", "uri"])
        snippet = decodeString(["snippet", "content", "text", "quote", "summary"])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(snippet, forKey: .snippet)
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case url
        case snippet
    }
}

private struct GlobalCareAssessmentRequest: Codable {
    let symptoms: String
    let targetCountry: String
    let medicalHistory: [String]
    let contact: String

    enum CodingKeys: String, CodingKey {
        case symptoms, contact
        case targetCountry = "target_country"
        case medicalHistory = "medical_history"
    }
}

private struct GlobalCareOrderRequest: Codable {
    let symptoms: String
    let targetCountry: String
    let medicalHistory: [String]
    let contact: String
    let packageId: String
    let riskLevel: String
    let recommendedDept: String

    enum CodingKeys: String, CodingKey {
        case symptoms, contact
        case targetCountry = "target_country"
        case medicalHistory = "medical_history"
        case packageId = "package_id"
        case riskLevel = "risk_level"
        case recommendedDept = "recommended_dept"
    }
}

private struct GlobalCareAssessmentAPIResponse: Codable {
    let riskLevel: String
    let recommendedDept: String
    let matchedHospitals: Int

    enum CodingKeys: String, CodingKey {
        case riskLevel = "risk_level"
        case recommendedDept = "recommended_dept"
        case matchedHospitals = "matched_hospitals"
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct OcrReportAPIResponse: Codable {
    let reportType: String
    let examName: String?
    let items: [[String: String]]
    let conclusion: String?
    let hospital: String?
    let reportDate: String?
    let detailText: String?

    enum CodingKeys: String, CodingKey {
        case reportType = "report_type"
        case examName = "exam_name"
        case items, conclusion, hospital
        case reportDate = "report_date"
        case detailText = "detail_text"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reportType = try container.decode(String.self, forKey: .reportType)
        examName = try container.decodeIfPresent(String.self, forKey: .examName)
        conclusion = try container.decodeIfPresent(String.self, forKey: .conclusion)
        hospital = try container.decodeIfPresent(String.self, forKey: .hospital)
        reportDate = try container.decodeIfPresent(String.self, forKey: .reportDate)
        detailText = try container.decodeIfPresent(String.self, forKey: .detailText)

        var itemsContainer = try container.nestedUnkeyedContainer(forKey: .items)
        var decodedItems: [[String: String]] = []
        while !itemsContainer.isAtEnd {
            let itemDecoder = try itemsContainer.superDecoder()
            let itemContainer = try itemDecoder.container(keyedBy: DynamicCodingKey.self)
            var item: [String: String] = [:]

            for key in itemContainer.allKeys {
                if let value = try? itemContainer.decode(String.self, forKey: key) {
                    item[key.stringValue] = value
                } else if let value = try? itemContainer.decode(Int.self, forKey: key) {
                    item[key.stringValue] = String(value)
                } else if let value = try? itemContainer.decode(Double.self, forKey: key) {
                    item[key.stringValue] = String(value)
                } else if let value = try? itemContainer.decode(Bool.self, forKey: key) {
                    item[key.stringValue] = value ? "true" : "false"
                } else if (try? itemContainer.decodeNil(forKey: key)) == true {
                    item[key.stringValue] = ""
                }
            }

            decodedItems.append(item)
        }
        items = decodedItems
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(reportType, forKey: .reportType)
        try container.encodeIfPresent(examName, forKey: .examName)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(conclusion, forKey: .conclusion)
        try container.encodeIfPresent(hospital, forKey: .hospital)
        try container.encodeIfPresent(reportDate, forKey: .reportDate)
        try container.encodeIfPresent(detailText, forKey: .detailText)
    }
}

struct GlobalCareOrderResponse: Codable {
    let orderId: String
    let orderNo: String
    let submittedAt: String

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderNo = "order_no"
        case submittedAt = "submitted_at"
    }
}

struct GlobalCareOrderStatusResponse: Codable {
    let orderId: String
    let orderNo: String
    let nodes: [GlobalCareNodeResponse]

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderNo = "order_no"
        case nodes
    }
}

struct GlobalCareNodeResponse: Codable {
    let key: String
    let status: String
    let timestamp: String
}

final class AssistantStreamSession: NSObject, URLSessionDataDelegate {
    static var sessionConfigurationOverride: URLSessionConfiguration?

    private let request: URLRequest
    private let onToken: (String) -> Void
    private let onMeta: ((AssistantStreamMeta) -> Void)?
    private let onGrounding: (([AssistantCitation]) -> Void)?
    private let onError: ((String) -> Void)?
    private let onComplete: (() -> Void)?

    private lazy var urlSession: URLSession = {
        URLSession(
            configuration: Self.sessionConfigurationOverride ?? .default,
            delegate: self,
            delegateQueue: nil
        )
    }()

    private var task: URLSessionDataTask?
    private var buffer = ""
    private var didFinish = false
    private var receivedToken = false
    private var responseStatusCode: Int?
    private var responseBody = Data()

    init(
        request: URLRequest,
        onToken: @escaping (String) -> Void,
        onMeta: ((AssistantStreamMeta) -> Void)?,
        onGrounding: (([AssistantCitation]) -> Void)?,
        onError: ((String) -> Void)?,
        onComplete: (() -> Void)?
    ) {
        self.request = request
        self.onToken = onToken
        self.onMeta = onMeta
        self.onGrounding = onGrounding
        self.onError = onError
        self.onComplete = onComplete
    }

    func start() {
        let task = urlSession.dataTask(with: request)
        self.task = task
        task.resume()
    }

    func cancel() {
        task?.cancel()
        urlSession.invalidateAndCancel()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let responseStatusCode, !(200...299).contains(responseStatusCode) {
            responseBody.append(data)
            return
        }

        guard let chunk = String(data: data, encoding: .utf8) else { return }
        buffer += chunk

        while let range = buffer.range(of: "\n\n") {
            let eventBlock = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            handle(eventBlock: eventBlock)
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse {
            responseStatusCode = http.statusCode
        } else {
            responseStatusCode = nil
        }
        responseBody.removeAll(keepingCapacity: true)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, !didFinish {
            dispatchToMain {
                self.onError?(error.localizedDescription)
            }
        } else if let statusCode = responseStatusCode, !(200...299).contains(statusCode) {
            let detail = responseErrorDetail(for: statusCode)
            dispatchToMain {
                self.onError?(detail)
            }
        } else if !didFinish && !receivedToken {
            dispatchToMain {
                self.onError?(APIError.analysisFailed("Model returned an empty response.").localizedDescription)
            }
        }
        dispatchToMain {
            self.onComplete?()
        }
        session.finishTasksAndInvalidate()
    }

    private func handle(eventBlock: String) {
        let lines = eventBlock
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var eventName = ""
        var dataString = ""

        for line in lines {
            if line.hasPrefix("event: ") {
                eventName = String(line.dropFirst(7))
            } else if line.hasPrefix("data: ") {
                dataString += String(line.dropFirst(6))
            }
        }

        guard !eventName.isEmpty else { return }
        switch eventName {
        case "token":
            guard let data = dataString.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(TokenPayload.self, from: data) else { return }
            receivedToken = true
            dispatchToMain { self.onToken(payload.content) }
        case "meta":
            guard let data = dataString.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(AssistantStreamMeta.self, from: data) else { return }
            dispatchToMain { self.onMeta?(payload) }
        case "grounding":
            guard let data = dataString.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(GroundingPayload.self, from: data) else { return }
            dispatchToMain { self.onGrounding?(payload.evidence) }
        case "error":
            guard let data = dataString.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(ErrorPayload.self, from: data) else {
                dispatchToMain { self.onError?(dataString) }
                return
            }
            dispatchToMain { self.onError?(payload.detail) }
        case "done":
            didFinish = true
        default:
            break
        }
    }

    private func dispatchToMain(_ action: @escaping () -> Void) {
        DispatchQueue.main.async(execute: action)
    }

    private func responseErrorDetail(for statusCode: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: responseBody) as? [String: Any] {
            if let detail = json["detail"] as? String, !detail.isEmpty {
                return detail
            }
            if let error = json["error"] as? String, !error.isEmpty {
                return error
            }
        }
        return APIError.serverError(statusCode).localizedDescription
    }
}

private struct TokenPayload: Codable {
    let content: String
}

private struct ErrorPayload: Codable {
    let detail: String
}

private struct GroundingPayload: Decodable {
    let evidence: [AssistantCitation]
}
