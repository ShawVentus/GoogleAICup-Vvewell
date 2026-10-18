import Foundation

final class OcrReportRepository {
    static let shared = OcrReportRepository()
    private init() {}
    private let lock = NSRecursiveLock()

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("ocr_reports.json")
    }

    func fetchAll() -> [OcrReport] {
        withLock { fetchAllUnlocked() }
    }

    private func fetchAllUnlocked() -> [OcrReport] {
        guard let data = try? Data(contentsOf: fileURL),
              let reports = try? JSONDecoder().decode([OcrReport].self, from: data) else {
            return []
        }
        return reports.sorted { $0.date > $1.date }
    }

    func save(_ report: OcrReport) {
        withLock {
            var all = fetchAllUnlocked()
            all.removeAll { $0.id == report.id }
            all.insert(report, at: 0)
            persistUnlocked(all)
        }
    }

    func replaceReports(_ reports: [OcrReport], for source: OcrReport.Source) {
        withLock {
            let preserved = fetchAllUnlocked().filter { $0.source != source }
            persistUnlocked(preserved + reports)
        }
    }

    func remove(id: String) {
        withLock {
            let all = fetchAllUnlocked()
            let removed = all.first(where: { $0.id == id })
            let remaining = all.filter { $0.id != id }
            persistUnlocked(remaining)

            if let removed, !removed.imageLocalPath.isEmpty {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                try? FileManager.default.removeItem(at: docs.appendingPathComponent(removed.imageLocalPath))
            }
        }
    }

    func clear() {
        withLock {
            try? FileManager.default.removeItem(at: fileURL)
            postDidUpdate()
        }
    }

    private func persistUnlocked(_ reports: [OcrReport]) {
        let deduped = Dictionary(grouping: reports, by: \.id)
            .compactMap { _, values in values.max(by: { $0.date < $1.date }) }
            .sorted { $0.date > $1.date }
        guard let data = try? JSONEncoder().encode(deduped) else { return }
        try? data.write(to: fileURL, options: .atomic)
        postDidUpdate()
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func postDidUpdate() {
        let post = {
            NotificationCenter.default.post(name: .ocrReportsDidUpdate, object: nil)
        }
        if Thread.isMainThread {
            post()
        } else {
            DispatchQueue.main.async(execute: post)
        }
    }
}

extension OcrReportRepository: UserScopedResetParticipant {
    var resetParticipantID: String { "ocr_reports" }

    func resetUserScopedData() {
        clear()
    }
}

extension Notification.Name {
    static let ocrReportsDidUpdate = Notification.Name("ocrReportsDidUpdate")
}
