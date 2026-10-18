import UIKit
import XCTest
@testable import vvewell_app_ios_sim

func mirrorValue(named label: String, in subject: Any) -> Any? {
    var mirror: Mirror? = Mirror(reflecting: subject)
    while let current = mirror {
        for child in current.children where child.label == label {
            return unwrapOptional(child.value)
        }
        mirror = current.superclassMirror
    }
    return nil
}

func unwrapOptional(_ value: Any) -> Any? {
    let mirror = Mirror(reflecting: value)
    guard mirror.displayStyle == .optional else { return value }
    return mirror.children.first?.value
}

extension UIView {
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let view = self as? T { return view }
        for subview in subviews {
            if let match = subview.firstSubview(of: type) {
                return match
            }
        }
        return nil
    }

    var recursiveSubviews: [UIView] {
        subviews + subviews.flatMap(\.recursiveSubviews)
    }

    var containsAnimatingActivityIndicator: Bool {
        recursiveSubviews
            .compactMap { $0 as? UIActivityIndicatorView }
            .contains { $0.isAnimating }
    }

    func firstLabel(withText text: String) -> UILabel? {
        recursiveSubviews
            .compactMap { $0 as? UILabel }
            .first(where: { $0.text == text })
    }

    func containsLabel(text: String) -> Bool {
        firstLabel(withText: text) != nil
    }

    func containsAnyLabel(texts: [String]) -> Bool {
        texts.contains(where: containsLabel(text:))
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

@MainActor
func waitForCondition(
    timeout: TimeInterval = 1,
    pollInterval: TimeInterval = 0.01,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () -> Bool
) {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return
        }
        pumpRunLoop(for: pollInterval)
    }
    XCTAssertTrue(condition(), "Timed out waiting for condition.", file: file, line: line)
}

@MainActor
func pumpRunLoop(for interval: TimeInterval = 0.05) {
    RunLoop.current.run(until: Date().addingTimeInterval(interval))
}

final class SpyResetParticipant: UserScopedResetParticipant {
    let resetParticipantID: String
    private let onReset: () -> Void

    init(id: String, onReset: @escaping () -> Void) {
        self.resetParticipantID = id
        self.onReset = onReset
    }

    func resetUserScopedData() {
        onReset()
    }
}

final class SpyResetCoordinator: UserScopedResetting {
    private(set) var resetCount = 0

    func resetUserScopedData() {
        resetCount += 1
    }
}

struct MockRemoteOcrFetcher: RemoteOcrReportsFetching {
    let reports: [RemoteOcrReport]

    func fetchOcrReports(limit: Int) async throws -> [RemoteOcrReport] {
        Array(reports.prefix(limit))
    }
}

func makeRemoteOcrReport(id: String, date: String) -> RemoteOcrReport {
    let payload: [String: Any] = [
        "id": id,
        "report_date": date,
        "created_at": date,
        "payload": [
            "report_type": "blood",
            "hospital": "Vvewell",
            "report_date": date,
            "items": [],
        ],
    ]
    let data = try! JSONSerialization.data(withJSONObject: payload)
    return try! JSONDecoder().decode(RemoteOcrReport.self, from: data)
}
