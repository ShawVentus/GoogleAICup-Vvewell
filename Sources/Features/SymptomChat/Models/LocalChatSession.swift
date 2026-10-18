import Foundation

enum ChatFeedbackKind: String, Codable, CaseIterable {
    case like
    case dislike
}

struct LocalAssistantVersion: Codable, Identifiable, Equatable {
    var id: String
    var content: String
    var displayContent: String?
    var citations: [AssistantCitation]
    var createdAt: TimeInterval
    var feedback: ChatFeedbackKind?

    init(
        id: String = UUID().uuidString,
        content: String,
        displayContent: String? = nil,
        citations: [AssistantCitation] = [],
        createdAt: TimeInterval = Date().timeIntervalSince1970,
        feedback: ChatFeedbackKind? = nil
    ) {
        self.id = id
        self.content = content
        self.displayContent = displayContent
        self.citations = citations
        self.createdAt = createdAt
        self.feedback = feedback
    }
}

struct LocalChatMessage: Codable, Identifiable, Equatable {
    var id: String
    var role: String
    var content: String
    var displayContent: String?
    var createdAt: TimeInterval
    var attachmentTitles: [String]
    var activeVersionId: String?
    var versions: [LocalAssistantVersion]

    init(
        id: String = UUID().uuidString,
        role: String,
        content: String,
        displayContent: String? = nil,
        createdAt: TimeInterval = Date().timeIntervalSince1970,
        attachmentTitles: [String] = [],
        activeVersionId: String? = nil,
        versions: [LocalAssistantVersion] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.displayContent = displayContent
        self.createdAt = createdAt
        self.attachmentTitles = attachmentTitles
        self.activeVersionId = activeVersionId
        self.versions = versions
    }

    var isAssistant: Bool {
        role == "assistant"
    }

    var activeVersion: LocalAssistantVersion? {
        guard isAssistant else { return nil }
        if let activeVersionId,
           let version = versions.first(where: { $0.id == activeVersionId }) {
            return version
        }
        return versions.last
    }

    var activeContent: String {
        if isAssistant {
            return activeVersion?.displayContent ?? activeVersion?.content ?? content
        }
        return displayContent ?? content
    }

    var activeCitations: [AssistantCitation] {
        activeVersion?.citations ?? []
    }

    var activeFeedback: ChatFeedbackKind? {
        activeVersion?.feedback
    }

    var activeVersionIndex: Int? {
        guard let activeVersionId else { return nil }
        return versions.firstIndex(where: { $0.id == activeVersionId })
    }

    mutating func ensureAssistantVersion() {
        guard isAssistant else { return }
        if versions.isEmpty {
            let version = LocalAssistantVersion(content: content, displayContent: content, createdAt: createdAt)
            versions = [version]
            activeVersionId = version.id
        } else if activeVersionId == nil {
            activeVersionId = versions.last?.id
        }
        if let activeVersion = activeVersion {
            content = activeVersion.content
        }
    }

    mutating func appendVersion(
        content: String,
        displayContent: String? = nil,
        citations: [AssistantCitation] = [],
        createdAt: TimeInterval = Date().timeIntervalSince1970
    ) -> LocalAssistantVersion {
        ensureAssistantVersion()
        let version = LocalAssistantVersion(
            content: content,
            displayContent: displayContent ?? content,
            citations: citations,
            createdAt: createdAt
        )
        versions.append(version)
        activeVersionId = version.id
        self.content = content
        return version
    }

    mutating func setActiveVersion(id: String) {
        guard isAssistant,
              let version = versions.first(where: { $0.id == id }) else { return }
        activeVersionId = version.id
        content = version.content
    }

    mutating func setFeedback(_ feedback: ChatFeedbackKind?) {
        guard isAssistant,
              let activeVersionId,
              let index = versions.firstIndex(where: { $0.id == activeVersionId }) else { return }
        versions[index].feedback = feedback
    }

    var visibleAssistantMessage: AssistantChatMessage {
        AssistantChatMessage(
            role: role,
            content: isAssistant ? activeContent : content,
            displayContent: isAssistant ? activeVersion?.displayContent : displayContent,
            messageID: id,
            versionID: activeVersion?.id,
            activeVersionID: activeVersionId,
            versions: isAssistant
                ? versions.map { version in
                    AssistantMessageVersion(
                        versionID: version.id,
                        content: version.content,
                        displayContent: version.displayContent,
                        citations: version.citations,
                        feedback: version.feedback == .like ? .up : (version.feedback == .dislike ? .down : nil)
                    )
                }
                : nil
        )
    }
}

struct LocalChatSession: Codable, Identifiable, Equatable {
    var id: String
    var remoteId: String?
    var title: String
    var createdAt: TimeInterval
    var updatedAt: TimeInterval
    var revision: Int
    var messages: [LocalChatMessage]
    var pendingUpload: Bool
    var pendingDelete: Bool
    var deletedAt: TimeInterval?
    var lastSyncedAt: TimeInterval?

    init(
        id: String = UUID().uuidString,
        remoteId: String? = nil,
        title: String,
        createdAt: TimeInterval = Date().timeIntervalSince1970,
        updatedAt: TimeInterval = Date().timeIntervalSince1970,
        revision: Int = 0,
        messages: [LocalChatMessage] = [],
        pendingUpload: Bool = true,
        pendingDelete: Bool = false,
        deletedAt: TimeInterval? = nil,
        lastSyncedAt: TimeInterval? = nil
    ) {
        self.id = id
        self.remoteId = remoteId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revision = revision
        self.messages = messages
        self.pendingUpload = pendingUpload
        self.pendingDelete = pendingDelete
        self.deletedAt = deletedAt
        self.lastSyncedAt = lastSyncedAt
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    var userPreview: String {
        firstUserMessage?.activeContent ?? title
    }

    var assistantPreview: String {
        firstAssistantMessage?.activeContent ?? ""
    }

    var firstUserMessage: LocalChatMessage? {
        messages.first(where: { $0.role == "user" })
    }

    var firstAssistantMessage: LocalChatMessage? {
        messages.first(where: { $0.role == "assistant" })
    }

    var activeAssistantMessage: LocalChatMessage? {
        messages.last(where: { $0.role == "assistant" })
    }

    var visibleMessages: [AssistantChatMessage] {
        messages.map(\.visibleAssistantMessage)
    }

    mutating func touch(updatedAt: TimeInterval = Date().timeIntervalSince1970) {
        self.updatedAt = updatedAt
        revision += 1
        pendingUpload = true
    }

    mutating func replaceMessages(_ messages: [LocalChatMessage], updatedAt: TimeInterval = Date().timeIntervalSince1970) {
        self.messages = messages
        touch(updatedAt: updatedAt)
    }

    mutating func markUploaded(remoteId: String?, syncedAt: TimeInterval = Date().timeIntervalSince1970) {
        if let remoteId {
            self.remoteId = remoteId
        }
        pendingUpload = false
        lastSyncedAt = syncedAt
    }

    mutating func markPendingDelete(at date: TimeInterval = Date().timeIntervalSince1970) {
        deletedAt = date
        pendingDelete = true
        revision += 1
    }

    static func makeTitle(from firstUserMessage: String) -> String {
        let trimmed = firstUserMessage.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return t(.symptomChatTitle) }
        return String(trimmed.prefix(24))
    }

    static func fromLegacy(messages: [AssistantChatMessage], savedAt: TimeInterval, isComplete: Bool) -> LocalChatSession? {
        guard !messages.isEmpty else { return nil }
        let localMessages = messages.map { message in
            if message.role == "assistant" {
                return LocalChatMessage(
                    role: message.role,
                    content: message.content,
                    displayContent: message.displayContent,
                    createdAt: savedAt,
                    versions: [LocalAssistantVersion(
                        content: message.content,
                        displayContent: message.displayContent ?? message.content,
                        citations: message.versions?.first?.citations ?? [],
                        createdAt: savedAt
                    )]
                )
            }
            return LocalChatMessage(
                role: message.role,
                content: message.content,
                displayContent: message.displayContent,
                createdAt: savedAt
            )
        }
        let title = makeTitle(from: messages.first(where: { $0.role == "user" })?.content ?? messages.first?.content ?? t(.symptomChatTitle))
        return LocalChatSession(
            title: title,
            createdAt: savedAt,
            updatedAt: savedAt,
            revision: isComplete ? 1 : 0,
            messages: localMessages,
            pendingUpload: !isComplete,
            pendingDelete: false,
            deletedAt: nil,
            lastSyncedAt: nil
        )
    }
}

struct LocalChatHistorySection: Equatable {
    let title: String
    let sessions: [LocalChatSession]
}
