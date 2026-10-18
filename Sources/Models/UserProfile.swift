import Foundation

/// 用户基础健康档案（六项基本信息），持久化至 UserDefaults
struct UserProfile: Codable {
    var name: String
    var gender: String       // "male" / "female" / "other"
    var birthday: Date?
    var heightCm: Double?
    var weightKg: Double?
    var bloodType: String    // "A" / "B" / "AB" / "O" / "unknown"

    init() {
        name = ""
        gender = ""
        birthday = nil
        heightCm = nil
        weightKg = nil
        bloodType = ""
    }
}

/// UserProfile 的本地持久化仓库（UserDefaults）
final class UserProfileRepository {
    static let shared = UserProfileRepository()
    private init() {}

    private let key = "user_profile_v1"
    private var cache: UserProfile?

    /// 读取当前用户档案，若从未保存则返回空档案
    /// - Returns: UserProfile 实例
    func fetch() -> UserProfile {
        if let cached = cache { return cached }
        guard let data = UserDefaults.standard.data(forKey: key),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile()
        }
        cache = profile
        return profile
    }

    /// 保存用户档案
    /// - Parameter profile: 待保存的 UserProfile
    func save(_ profile: UserProfile) {
        cache = profile
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
        NotificationCenter.default.post(name: .userProfileDidUpdate, object: profile)
    }

    func mergeFromOwnerProfile(_ profile: HealthProfile) {
        var current = fetch()
        var changed = false

        if !profile.name.isEmpty, current.name != profile.name {
            current.name = profile.name
            changed = true
        }

        if let gender = profile.gender?.rawValue, current.gender != gender {
            current.gender = gender
            changed = true
        }

        if current.birthday == nil,
           let birthYear = profile.birthYear,
           let inferredBirthday = Calendar.current.date(from: DateComponents(year: birthYear, month: 1, day: 1)) {
            current.birthday = inferredBirthday
            changed = true
        }

        if current.heightCm == nil, let heightCm = profile.heightCm {
            current.heightCm = heightCm
            changed = true
        }

        if current.weightKg == nil, let weightKg = profile.weightKg {
            current.weightKg = weightKg
            changed = true
        }

        if current.bloodType.isEmpty, let bloodType = profile.bloodType, !bloodType.isEmpty {
            current.bloodType = bloodType
            changed = true
        }

        guard changed else { return }
        save(current)
    }
}

extension Notification.Name {
    static let userProfileDidUpdate = Notification.Name("userProfileDidUpdate")
}
