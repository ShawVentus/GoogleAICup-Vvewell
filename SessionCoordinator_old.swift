import Foundation

@MainActor
final class SymptomChatSessionCoordinator {
    enum State: Equatable {
        case draftOnly
        case streamingFirstReply
        case persistedActive
        case persistedDeleting
        case switchingHistory
    }

    struct NewChatDecision {
        let blockedMessage: String?
        let injectedDraft: String?
        let state: State
    }

    private let store: SymptomChatHistoryStore
    private let remoteService: SymptomChatRemoteServing

    private(set) var state: State = .draftOnly
    private(set) var activeSession: LocalChatSession?
    private(set) var detachedDraftBuffer: String?

    init(
        store: SymptomChatHistoryStore = .shared,
        remoteService: SymptomChatRemoteServing = LiveSymptomChatRemoteService()
    ) {
        self.store = store
        self.remoteService = remoteService
    }


    func returnToDraftOnly(detachedDraft: String? = nil) {
        activeSession = nil
        detachedDraftBuffer = detachedDraft?.trimmingCharacters(in: .whitespacesAndNewlines)
        state = .draftOnly
    }

    func bootstrapLatestSession() -> LocalChatSession? {
        let session = (store.latestVisibleSession() ?? store.legacyFallbackSession()).flatMap {
            $0.visibleMessages.isEmpty ? nil : $0
        }
        activeSession = session
        state = session == nil ? .draftOnly : .persistedActive
        if let session, store.session(id: session.id) == nil {
            store.upsert(session)
        }
        return session
    }

    func beginFirstReplyStreaming() {
        state = .streamingFirstReply
    }

    func finalizeFirstReply(
        userMessage: String,
        displayedUserMessage: String? = nil,
        userAttachmentTitles: [String],
        assistantMessage: String,
        displayedAssistantMessage: String? = nil,
        assistantCitations: [AssistantCitation] = [],
        createdAt: Date = Date()
    ) -> LocalChatSession {
        let timestamp = createdAt.timeIntervalSince1970
        let session = LocalChatSession(
            title: LocalChatSession.makeTitle(from: displayedUserMessage ?? userMessage),
            createdAt: timestamp,
            updatedAt: timestamp,
            revision: 1,
            messages: [
                LocalChatMessage(
                    role: "user",
                    content: userMessage,
                    displayContent: displayedUserMessage,
                    createdAt: timestamp,
                    attachmentTitles: userAttachmentTitles
                ),
                LocalChatMessage(
                    role: "assistant",
                    content: assistantMessage,
                    createdAt: timestamp,
                    versions: [LocalAssistantVersion(
                        content: assistantMessage,
                        displayContent: displayedAssistantMessage ?? assistantMessage,
                        citations: assistantCitations,
                        createdAt: timestamp
                    )]
                ),
            ],
            pendingUpload: true
        )
        activeSession = session
        state = .persistedActive
        store.upsert(session)
        return session
    }

    func syncCurrentConversation(messages: [LocalChatMessage], titleFallback: String) -> LocalChatSession? {
        guard var activeSession else { return nil }
        activeSession.title = activeSession.title.isEmpty ? titleFallback : activeSession.title
        activeSession.replaceMessages(messages)
        self.activeSession = activeSession
        state = .persistedActive
        store.upsert(activeSession)
        return activeSession
    }

    func openNewChat(currentDraft: String?, isStreaming: Bool) -> NewChatDecision {
        if isStreaming || state == .streamingFirstReply {
            return NewChatDecision(
                blockedMessage: localizedChatGenerationBlockedMessage(),
                injectedDraft: nil,
                state: state
            )
        }

        let trimmedDraft = currentDraft?.trimmingCharacters(in: .whitespacesAndNewlines)
        let injectedDraft = (trimmedDraft?.isEmpty == false ? trimmedDraft : nil) ?? detachedDraftBuffer
        detachedDraftBuffer = nil
        activeSession = nil
        state = .draftOnly
        return NewChatDecision(blockedMessage: nil, injectedDraft: injectedDraft, state: state)
    }

    func bufferDraftForHistorySwitch(_ draft: String?) {
        let trimmed = draft?.trimmingCharacters(in: .whitespacesAndNewlines)
        detachedDraftBuffer = trimmed?.isEmpty == false ? trimmed : nil
    }

    func restoreDetachedDraft() -> String? {
        let draft = detachedDraftBuffer
        detachedDraftBuffer = nil
        return draft
    }

    func switchToSession(id: String, currentDraft: String?) -> LocalChatSession? {
        bufferDraftForHistorySwitch(currentDraft)
        state = .switchingHistory
        guard let session = store.session(id: id), !session.isDeleted else {
            state = activeSession == nil ? .draftOnly : .persistedActive
            return nil
        }
        activeSession = session
        state = .persistedActive
        return session
    }


    func deleteSessions(ids: [String]) -> [LocalChatSession] {
        let deleted = ids.compactMap { store.removeLogically(id: $0) }
        if let activeSession, ids.contains(activeSession.id) {
            self.activeSession = nil
            state = .draftOnly
        }
        return deleted
    }

    func deleteCurrentSession() -> LocalChatSession? {
        guard let activeSession else {
            state = .draftOnly
            return nil
        }
        state = .persistedDeleting
        let deleted = store.removeLogically(id: activeSession.id)
        self.activeSession = nil
        state = .draftOnly
        return deleted
    }

    func visibleHistorySections() -> [LocalChatHistorySection] {
        store.groupedSections()
    }

    func visibleHistorySessions() -> [LocalChatSession] {
        store.allSessions().sorted { $0.updatedAt > $1.updatedAt }
    }

    func markUploadSuccess(sessionId: String, remoteId: String?) {
        store.markUploadSuccess(sessionId: sessionId, remoteId: remoteId)
        if var activeSession, activeSession.id == sessionId {
            activeSession.markUploaded(remoteId: remoteId)
            self.activeSession = activeSession
        }
    }

    func finalizeDelete(sessionId: String) {
        store.finalizeDelete(id: sessionId)
        if activeSession?.id == sessionId {
            activeSession = nil
            state = .draftOnly
        }
    }

    func syncPendingDeletes() async {
        let sessions = store.pendingDeleteSessions()
        for session in sessions {
            do {
                _ = try await remoteService.deleteChatHistory(clientSessionID: session.id, revision: session.revision)
                finalizeDelete(sessionId: session.id)
            } catch {
                continue
            }
        }
    }

    func syncPendingUploads() async {
        let sessions = store.pendingUploadSessions()
        for session in sessions {
            do {
                let remoteSession = try await remoteService.saveChatHistory(
                    clientSessionID: session.id,
                    revision: session.revision,
                    messages: session.visibleMessages
                )
                markUploadSuccess(sessionId: session.id, remoteId: remoteSession.id)
            } catch {
                continue
            }
        }
    }

    func syncSession(_ session: LocalChatSession) async throws -> ChatHistorySession {
        let remoteSession = try await remoteService.saveChatHistory(
            clientSessionID: session.id,
            revision: session.revision,
            messages: session.visibleMessages
        )
        markUploadSuccess(sessionId: session.id, remoteId: remoteSession.id)
        return remoteSession
    }

    func submitFeedback(
        for session: LocalChatSession,
        messageId: String,
        versionId: String,
        feedback: ChatFeedbackKind
    ) async throws -> ChatHistoryFeedbackResult {
        let apiFeedback: ChatHistoryFeedbackType = feedback == .like ? .up : .down
        return try await remoteService.sendChatHistoryFeedback(
            clientSessionID: session.id,
            messageID: messageId,
            versionID: versionId,
            feedback: apiFeedback,
            revision: session.revision
        )
    }

    func setFeedback(messageId: String, versionId: String, feedback: ChatFeedbackKind?) -> LocalChatSession? {
        guard var activeSession else { return nil }
        guard let index = activeSession.messages.firstIndex(where: { $0.id == messageId }) else { return nil }
        activeSession.messages[index].setActiveVersion(id: versionId)
        activeSession.messages[index].setFeedback(feedback)
        activeSession.touch()
        self.activeSession = activeSession
        store.upsert(activeSession)
        return activeSession
    }

    func appendRegeneratedVersion(
        messageId: String,
        content: String,
        displayContent: String? = nil,
        citations: [AssistantCitation] = []
    ) -> LocalChatSession? {
        guard var activeSession else { return nil }
        guard let index = activeSession.messages.firstIndex(where: { $0.id == messageId }) else { return nil }
        _ = activeSession.messages[index].appendVersion(
            content: content,
            displayContent: displayContent,
            citations: citations
        )
        activeSession.touch()
        self.activeSession = activeSession
        store.upsert(activeSession)
        return activeSession
    }

    func switchAssistantVersion(messageId: String, versionId: String) -> LocalChatSession? {
        guard var activeSession else { return nil }
        guard let index = activeSession.messages.firstIndex(where: { $0.id == messageId }) else { return nil }
        activeSession.messages[index].setActiveVersion(id: versionId)
        activeSession.touch()
        self.activeSession = activeSession
        store.upsert(activeSession)
        return activeSession
    }
}


private func localizedChatGenerationBlockedMessage() -> String {
    switch LocaleManager.shared.current {
    case .zh: return "Vvewell正在生成中，请稍后再创建新会话。"
    case .ar: return "يقوم Vvewell بالإنشاء الآن، يرجى إنشاء محادثة جديدة لاحقًا."
    case .en: return "Vvewell is generating. Please create a new conversation later."
    }
}
