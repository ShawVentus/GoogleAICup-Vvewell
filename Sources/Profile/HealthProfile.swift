import Foundation

/// Family member health profile
struct HealthProfile: Identifiable, Codable {
    /// Unique identifier (UUID)
    let id: String
    
    /// Display name
    var name: String
    
    /// Avatar path or emoji
    var avatar: String?
    
    /// Relationship to the primary account holder
    var relationship: Relationship
    
    /// Birth year
    var birthYear: Int?
    
    /// Gender
    var gender: Gender?

    /// Height in cm
    var heightCm: Double?

    /// Weight in kg
    var weightKg: Double?

    /// Blood type
    var bloodType: String?
    
    /// Creation timestamp
    let createdAt: Double
    
    /// Last update timestamp
    var updatedAt: Double
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        name: String,
        avatar: String? = nil,
        relationship: Relationship,
        birthYear: Int? = nil,
        gender: Gender? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        bloodType: String? = nil
    ) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.relationship = relationship
        self.birthYear = birthYear
        self.gender = gender
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.bloodType = bloodType
        self.createdAt = Date().timeIntervalSince1970
        self.updatedAt = Date().timeIntervalSince1970
    }
}

// MARK: - Relationship

enum Relationship: String, Codable, CaseIterable {
    case owner      // Primary account holder
    case spouse     // Spouse/partner
    case parent     // Parent
    case child      // Child
    case other      // Other family member
    
    var displayName: String {
        switch self {
        case .owner: return t(.relationshipOwner)
        case .spouse: return t(.relationshipSpouse)
        case .parent: return t(.relationshipParent)
        case .child: return t(.relationshipChild)
        case .other: return t(.relationshipOther)
        }
    }
}

// MARK: - Gender

enum Gender: String, Codable {
    case male
    case female
    case other
    
    var displayName: String {
        switch self {
        case .male: return t(.healthProfileGenderMale)
        case .female: return t(.healthProfileGenderFemale)
        case .other: return t(.healthProfileGenderOther)
        }
    }
}

// MARK: - Database Mapping

extension HealthProfile {
    /// Create from database row
    init?(from row: [String: Any]) {
        guard let id = row["id"] as? String,
              let name = row["name"] as? String,
              let relationshipStr = row["relationship"] as? String,
              let relationship = Relationship(rawValue: relationshipStr),
              let createdAt = row["created_at"] as? Double,
              let updatedAt = row["updated_at"] as? Double else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.avatar = row["avatar"] as? String
        self.relationship = relationship
        self.birthYear = row["birth_year"] as? Int
        self.gender = (row["gender"] as? String).flatMap { Gender(rawValue: $0) }
        self.heightCm = row["height_cm"] as? Double
        self.weightKg = row["weight_kg"] as? Double
        self.bloodType = row["blood_type"] as? String
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Convert to dictionary for database
    func toDatabaseRow() -> [String: Any] {
        var row: [String: Any] = [
            "id": id,
            "name": name,
            "relationship": relationship.rawValue,
            "created_at": createdAt,
            "updated_at": updatedAt
        ]
        
        if let avatar = avatar { row["avatar"] = avatar }
        if let birthYear = birthYear { row["birth_year"] = birthYear }
        if let gender = gender { row["gender"] = gender.rawValue }
        if let heightCm = heightCm { row["height_cm"] = heightCm }
        if let weightKg = weightKg { row["weight_kg"] = weightKg }
        if let bloodType = bloodType, !bloodType.isEmpty { row["blood_type"] = bloodType }
        
        return row
    }
}
