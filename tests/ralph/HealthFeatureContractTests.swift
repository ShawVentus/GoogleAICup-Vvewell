import UIKit
import XCTest
@testable import vvewell_app_ios_sim

@MainActor
final class AppSessionResetCoordinatorTests: XCTestCase {
    func testCoordinatorResetsParticipantsInRegistrationOrder() {
        var events: [String] = []
        let first = SpyResetParticipant(id: "first") { events.append("first") }
        let second = SpyResetParticipant(id: "second") { events.append("second") }

        let coordinator = AppSessionResetCoordinator(participants: [first, second])
        coordinator.resetUserScopedData()

        XCTAssertEqual(events, ["first", "second"])
    }

    func testCoordinatorDeduplicatesParticipantIDs() {
        var events: [String] = []
        let first = SpyResetParticipant(id: "shared") { events.append("first") }
        let duplicate = SpyResetParticipant(id: "shared") { events.append("duplicate") }

        let coordinator = AppSessionResetCoordinator(participants: [first, duplicate])
        coordinator.resetUserScopedData()

        XCTAssertEqual(events, ["first"])
    }

    func testDefaultCoordinatorClearsChatHistoryAndOcrReports() {
        SymptomChatHistoryStore.shared.debugResetStorage()
        OcrReportRepository.shared.clear()

        let chatSession = LocalChatSession(
            id: "chat-session",
            title: "头痛",
            createdAt: 1,
            updatedAt: 1,
            revision: 1,
            messages: [
                LocalChatMessage(role: "user", content: "头痛", createdAt: 1),
                LocalChatMessage(role: "assistant", content: "多休息", createdAt: 2),
            ]
        )
        SymptomChatHistoryStore.shared.upsert(chatSession)
        OcrReportRepository.shared.save(
            OcrReport(
                id: "ocr-device",
                date: Date(timeIntervalSince1970: 10),
                imageLocalPath: "",
                source: .device,
                items: []
            )
        )

        let coordinator = AppSessionResetComposer.makeDefaultCoordinator()
        coordinator.resetUserScopedData()

        XCTAssertTrue(SymptomChatHistoryStore.shared.allSessions().isEmpty)
        XCTAssertTrue(OcrReportRepository.shared.fetchAll().isEmpty)
    }
}

@MainActor
final class ProfileLogoutResetContractTests: XCTestCase {
    func testPerformLogoutUsesInjectedResetCoordinator() {
        let controller = ProfileViewController()
        let coordinator = SpyResetCoordinator()
        controller.sessionResetCoordinator = coordinator

        controller.loadViewIfNeeded()
        _ = controller.perform(NSSelectorFromString("performLogout"))

        XCTAssertEqual(coordinator.resetCount, 1)
    }
}

@MainActor
final class FamilyActiveProfileLinkageTests: XCTestCase {
    private var window: UIWindow?

    override func setUp() {
        super.setUp()
        LocaleManager.shared.setLanguage(.zh)
        try? HealthMetricStore.shared.initialize()
        HealthRecordRepository.shared.clear()
        UserProfileRepository.shared.save(UserProfile())
        resetProfiles()
    }

    override func tearDown() {
        HealthRecordRepository.shared.clear()
        UserProfileRepository.shared.save(UserProfile())
        resetProfiles()
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testHealthViewControllerUsesActiveProfileForBasicInfoAndLatestVitals() throws {
        let owner = try seedOwner(name: "本人", heightCm: 170)
        let child = try addProfile(name: "宝宝", relationship: .child, heightCm: 120)
        try ProfileManager.shared.setActiveProfile(id: child.id)
        try HealthRecordRepository.shared.save(
            HealthRecord(
                date: Date(timeIntervalSince1970: 20),
                profileId: owner.id,
                hr: 72,
                hrStatus: "normal",
                rr: 16,
                rrStatus: "normal",
                spo2: 98,
                spo2Status: "excellent",
                stressScore: 35,
                stressLevel: "normal",
                sqi: 0.9,
                confidence: "high",
                skinLabel: nil,
                skinI18n: nil
            )
        )
        try HealthRecordRepository.shared.save(
            HealthRecord(
                date: Date(timeIntervalSince1970: 40),
                profileId: child.id,
                hr: 88,
                hrStatus: "normal",
                rr: 20,
                rrStatus: "normal",
                spo2: 97,
                spo2Status: "excellent",
                stressScore: 42,
                stressLevel: "normal",
                sqi: 0.9,
                confidence: "high",
                skinLabel: nil,
                skinI18n: nil
            )
        )

        let controller = HealthViewController()
        host(controller)

        XCTAssertEqual(controller.nameValueLabel.text, "宝宝")
        XCTAssertEqual(controller.heightValueLabel.text, "120 \(t(.unitCentimeters))")
        XCTAssertEqual(controller.hrValueLabel.text, "88")
        XCTAssertEqual(controller.profileSwitcherStack.arrangedSubviews.count, 2)
    }

    func testMainHealthOverviewUsesActiveProfileLatestRecord() throws {
        let owner = try seedOwner(name: "本人")
        let spouse = try addProfile(name: "爱人", relationship: .spouse)
        try HealthRecordRepository.shared.save(
            HealthRecord(
                date: Date(timeIntervalSince1970: 20),
                profileId: owner.id,
                hr: 70,
                hrStatus: "normal",
                rr: 16,
                rrStatus: "normal",
                spo2: 99,
                spo2Status: "excellent",
                stressScore: 20,
                stressLevel: "normal",
                sqi: 0.9,
                confidence: "high",
                skinLabel: nil,
                skinI18n: nil
            )
        )
        try HealthRecordRepository.shared.save(
            HealthRecord(
                date: Date(timeIntervalSince1970: 30),
                profileId: spouse.id,
                hr: 93,
                hrStatus: "elevated",
                rr: 19,
                rrStatus: "normal",
                spo2: 96,
                spo2Status: "normal",
                stressScore: 56,
                stressLevel: "elevated",
                sqi: 0.8,
                confidence: "medium",
                skinLabel: nil,
                skinI18n: nil
            )
        )
        try ProfileManager.shared.setActiveProfile(id: spouse.id)

        let controller = MainViewController()
        host(controller)
        controller.refreshHealthOverview()

        XCTAssertEqual(controller.homeMetricCards[.heartRate]?.valueLabel.text, "93")
        XCTAssertEqual(controller.homeMetricCards[.stress]?.valueLabel.text, "56")
    }

    func testHealthRecordRepositoryFiltersByProfileAndKeepsLegacyForOwner() throws {
        let owner = try seedOwner(name: "本人")
        let child = try addProfile(name: "宝宝", relationship: .child)
        try HealthRecordRepository.shared.save(
            HealthRecord(
                date: Date(timeIntervalSince1970: 10),
                profileId: nil,
                hr: 66,
                hrStatus: "normal",
                rr: nil,
                rrStatus: nil,
                spo2: nil,
                spo2Status: nil,
                stressScore: nil,
                stressLevel: nil,
                sqi: nil,
                confidence: nil,
                skinLabel: nil,
                skinI18n: nil
            )
        )
        try HealthRecordRepository.shared.save(
            HealthRecord(
                date: Date(timeIntervalSince1970: 20),
                profileId: child.id,
                hr: 82,
                hrStatus: "normal",
                rr: nil,
                rrStatus: nil,
                spo2: nil,
                spo2Status: nil,
                stressScore: nil,
                stressLevel: nil,
                sqi: nil,
                confidence: nil,
                skinLabel: nil,
                skinI18n: nil
            )
        )

        XCTAssertEqual(HealthRecordRepository.shared.fetchAll(profileId: owner.id).count, 1)
        XCTAssertEqual(HealthRecordRepository.shared.fetchLatest(profileId: child.id)?.hr, 82)
    }

    private func resetProfiles() {
        let profiles = (try? ProfileManager.shared.allProfiles()) ?? []
        profiles.filter { $0.relationship != .owner }.forEach { profile in
            try? ProfileManager.shared.removeProfile(id: profile.id)
        }
        if let owner = try? ProfileManager.shared.ownerProfile() {
            var updated = owner
            updated.name = "本人"
            updated.birthYear = nil
            updated.heightCm = nil
            updated.weightKg = nil
            updated.bloodType = nil
            updated.gender = nil
            try? ProfileManager.shared.updateProfile(updated)
            _ = try? ProfileManager.shared.setActiveProfile(id: updated.id)
        }
    }

    @discardableResult
    private func seedOwner(name: String, heightCm: Double? = nil) throws -> HealthProfile {
        let owner: HealthProfile
        if var existing = try ProfileManager.shared.ownerProfile() {
            existing.name = name
            existing.heightCm = heightCm
            existing.birthYear = nil
            existing.weightKg = nil
            existing.bloodType = nil
            existing.gender = nil
            try ProfileManager.shared.updateProfile(existing)
            owner = existing
        } else {
            owner = try ProfileManager.shared.ensureOwnerProfile(name: name)
            if var reloaded = try ProfileManager.shared.ownerProfile() {
                reloaded.heightCm = heightCm
                try ProfileManager.shared.updateProfile(reloaded)
            }
        }
        try ProfileManager.shared.setActiveProfile(id: owner.id)
        return try XCTUnwrap(try ProfileManager.shared.ownerProfile())
    }

    @discardableResult
    private func addProfile(name: String, relationship: Relationship, heightCm: Double? = nil) throws -> HealthProfile {
        let profile = HealthProfile(name: name, relationship: relationship, heightCm: heightCm)
        try ProfileManager.shared.addProfile(profile)
        return try XCTUnwrap(try ProfileManager.shared.profile(id: profile.id))
    }

    private func host(_ controller: UIViewController) {
        let nav = UINavigationController(rootViewController: controller)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
        nav.loadViewIfNeeded()
        controller.loadViewIfNeeded()
        nav.view.layoutIfNeeded()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }
}

@MainActor
final class OcrHistoryLoaderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        OcrReportRepository.shared.clear()
        AuthTokenManager.shared.clearTokens()
    }

    override func tearDown() {
        OcrReportRepository.shared.clear()
        AuthTokenManager.shared.clearTokens()
        super.tearDown()
    }

    func testRefreshPreservesDeviceReportsAndHydratesCloudReports() async throws {
        AuthTokenManager.shared.storeTokens(access: "access", refresh: "refresh")
        OcrReportRepository.shared.save(
            OcrReport(
                id: "device-report",
                date: Date(timeIntervalSince1970: 10),
                imageLocalPath: "",
                source: .device,
                items: []
            )
        )

        let loader = OcrHistoryLoader(
            remoteFetcher: MockRemoteOcrFetcher(
                reports: [
                    makeRemoteOcrReport(id: "cloud-report", date: "2026-04-14T00:00:00Z"),
                ]
            ),
            repository: .shared,
            relayEnabled: true,
            authenticationRequired: false
        )

        let reports = try await loader.refresh(limit: 20)

        XCTAssertEqual(Set(reports.map(\.id)), ["device-report", "cloud-report"])
        XCTAssertTrue(reports.contains(where: { $0.id == "device-report" && $0.source == .device }))
        XCTAssertTrue(reports.contains(where: { $0.id == "cloud-report" && $0.source == .cloud }))
    }

    func testRefreshReplacesExistingCloudReportsByID() async throws {
        AuthTokenManager.shared.storeTokens(access: "access", refresh: "refresh")
        OcrReportRepository.shared.replaceReports(
            [
                OcrReport(
                    id: "cloud-stale",
                    date: Date(timeIntervalSince1970: 1),
                    imageLocalPath: "",
                    source: .cloud,
                    items: []
                ),
            ],
            for: .cloud
        )

        let loader = OcrHistoryLoader(
            remoteFetcher: MockRemoteOcrFetcher(
                reports: [
                    makeRemoteOcrReport(id: "cloud-fresh", date: "2026-04-14T00:00:00Z"),
                ]
            ),
            repository: .shared,
            relayEnabled: true,
            authenticationRequired: false
        )

        let reports = try await loader.refresh(limit: 20)

        XCTAssertEqual(reports.filter { $0.source == .cloud }.map(\.id), ["cloud-fresh"])
    }
}
