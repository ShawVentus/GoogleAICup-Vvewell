import Foundation
import Combine

private actor ProfileMergeCoordinator {
    private var inFlight: (id: UUID, task: Task<Void, Error>)?

    func existing() -> (UUID, Task<Void, Error>)? {
        inFlight
    }

    func set(id: UUID, task: Task<Void, Error>) {
        inFlight = (id, task)
    }

    func clear(id: UUID) {
        guard inFlight?.id == id else { return }
        inFlight = nil
    }
}

/// Manages family member profiles and device bindings.
/// Provides CRUD operations backed by SQLite.
final class ProfileManager {
    
    // MARK: - Singleton
    
    static let shared = ProfileManager()
    
    // MARK: - Properties
    
    /// Database reference
    private let db: SQLiteDatabase
    private let mergeCoordinator = ProfileMergeCoordinator()
    
    /// Currently active profile ID (whose data is shown on dashboard)
    @Published var activeProfileId: String = ""
    
    /// Notification when profiles change
    let profilesChanged = PassthroughSubject<Void, Never>()

    /// Notification when active profile changes
    let activeProfileChanged = PassthroughSubject<String, Never>()
    
    // MARK: - Initialization
    
    init(database: SQLiteDatabase = .shared) {
        self.db = database
    }
    
    // MARK: - Profile CRUD
    
    /// Get all family profiles
    func allProfiles() throws -> [HealthProfile] {
        try db.run {
            try db.query("SELECT * FROM profiles ORDER BY relationship ASC, created_at ASC", mapProfile)
        }
    }
    
    /// Get profile by ID
    func profile(id: String) throws -> HealthProfile? {
        let results = try db.run {
            try db.query(
                "SELECT * FROM profiles WHERE id = ?",
                params: [id],
                mapProfile
            )
        }
        return results.first
    }
    
    /// Get the owner profile (primary account holder)
    func ownerProfile() throws -> HealthProfile? {
        let results = try db.run {
            try db.query(
                "SELECT * FROM profiles WHERE relationship = ? LIMIT 1",
                params: [Relationship.owner.rawValue],
                mapProfile
            )
        }
        return results.first
    }
    
    /// Add a new profile
    func addProfile(_ profile: HealthProfile) throws {
        _ = try db.run {
            try db.insert(table: "profiles", values: profile.toDatabaseRow())
        }
        if profile.relationship == .owner {
            UserProfileRepository.shared.mergeFromOwnerProfile(profile)
        }
        profilesChanged.send()
        triggerCloudSyncIfPossible()
        
        // If this is the owner, set as active
        if profile.relationship == .owner && activeProfileId.isEmpty {
            updateActiveProfileID(profile.id)
        }
    }
    
    /// Update an existing profile
    func updateProfile(_ profile: HealthProfile) throws {
        var updated = profile
        updated.updatedAt = Date().timeIntervalSince1970

        _ = try db.run {
            try db.update(
                table: "profiles",
                values: [
                    "name": updated.name,
                    "avatar": updated.avatar as Any,
                    "relationship": updated.relationship.rawValue,
                    "birth_year": updated.birthYear as Any,
                    "gender": updated.gender?.rawValue as Any,
                    "height_cm": updated.heightCm as Any,
                    "weight_kg": updated.weightKg as Any,
                    "blood_type": updated.bloodType as Any,
                    "updated_at": updated.updatedAt
                ],
                where: "id = ?",
                params: [profile.id]
            )
        }
        if updated.relationship == .owner {
            UserProfileRepository.shared.mergeFromOwnerProfile(updated)
        }
        profilesChanged.send()
        triggerCloudSyncIfPossible()
    }
    
    /// Remove a profile (cannot remove owner)
    func removeProfile(id: String) throws {
        // Check it's not the owner
        if let profile = try profile(id: id), profile.relationship == .owner {
            throw ProfileError.cannotRemoveOwner
        }

        _ = try db.run {
            try db.delete(from: "profiles", where: "id = ?", params: [id])
        }
        
        // Switch active if needed
        if activeProfileId == id {
            if let owner = try ownerProfile() {
                updateActiveProfileID(owner.id)
            } else {
                updateActiveProfileID("")
            }
        }
        
        profilesChanged.send()
        triggerCloudDeleteIfPossible(id: id)
    }
    
    /// Create or get the owner profile (ensures one always exists)
    func ensureOwnerProfile(name: String, gender: Gender? = nil, birthYear: Int? = nil) throws -> HealthProfile {
        if let existing = try ownerProfile() {
            return existing
        }
        
        let owner = HealthProfile(
            name: name,
            relationship: .owner,
            birthYear: birthYear,
            gender: gender
        )
        
        try addProfile(owner)
        updateActiveProfileID(owner.id)
        return owner
    }

    func upsertOwnerProfile(from userProfile: UserProfile) throws {
        let resolvedName: String
        if let existing = try ownerProfile(), !existing.name.isEmpty {
            resolvedName = userProfile.name.isEmpty ? existing.name : userProfile.name
        } else {
            resolvedName = userProfile.name.isEmpty ? "Owner" : userProfile.name
        }

        let birthYear = userProfile.birthday.map { Calendar.current.component(.year, from: $0) }
        let mappedGender = Gender(rawValue: userProfile.gender)
        let mappedHeight = userProfile.heightCm
        let mappedWeight = userProfile.weightKg
        let mappedBloodType = userProfile.bloodType.isEmpty ? nil : userProfile.bloodType

        if var existing = try ownerProfile() {
            existing.name = resolvedName
            existing.birthYear = birthYear
            existing.gender = mappedGender
            existing.heightCm = mappedHeight
            existing.weightKg = mappedWeight
            existing.bloodType = mappedBloodType
            try updateProfile(existing)
        } else {
            let owner = HealthProfile(
                name: resolvedName,
                relationship: .owner,
                birthYear: birthYear,
                gender: mappedGender,
                heightCm: mappedHeight,
                weightKg: mappedWeight,
                bloodType: mappedBloodType
            )
            try addProfile(owner)
            updateActiveProfileID(owner.id)
        }
    }

    // MARK: - Cloud Sync Foundation

    func syncToCloud() async throws {
        guard Config.useRelay, AuthTokenManager.shared.isLoggedIn else { return }
        try await APIClient.shared.syncProfiles(try allProfiles())
    }

    func mergeProfilesFromCloud() async throws {
        guard Config.useRelay, AuthTokenManager.shared.isLoggedIn else { return }
        if let (_, existingTask) = await mergeCoordinator.existing() {
            return try await existingTask.value
        }

        let mergeID = UUID()
        let task = Task<Void, Error> { [weak self] in
            guard let self else { return }
            let remoteProfiles = try await APIClient.shared.fetchProfiles()
            try self.db.run {
                try self.db.inTransaction {
                    for profile in remoteProfiles {
                        try self.upsertProfileLocked(profile, preserveUpdatedAt: true)
                    }
                }
            }
        }

        await mergeCoordinator.set(id: mergeID, task: task)
        defer { Task { await self.mergeCoordinator.clear(id: mergeID) } }

        try await task.value

        if let owner = try ownerProfile() {
            UserProfileRepository.shared.mergeFromOwnerProfile(owner)
        }
        profilesChanged.send()
    }

    private func upsertProfile(_ profile: HealthProfile, preserveUpdatedAt: Bool) throws {
        try db.run {
            try upsertProfileLocked(profile, preserveUpdatedAt: preserveUpdatedAt)
        }

        if profile.relationship == .owner && activeProfileId.isEmpty {
            updateActiveProfileID(profile.id)
        }

        if profile.relationship == .owner {
            UserProfileRepository.shared.mergeFromOwnerProfile(profile)
        }
    }

    private func triggerCloudSyncIfPossible() {
        guard Config.useRelay, AuthTokenManager.shared.isLoggedIn else { return }
        Task {
            try? await self.syncToCloud()
        }
    }

    private func triggerCloudDeleteIfPossible(id: String) {
        guard Config.useRelay, AuthTokenManager.shared.isLoggedIn else { return }
        Task {
            try? await APIClient.shared.deleteProfile(id: id)
        }
    }

    private func mapProfile(_ stmt: OpaquePointer) -> HealthProfile? {
        let row: [String: Any] = [
            "id": SQLiteDatabase.string(stmt, 0) as Any,
            "name": SQLiteDatabase.string(stmt, 1) as Any,
            "avatar": SQLiteDatabase.string(stmt, 2) as Any,
            "relationship": SQLiteDatabase.string(stmt, 3) as Any,
            "birth_year": SQLiteDatabase.int(stmt, 4),
            "gender": SQLiteDatabase.string(stmt, 5) as Any,
            "created_at": SQLiteDatabase.double(stmt, 6),
            "updated_at": SQLiteDatabase.double(stmt, 7),
            "height_cm": SQLiteDatabase.double(stmt, 8),
            "weight_kg": SQLiteDatabase.double(stmt, 9),
            "blood_type": SQLiteDatabase.string(stmt, 10) as Any
        ]
        return HealthProfile(from: row)
    }

    private func upsertProfileLocked(_ profile: HealthProfile, preserveUpdatedAt: Bool) throws {
        let updatedAt = preserveUpdatedAt ? profile.updatedAt : Date().timeIntervalSince1970
        let existing = try db.query(
            "SELECT id FROM profiles WHERE id = ? LIMIT 1",
            params: [profile.id]
        ) { _ in true }.first ?? false

        if existing {
            try db.update(
                table: "profiles",
                values: [
                    "name": profile.name,
                    "avatar": profile.avatar as Any,
                    "relationship": profile.relationship.rawValue,
                    "birth_year": profile.birthYear as Any,
                    "gender": profile.gender?.rawValue as Any,
                    "height_cm": profile.heightCm as Any,
                    "weight_kg": profile.weightKg as Any,
                    "blood_type": profile.bloodType as Any,
                    "updated_at": updatedAt
                ],
                where: "id = ?",
                params: [profile.id]
            )
        } else {
            var row = profile.toDatabaseRow()
            row["updated_at"] = updatedAt
            try db.insert(table: "profiles", values: row)
        }
    }
    
    // MARK: - Device Bindings
    
    /// Get all device bindings
    func allBindings() throws -> [DeviceBinding] {
        try db.query("SELECT * FROM device_bindings") { stmt in
            let row: [String: Any] = [
                "device_type": SQLiteDatabase.string(stmt, 0) as Any,
                "device_name": SQLiteDatabase.string(stmt, 1) as Any,
                "primary_profile_id": SQLiteDatabase.string(stmt, 2) as Any,
                "created_at": SQLiteDatabase.double(stmt, 3)
            ]
            return DeviceBinding(from: row)
        }
    }
    
    /// Get binding for a device type
    func binding(for deviceType: DeviceType) throws -> DeviceBinding? {
        let results = try db.query(
            "SELECT * FROM device_bindings WHERE device_type = ?",
            params: [deviceType.rawValue]
        ) { stmt in
            let row: [String: Any] = [
                "device_type": SQLiteDatabase.string(stmt, 0) as Any,
                "device_name": SQLiteDatabase.string(stmt, 1) as Any,
                "primary_profile_id": SQLiteDatabase.string(stmt, 2) as Any,
                "created_at": SQLiteDatabase.double(stmt, 3)
            ]
            return DeviceBinding(from: row)
        }
        return results.first
    }
    
    /// Bind a device to a profile
    func bindDevice(_ binding: DeviceBinding) throws {
        let row = binding.toDatabaseRow()
        // Use INSERT OR REPLACE for upsert
        let columns = row.keys.sorted()
        let placeholders = columns.map { _ in "?" }.joined(separator: ", ")
        let sql = "INSERT OR REPLACE INTO device_bindings (\(columns.joined(separator: ", "))) VALUES (\(placeholders))"
        try db.execute(sql)
    }
    
    /// Unbind a device
    func unbindDevice(type: DeviceType) throws {
        try db.delete(from: "device_bindings", where: "device_type = ?", params: [type.rawValue])
    }
    
    /// Get the profile ID for a device (for default measurement attribution)
    func profileId(for deviceType: DeviceType) throws -> String {
        if let binding = try binding(for: deviceType) {
            return binding.primaryProfileId
        }
        // Fallback to active profile
        return try resolveActiveProfileID() ?? activeProfileId
    }

    func activeProfile() throws -> HealthProfile? {
        if !activeProfileId.isEmpty, let profile = try profile(id: activeProfileId) {
            return profile
        }
        if let owner = try ownerProfile() {
            if activeProfileId != owner.id {
                updateActiveProfileID(owner.id)
            }
            return owner
        }
        if let firstProfile = try allProfiles().first {
            updateActiveProfileID(firstProfile.id)
            return firstProfile
        }
        return nil
    }

    @discardableResult
    func setActiveProfile(id: String) throws -> HealthProfile {
        guard let profile = try profile(id: id) else {
            throw ProfileError.profileNotFound(id)
        }
        updateActiveProfileID(profile.id)
        return profile
    }

    func resolveActiveProfileID() throws -> String? {
        try activeProfile()?.id
    }

    private func updateActiveProfileID(_ newID: String) {
        guard activeProfileId != newID else { return }
        activeProfileId = newID
        activeProfileChanged.send(newID)
        let post = {
            NotificationCenter.default.post(name: .activeHealthProfileDidChange, object: newID)
        }
        if Thread.isMainThread {
            post()
        } else {
            DispatchQueue.main.async(execute: post)
        }
    }
}

// MARK: - Errors

enum ProfileError: Error, LocalizedError {
    case cannotRemoveOwner
    case profileNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .cannotRemoveOwner:
            return t(.healthProfileCannotRemoveOwner)
        case .profileNotFound(let id):
            return String(format: t(.healthProfileProfileNotFoundFormat), id)
        }
    }
}

extension Notification.Name {
    static let activeHealthProfileDidChange = Notification.Name("activeHealthProfileDidChange")
}
