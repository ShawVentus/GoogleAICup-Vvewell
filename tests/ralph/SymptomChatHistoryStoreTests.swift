import XCTest
@testable import vvewell_app_ios_sim

final class SymptomChatHistoryStoreTests: XCTestCase {
    private let store = SymptomChatHistoryStore.shared

    override func setUp() {
        super.setUp()
        store.debugResetStorage()
        LocaleManager.shared.setLanguage(.zh)
    }

    func testLegacySessionMigratesIntoSingleLocalSession() throws {
        let messages = [
            AssistantChatMessage(role: "user", content: "你好"),
            AssistantChatMessage(role: "assistant", content: "您好，我能帮您什么？"),
        ]
        let legacy = LegacyTestSession(savedAt: 1_718_888_888, messages: messages, isComplete: true)
        let data = try JSONEncoder().encode(legacy)
        store.debugStoreLegacySessionData(data)
        store.debugRunLegacyMigration()

        let sessions = store.allSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.title, String("你好".prefix(24)))
        XCTAssertEqual(sessions.first?.messages.count, 2)
    }

    func testRetentionKeepsNewestHundredVisibleSessions() {
        for index in 0..<101 {
            let session = LocalChatSession(
                id: "session-\(index)",
                title: "title-\(index)",
                createdAt: TimeInterval(index),
                updatedAt: TimeInterval(index),
                revision: 1,
                messages: [LocalChatMessage(role: "user", content: "q\(index)", createdAt: TimeInterval(index))]
            )
            store.upsert(session)
        }

        let sessions = store.allSessions().sorted { $0.updatedAt < $1.updatedAt }
        XCTAssertEqual(sessions.count, 100)
        XCTAssertNil(sessions.first(where: { $0.id == "session-0" }))
        XCTAssertNotNil(sessions.first(where: { $0.id == "session-100" }))
    }

    func testGroupedSectionsUseTodayYesterdayEarlier() {
        let now = Date()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let earlier = calendar.date(byAdding: .day, value: -5, to: now)!
        store.upsert(LocalChatSession(id: "today", title: "today", createdAt: now.timeIntervalSince1970, updatedAt: now.timeIntervalSince1970, revision: 1, messages: []))
        store.upsert(LocalChatSession(id: "yesterday", title: "yesterday", createdAt: yesterday.timeIntervalSince1970, updatedAt: yesterday.timeIntervalSince1970, revision: 1, messages: []))
        store.upsert(LocalChatSession(id: "earlier", title: "earlier", createdAt: earlier.timeIntervalSince1970, updatedAt: earlier.timeIntervalSince1970, revision: 1, messages: []))

        let titles = store.groupedSections(now: now).map(\.title)
        XCTAssertEqual(titles, ["今天", "昨天", "更早"])
    }

    func testLogicalDeleteRemovesOnlySessionFromVisibleHistorySections() {
        let timestamp = Date().timeIntervalSince1970
        let session = LocalChatSession(
            id: "session-only",
            title: "only",
            createdAt: timestamp,
            updatedAt: timestamp,
            revision: 1,
            messages: [
                LocalChatMessage(role: "user", content: "头疼", createdAt: timestamp),
                LocalChatMessage(
                    role: "assistant",
                    content: "请补充时长",
                    createdAt: timestamp,
                    versions: [LocalAssistantVersion(content: "请补充时长", createdAt: timestamp)]
                ),
            ],
            pendingUpload: false
        )
        store.upsert(session)

        let deleted = store.removeLogically(id: session.id, at: Date(timeIntervalSince1970: timestamp + 1))

        XCTAssertEqual(deleted?.id, session.id)
        XCTAssertTrue(store.groupedSections(now: Date(timeIntervalSince1970: timestamp + 1)).isEmpty)
        XCTAssertEqual(store.pendingDeleteSessions().map(\.id), [session.id])
    }
}

private struct LegacyTestSession: Codable {
    let savedAt: TimeInterval
    let messages: [AssistantChatMessage]
    let isComplete: Bool?
}
