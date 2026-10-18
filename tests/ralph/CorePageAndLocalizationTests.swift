import UIKit
import XCTest
@testable import vvewell_app_ios_sim

@MainActor
final class CorePageSmokeTests: XCTestCase {
    private var window: UIWindow?

    override func setUp() {
        super.setUp()
        LocaleManager.shared.setLanguage(.zh)
        AuthTokenManager.shared.clearTokens()
        AuthManager.shared.logout()
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testHealthViewControllerLoadsPrimarySections() {
        let controller = HealthViewController()
        host(controller)

        XCTAssertEqual(controller.titleLabel.text, t(.healthRecordTitle))
        XCTAssertEqual(controller.vitalsCardTitleLabel.text, t(.healthRecordLatestVitals))
        XCTAssertEqual(controller.checkHistoryTitleLabel.text, t(.healthProfileCheckHistory))
        XCTAssertEqual(controller.ocrTitleLabel.text, t(.healthProfileOcrHistory))
        XCTAssertNotNil(controller.view.firstSubview(of: UIScrollView.self))
        XCTAssertNil(controller.presentedViewController)
    }

    func testMyDevicesViewControllerLoadsWithoutCrash() {
        let controller = MyDevicesViewController()
        host(controller)

        XCTAssertEqual(controller.title, t(.profileMyDevices))
        XCTAssertTrue(controller.view.containsAnyLabel(texts: [t(.myDevicesConnectTitle), t(.profileMyDevices)]))
        XCTAssertNotNil(controller.view.firstSubview(of: UIScrollView.self))
        XCTAssertNil(controller.presentedViewController)
    }

    func testProfileViewControllerLoadsCoreSections() {
        let controller = ProfileViewController()
        host(controller)

        XCTAssertTrue(controller.view.containsLabel(text: t(.profileTitle)))
        XCTAssertTrue(controller.view.containsLabel(text: t(.profileSectionHealth)))
        XCTAssertTrue(controller.view.containsLabel(text: t(.profileSectionServices)))
        XCTAssertNotNil(controller.view.firstSubview(of: UIScrollView.self))
        XCTAssertNil(controller.presentedViewController)
    }

    func testMainViewControllerLoadsCoachAndConnectedDeviceEntry() {
        let controller = MainViewController()
        host(controller)

        XCTAssertTrue(controller.view.containsLabel(text: "健康教练"))
        XCTAssertEqual(controller.coachSectionView.superview, controller.contentView)
        XCTAssertEqual(controller.connectedDeviceBanner.superview, controller.contentView)
        let deviceTitle = controller.connectedDeviceTitleLabel?.text ?? ""
        XCTAssertTrue(deviceTitle.hasPrefix("已连接设备") || deviceTitle == "连接你的健康设备")
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
final class CorePageInteractionSmokeTests: XCTestCase {
    private var window: UIWindow?

    override func setUp() {
        super.setUp()
        LocaleManager.shared.setLanguage(.zh)
        AuthTokenManager.shared.clearTokens()
        AuthManager.shared.logout()
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testHealthViewControllerNewCheckPushesHealthCheckScreen() {
        let controller = HealthViewController()
        let nav = host(controller)

        controller.newCheckTapped()
        pumpRunLoop()

        XCTAssertTrue(nav.topViewController is HealthCheckViewController)
    }

    func testHealthViewControllerUploadReportPresentsExpectedEntryPoint() throws {
        let controller = HealthViewController()
        _ = host(controller)

        controller.uploadReportTapped()
        pumpRunLoop()

        if Config.useRelay {
            let nav = controller.presentedViewController as? UINavigationController
            XCTAssertTrue(nav?.topViewController is LoginViewController)
        } else {
            let sheet = controller.presentedViewController as? UIAlertController
            XCTAssertEqual(sheet?.preferredStyle, .actionSheet)
            XCTAssertEqual(sheet?.title, t(.healthProfileUploadReport))
        }
    }

    func testHealthViewControllerSyncNowPresentsIdleAlertWhenNothingToSync() {
        let controller = HealthViewController()
        _ = host(controller)

        controller.syncNowTapped()
        pumpRunLoop()

        let alert = controller.presentedViewController as? UIAlertController
        XCTAssertEqual(alert?.preferredStyle, .alert)
        XCTAssertEqual(alert?.message, t(.syncStatusIdle))
    }

    func testMyDevicesViewControllerScanPushesDiscoveryScreen() {
        let controller = MyDevicesViewController()
        let nav = host(controller)

        _ = controller.perform(NSSelectorFromString("scanTapped"))
        pumpRunLoop()

        XCTAssertTrue(nav.topViewController is DeviceDiscoveryViewController)
    }

    func testProfileAccountCardPushesFamilyProfiles() {
        let controller = ProfileViewController()
        let nav = host(controller)

        _ = controller.perform(NSSelectorFromString("accountCardTapped"))
        pumpRunLoop()

        XCTAssertTrue(nav.topViewController is FamilyProfilesViewController)
    }

    func testProfileLogoutPresentsConfirmationAlert() {
        let controller = ProfileViewController()
        _ = host(controller)

        _ = controller.perform(NSSelectorFromString("logoutTapped"))
        pumpRunLoop()

        let alert = controller.presentedViewController as? UIAlertController
        XCTAssertEqual(alert?.title, t(.profileLogoutConfirmTitle))
        XCTAssertEqual(alert?.message, t(.profileLogoutConfirmMessage))
    }

    func testProfileLanguageRowPresentsLanguagePicker() {
        let controller = ProfileViewController()
        _ = host(controller)

        _ = controller.perform(NSSelectorFromString("showLanguagePicker"))
        pumpRunLoop()

        let alert = controller.presentedViewController as? UIAlertController
        XCTAssertEqual(alert?.preferredStyle, .actionSheet)
        XCTAssertEqual(alert?.title, t(.profileLanguage))
        XCTAssertEqual(alert?.actions.count, AppLanguage.allCases.count + 1)
        XCTAssertEqual(
            alert?.actions.dropLast().compactMap(\.title),
            AppLanguage.allCases.map(\.localizedDisplayName)
        )
    }

    func testProfileThemeRowPresentsThemePicker() {
        let controller = ProfileViewController()
        _ = host(controller)

        let button = try! XCTUnwrap(controller.view.recursiveSubviews
            .compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "profile-row-\(t(.profileTheme))" })
        button.sendActions(for: .touchUpInside)
        pumpRunLoop()

        let alert = controller.presentedViewController as? UIAlertController
        XCTAssertEqual(alert?.preferredStyle, .actionSheet)
        XCTAssertEqual(alert?.title, t(.profileTheme))
    }

    @discardableResult
    private func host(_ controller: UIViewController) -> UINavigationController {
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
        return nav
    }
}

@MainActor
final class LocalizationContractTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        LocaleManager.shared.setLanguage(.zh)
        super.tearDown()
    }

    func testAppLanguageCatalogIncludesPlannedLocales() {
        XCTAssertEqual(
            AppLanguage.allCases.map(\.rawValue),
            ["en", "zh", "ar", "es", "fr", "id", "th"]
        )
    }

    func testArabicUsesRTLButEnglishUsesLTR() {
        LocaleManager.shared.setLanguage(.ar)
        XCTAssertTrue(LocaleManager.shared.isRTL)
        XCTAssertEqual(LocaleManager.shared.currentSemanticContentAttribute, .forceRightToLeft)

        LocaleManager.shared.setLanguage(.en)
        XCTAssertFalse(LocaleManager.shared.isRTL)
        XCTAssertEqual(LocaleManager.shared.currentSemanticContentAttribute, .forceLeftToRight)
    }

    func testLanguagePickerUsesNativeDisplayNames() {
        XCTAssertEqual(AppLanguage.es.localizedDisplayName, "Español")
        XCTAssertEqual(AppLanguage.fr.localizedDisplayName, "Français")
        XCTAssertEqual(AppLanguage.id.localizedDisplayName, "Bahasa Indonesia")
        XCTAssertEqual(AppLanguage.th.localizedDisplayName, "ไทย")
    }

    func testCoreProfileTitleHasLocalizedCoverageForNewLanguages() {
        XCTAssertEqual(L10n.string(for: .profileTitle, language: .es), "Perfil")
        XCTAssertEqual(L10n.string(for: .profileTitle, language: .fr), "Profil")
        XCTAssertEqual(L10n.string(for: .profileTitle, language: .id), "Profil")
        XCTAssertEqual(L10n.string(for: .profileTitle, language: .th), "โปรไฟล์")
    }

    func testArabicHostedProfilePageUsesRTLWindowSemantic() {
        LocaleManager.shared.setLanguage(.ar)
        let controller = ProfileViewController()
        let window = host(controller)

        XCTAssertEqual(window.semanticContentAttribute, .forceRightToLeft)
    }

    func testArabicWelcomeHeroUsesDirectionalControls() {
        LocaleManager.shared.setLanguage(.ar)
        let hero = SymptomChatWelcomeHeroView(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
        hero.refreshLocalization()
        hero.layoutIfNeeded()

        let buttons = hero.recursiveSubviews
            .compactMap { $0 as? UIButton }
            .filter { ($0.title(for: .normal) ?? "").isEmpty == false }
        XCTAssertFalse(buttons.isEmpty)
        XCTAssertTrue(buttons.allSatisfy { $0.contentHorizontalAlignment == .right })
        XCTAssertTrue(buttons.allSatisfy { $0.semanticContentAttribute == .forceRightToLeft })
    }

    @discardableResult
    private func host(_ controller: UIViewController) -> UIWindow {
        let nav = UINavigationController(rootViewController: controller)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = nav
        window.makeKeyAndVisible()
        LocaleManager.shared.apply(to: window)
        self.window = window
        nav.loadViewIfNeeded()
        controller.loadViewIfNeeded()
        nav.view.layoutIfNeeded()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        return window
    }
}
