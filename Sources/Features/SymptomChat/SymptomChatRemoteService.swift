import Foundation

protocol SymptomChatRemoteServing {
    func makeAssistantStreamSession(
        message: String,
        history: [AssistantChatMessage],
        attachments: [AssistantAttachmentPayload],
        language: String,
        onToken: @escaping (String) -> Void,
        onMeta: @escaping (AssistantStreamMeta) -> Void,
        onGrounding: @escaping ([AssistantCitation]) -> Void,
        onError: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) throws -> AssistantStreamSession

    func fetchChatHistory(limit: Int) async throws -> [ChatHistorySession]
    func saveChatHistory(
        clientSessionID: String?,
        revision: Int?,
        messages: [AssistantChatMessage]
    ) async throws -> ChatHistorySession
    func deleteChatHistory(id: String) async throws
    func deleteChatHistory(clientSessionID: String, revision: Int?) async throws -> ChatHistoryDeleteResult
    func sendChatHistoryFeedback(
        clientSessionID: String,
        messageID: String,
        versionID: String,
        feedback: ChatHistoryFeedbackType,
        revision: Int?
    ) async throws -> ChatHistoryFeedbackResult
    func uploadOcrReport(imageData: Data) async throws -> OcrReportAPIResponse
}

struct LiveSymptomChatRemoteService: SymptomChatRemoteServing {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func makeAssistantStreamSession(
        message: String,
        history: [AssistantChatMessage],
        attachments: [AssistantAttachmentPayload],
        language: String,
        onToken: @escaping (String) -> Void,
        onMeta: @escaping (AssistantStreamMeta) -> Void,
        onGrounding: @escaping ([AssistantCitation]) -> Void,
        onError: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) throws -> AssistantStreamSession {
        try apiClient.makeAssistantStreamSession(
            message: message,
            history: history,
            attachments: attachments,
            language: language,
            onToken: onToken,
            onMeta: onMeta,
            onGrounding: onGrounding,
            onError: onError,
            onComplete: onComplete
        )
    }

    func fetchChatHistory(limit: Int = 20) async throws -> [ChatHistorySession] {
        try await apiClient.fetchChatHistory(limit: limit)
    }

    func saveChatHistory(
        clientSessionID: String? = nil,
        revision: Int? = nil,
        messages: [AssistantChatMessage]
    ) async throws -> ChatHistorySession {
        try await apiClient.saveChatHistory(
            clientSessionID: clientSessionID,
            revision: revision,
            messages: messages
        )
    }

    func deleteChatHistory(id: String) async throws {
        try await apiClient.deleteChatHistory(id: id)
    }

    func deleteChatHistory(clientSessionID: String, revision: Int? = nil) async throws -> ChatHistoryDeleteResult {
        try await apiClient.deleteChatHistory(clientSessionID: clientSessionID, revision: revision)
    }

    func sendChatHistoryFeedback(
        clientSessionID: String,
        messageID: String,
        versionID: String,
        feedback: ChatHistoryFeedbackType,
        revision: Int? = nil
    ) async throws -> ChatHistoryFeedbackResult {
        try await apiClient.sendChatHistoryFeedback(
            clientSessionID: clientSessionID,
            messageID: messageID,
            versionID: versionID,
            feedback: feedback,
            revision: revision
        )
    }

    func uploadOcrReport(imageData: Data) async throws -> OcrReportAPIResponse {
        try await apiClient.uploadOcrReport(imageData: imageData)
    }
}
