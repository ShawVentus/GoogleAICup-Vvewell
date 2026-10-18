import Foundation

protocol UserScopedResetParticipant {
    var resetParticipantID: String { get }
    func resetUserScopedData()
}

protocol UserScopedResetting {
    func resetUserScopedData()
}

final class AppSessionResetCoordinator: UserScopedResetting {
    private let participants: [UserScopedResetParticipant]

    init(participants: [UserScopedResetParticipant]) {
        var seen = Set<String>()
        self.participants = participants.filter { participant in
            seen.insert(participant.resetParticipantID).inserted
        }
    }

    func resetUserScopedData() {
        participants.forEach { $0.resetUserScopedData() }
    }
}

enum AppSessionResetComposer {
    static func makeDefaultCoordinator() -> UserScopedResetting {
        AppSessionResetCoordinator(
            participants: [
                SymptomChatHistoryStore.shared,
                OcrReportRepository.shared,
            ]
        )
    }
}
