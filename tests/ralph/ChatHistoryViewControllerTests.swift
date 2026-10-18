import XCTest
import UIKit
@testable import vvewell_app_ios_sim

@MainActor
final class ChatHistoryViewControllerTests: XCTestCase {
    private let store = SymptomChatHistoryStore.shared

    override func setUp() {
        super.setUp()
        store.debugResetStorage()
        store.setHistoryHintShown()
        LocaleManager.shared.setLanguage(.zh)
    }

    func testEmptyHistoryShowsEmptyStateAndDisablesLongPressDeletion() throws {
        let sut = makeSUT()

        sut.loadViewIfNeeded()

        let tableView = try XCTUnwrap(sut.view.firstSubview(of: UITableView.self))
        let emptyLabel = try XCTUnwrap(sut.view.firstLabel(withText: "暂时没有对话，请去创建对话"))
        _ = try XCTUnwrap(tableView.gestureRecognizers?.first(where: { $0 is UILongPressGestureRecognizer }) as? UILongPressGestureRecognizer)

        XCTAssertTrue(tableView.isHidden)
        XCTAssertFalse(emptyLabel.isHidden)
        XCTAssertFalse(tableView.isUserInteractionEnabled)
        XCTAssertNil(sut.navigationItem.leftBarButtonItem)
    }

    func testExistingHistoryShowsTableAndEnablesLongPressDeletion() throws {
        store.upsert(
            LocalChatSession(
                id: "session-1",
                title: "头痛",
                createdAt: 100,
                updatedAt: 100,
                revision: 1,
                messages: [
                    LocalChatMessage(role: "user", content: "头痛", createdAt: 100),
                    LocalChatMessage(role: "assistant", content: "先观察症状", createdAt: 101),
                ]
            )
        )
        let sut = makeSUT()

        sut.loadViewIfNeeded()

        let tableView = try XCTUnwrap(sut.view.firstSubview(of: UITableView.self))
        let emptyLabel = try XCTUnwrap(sut.view.firstLabel(withText: "暂时没有对话，请去创建对话"))
        _ = try XCTUnwrap(tableView.gestureRecognizers?.first(where: { $0 is UILongPressGestureRecognizer }) as? UILongPressGestureRecognizer)

        XCTAssertFalse(tableView.isHidden)
        XCTAssertTrue(emptyLabel.isHidden)
        XCTAssertTrue(tableView.isUserInteractionEnabled)
        XCTAssertEqual(tableView.numberOfSections, 1)
        XCTAssertEqual(tableView.numberOfRows(inSection: 0), 1)
    }

    private func makeSUT() -> ChatHistoryViewController {
        ChatHistoryViewController(
            coordinator: SymptomChatSessionCoordinator(store: store),
            onSelect: { _ in },
            onDelete: { _ in }
        )
    }
}
