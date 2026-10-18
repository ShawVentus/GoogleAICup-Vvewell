import Foundation

final class HealthRecordRepository {
    static let shared = HealthRecordRepository()
    private init() {}

    private let maxRecords = 50
    private var cache: [HealthRecord]?

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("health_records.json")
    }

    // MARK: - 读取所有记录（按日期倒序）

    /// 获取所有历史检测记录，按时间倒序排列
    /// - Returns: HealthRecord 数组
    func fetchAll(profileId: String? = nil) -> [HealthRecord] {
        let records = loadAll()
        guard let profileId, !profileId.isEmpty else { return records }
        return records.filter { matchesProfile($0, requestedProfileID: profileId) }
    }

    private func loadAll() -> [HealthRecord] {
        if let cached = cache { return cached }
        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode([HealthRecord].self, from: data) else {
            return []
        }
        let sorted = records.sorted { $0.date > $1.date }
        cache = sorted
        return sorted
    }

    /// 获取最近一条检测记录
    /// - Returns: 最新 HealthRecord，若无记录则返回 nil
    func fetchLatest(profileId: String? = nil) -> HealthRecord? {
        fetchAll(profileId: profileId).first
    }

    // MARK: - 保存新记录

    /// 保存检测记录，超过上限时自动淘汰最旧记录
    /// - Parameter record: 待保存的 HealthRecord
    func save(_ record: HealthRecord) throws {
        var records = loadAll()
        records.insert(record, at: 0)
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        let data = try JSONEncoder().encode(records)
        try data.write(to: fileURL, options: .atomic)
        cache = records
        NotificationCenter.default.post(name: .healthRecordsDidUpdate, object: record)
    }

    func clear() {
        cache = []
        try? FileManager.default.removeItem(at: fileURL)
        NotificationCenter.default.post(name: .healthRecordsDidUpdate, object: nil)
    }

    private func matchesProfile(_ record: HealthRecord, requestedProfileID: String) -> Bool {
        if let recordProfileID = record.profileId, !recordProfileID.isEmpty {
            return recordProfileID == requestedProfileID
        }
        let ownerProfileID: String?
        if let owner = try? ProfileManager.shared.ownerProfile() {
            ownerProfileID = owner.id
        } else {
            ownerProfileID = nil
        }
        return ownerProfileID == requestedProfileID
    }
}
