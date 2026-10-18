import Foundation

final class SymptomChatHistoryStore {
    static let shared = SymptomChatHistoryStore()

    private let defaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "com.vvewell.symptomChatHistoryStore")
    private let sessionsKey = "symptom_chat_sessions_v2"
    private let legacySessionKey = "symptom_chat_last_session_v1"
    private let historyHintKey = "symptom_chat_history_long_press_tip_shown_v1"
    private let maxSessions = 100

    private init() {
        migrateLegacySessionIfNeeded()
    }

    func allSessions(includeDeleted: Bool = false) -> [LocalChatSession] {
        queue.sync {
            let sessions = loadSessionsLocked()
            return includeDeleted ? sessions : sessions.filter { !$0.isDeleted }
        }
    }

    func latestVisibleSession() -> LocalChatSession? {
        allSessions().sorted { $0.updatedAt > $1.updatedAt }.first
    }

    func legacyFallbackSession() -> LocalChatSession? {
        queue.sync {
            guard let data = defaults.data(forKey: legacySessionKey), !data.isEmpty else { return nil }
            return decodeLegacySession(data)
        }
    }

    func session(id: String) -> LocalChatSession? {
        allSessions(includeDeleted: true).first(where: { $0.id == id })
    }

    func pendingDeleteSessions() -> [LocalChatSession] {
        allSessions(includeDeleted: true).filter { $0.pendingDelete }
    }

    func pendingUploadSessions() -> [LocalChatSession] {
        allSessions(includeDeleted: true).filter { !$0.isDeleted && $0.pendingUpload }
    }

    func upsert(_ session: LocalChatSession) {
        queue.sync {
            var sessions = loadSessionsLocked()
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
            } else {
                sessions.append(session)
            }
            saveSessionsLocked(trimmedSessions(sessions))
        }
    }

    func removeLogically(id: String, at date: Date = Date()) -> LocalChatSession? {
        queue.sync {
            var sessions = loadSessionsLocked()
            guard let index = sessions.firstIndex(where: { $0.id == id }) else { return nil }
            sessions[index].markPendingDelete(at: date.timeIntervalSince1970)
            let session = sessions[index]
            saveSessionsLocked(trimmedSessions(sessions))
            return session
        }
    }

    func finalizeDelete(id: String) {
        queue.sync {
            var sessions = loadSessionsLocked()
            sessions.removeAll { $0.id == id }
            saveSessionsLocked(sessions)
        }
    }

    func markUploadSuccess(sessionId: String, remoteId: String?) {
        queue.sync {
            var sessions = loadSessionsLocked()
            guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
            sessions[index].markUploaded(remoteId: remoteId)
            saveSessionsLocked(sessions)
        }
    }

    func setHistoryHintShown() {
        defaults.set(true, forKey: historyHintKey)
    }

    func shouldShowHistoryHint() -> Bool {
        defaults.bool(forKey: historyHintKey) == false
    }

    func clearAll() {
        queue.sync {
            defaults.removeObject(forKey: sessionsKey)
            defaults.removeObject(forKey: legacySessionKey)
            defaults.removeObject(forKey: historyHintKey)
        }
    }

    func groupedSections(now: Date = Date()) -> [LocalChatHistorySection] {
        let sessions = allSessions().sorted { $0.updatedAt > $1.updatedAt }
        guard !sessions.isEmpty else { return [] }

        let calendar = Calendar.current
        let today = sessions.filter { calendar.isDate(Date(timeIntervalSince1970: $0.updatedAt), inSameDayAs: now) }
        let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterday = sessions.filter {
            let date = Date(timeIntervalSince1970: $0.updatedAt)
            return !calendar.isDate(date, inSameDayAs: now) && calendar.isDate(date, inSameDayAs: yesterdayDate)
        }
        let earlier = sessions.filter {
            let date = Date(timeIntervalSince1970: $0.updatedAt)
            return !calendar.isDate(date, inSameDayAs: now) && !calendar.isDate(date, inSameDayAs: yesterdayDate)
        }

        return [
            today.isEmpty ? nil : LocalChatHistorySection(title: localizedRelativeTitle(.today), sessions: today),
            yesterday.isEmpty ? nil : LocalChatHistorySection(title: localizedRelativeTitle(.yesterday), sessions: yesterday),
            earlier.isEmpty ? nil : LocalChatHistorySection(title: localizedRelativeTitle(.earlier), sessions: earlier),
        ].compactMap { $0 }
    }

    private func trimmedSessions(_ sessions: [LocalChatSession]) -> [LocalChatSession] {
        let keptDeleted = sessions.filter(\.isDeleted)
        let visible = sessions.filter { !$0.isDeleted }.sorted { $0.updatedAt > $1.updatedAt }
        return Array(visible.prefix(maxSessions)) + keptDeleted
    }

    private func migrateLegacySessionIfNeeded() {
        queue.sync {
            let existing = loadSessionsLocked()
            guard existing.isEmpty,
                  let data = defaults.data(forKey: legacySessionKey),
                  !data.isEmpty else { return }

            if let session = decodeLegacySession(data) {
                saveSessionsLocked([session])
            }
        }
    }

    private func decodeLegacySession(_ data: Data) -> LocalChatSession? {
        if let legacy = try? JSONDecoder().decode(LegacyPersistedSession.self, from: data) {
            return LocalChatSession.fromLegacy(
                messages: legacy.messages,
                savedAt: legacy.savedAt,
                isComplete: legacy.isComplete ?? true
            )
        }

        if let messages = try? JSONDecoder().decode([AssistantChatMessage].self, from: data) {
            return LocalChatSession.fromLegacy(messages: messages, savedAt: Date().timeIntervalSince1970, isComplete: true)
        }

        return nil
    }

    private func loadSessionsLocked() -> [LocalChatSession] {
        guard let data = defaults.data(forKey: sessionsKey), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([LocalChatSession].self, from: data)) ?? []
    }

    private func saveSessionsLocked(_ sessions: [LocalChatSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: sessionsKey)
    }
}

extension SymptomChatHistoryStore: UserScopedResetParticipant {
    var resetParticipantID: String { "symptom_chat_history" }

    func resetUserScopedData() {
        clearAll()
    }
}

#if DEBUG
extension SymptomChatHistoryStore {
    func debugResetStorage() {
        clearAll()
    }

    func debugRunLegacyMigration() {
        migrateLegacySessionIfNeeded()
    }

    func debugStoreLegacySessionData(_ data: Data) {
        defaults.set(data, forKey: legacySessionKey)
    }
}
#endif

private struct LegacyPersistedSession: Codable {
    let savedAt: TimeInterval
    let messages: [AssistantChatMessage]
    let isComplete: Bool?
}


private enum RelativeHistoryBucket {
    case today
    case yesterday
    case earlier
}

private func localizedRelativeTitle(_ bucket: RelativeHistoryBucket) -> String {
    switch (LocaleManager.shared.current, bucket) {
    case (.zh, .today): return "今天"
    case (.zh, .yesterday): return "昨天"
    case (.zh, .earlier): return "更早"
    case (.ar, .today): return "اليوم"
    case (.ar, .yesterday): return "أمس"
    case (.ar, .earlier): return "الأقدم"
    case (.en, .today), (.es, .today), (.fr, .today), (.id, .today), (.th, .today): return "Today"
    case (.en, .yesterday), (.es, .yesterday), (.fr, .yesterday), (.id, .yesterday), (.th, .yesterday): return "Yesterday"
    case (.en, .earlier), (.es, .earlier), (.fr, .earlier), (.id, .earlier), (.th, .earlier): return "Earlier"
    }
}
