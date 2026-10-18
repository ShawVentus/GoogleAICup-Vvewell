import Foundation

/// Binding between a device and its primary profile (owner).
/// A device can have one primary owner, but measurements can be
/// temporarily attributed to other family members.
struct DeviceBinding: Codable {
    /// Device type (primary key)
    let deviceType: DeviceType
    
    /// Device display name
    let deviceName: String
    
    /// Primary profile ID (default owner)
    let primaryProfileId: String
    
    /// Binding creation timestamp
    let createdAt: Double
    
    // MARK: - Initialization
    
    init(
        deviceType: DeviceType,
        deviceName: String,
        primaryProfileId: String
    ) {
        self.deviceType = deviceType
        self.deviceName = deviceName
        self.primaryProfileId = primaryProfileId
        self.createdAt = Date().timeIntervalSince1970
    }
}

// MARK: - Database Mapping

extension DeviceBinding {
    /// Create from database row
    init?(from row: [String: Any]) {
        guard let deviceTypeStr = row["device_type"] as? String,
              let deviceType = DeviceType(rawValue: deviceTypeStr),
              let deviceName = row["device_name"] as? String,
              let primaryProfileId = row["primary_profile_id"] as? String,
              let createdAt = row["created_at"] as? Double else {
            return nil
        }
        
        self.deviceType = deviceType
        self.deviceName = deviceName
        self.primaryProfileId = primaryProfileId
        self.createdAt = createdAt
    }
    
    /// Convert to dictionary for database
    func toDatabaseRow() -> [String: Any] {
        [
            "device_type": deviceType.rawValue,
            "device_name": deviceName,
            "primary_profile_id": primaryProfileId,
            "created_at": createdAt
        ]
    }
}
