import Foundation

// SyncStatus enum is defined in RawReading.swift to avoid circular dependencies.
// This file provides extensions for sync-related utilities.

// MARK: - SyncStatus Display

extension SyncStatus {
    /// Localized display name
    var displayName: String {
        switch self {
        case .local: return "本地"
        case .pending: return "待同步"
        case .uploading: return "同步中"
        case .synced: return "已同步"
        case .failed: return "同步失败"
        }
    }
    
    /// Icon for display
    var icon: String {
        switch self {
        case .local: return "📱"
        case .pending: return "⏳"
        case .uploading: return "📤"
        case .synced: return "✅"
        case .failed: return "❌"
        }
    }
    
    /// Whether this status indicates the reading needs syncing
    var needsSync: Bool {
        switch self {
        case .local, .pending, .failed:
            return true
        case .uploading, .synced:
            return false
        }
    }
}
