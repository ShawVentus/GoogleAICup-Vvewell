import UIKit

final class MainTabBarController: UITabBarController {

    enum Tab: Int {
        case home = 0
        case health = 1
        case chat = 2
        case medical = 3
        case profile = 4
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
        updateTabTitles()
        NotificationCenter.default.addObserver(
            self, selector: #selector(languageChanged),
            name: .appLanguageDidChange, object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupTabs() {
        let homeVC = UINavigationController(rootViewController: MainViewController())
        homeVC.tabBarItem = UITabBarItem(
            title: t(.tabHome),
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )

        let healthVC = UINavigationController(rootViewController: HealthViewController())
        healthVC.tabBarItem = UITabBarItem(
            title: t(.tabHealth),
            image: UIImage(systemName: "heart"),
            selectedImage: UIImage(systemName: "heart.fill")
        )

        let chat = SymptomChatViewController(initialMessage: nil)
        chat.topicSelectorEnabled = true
        let chatVC = UINavigationController(rootViewController: chat)
        chatVC.tabBarItem = UITabBarItem(
            title: t(.tabChat),
            image: UIImage(systemName: "message"),
            selectedImage: UIImage(systemName: "message.fill")
        )

        let medicalVC = UINavigationController(rootViewController: MedicalHubViewController())
        medicalVC.tabBarItem = UITabBarItem(
            title: t(.tabServices),
            image: UIImage(systemName: "cross.case"),
            selectedImage: UIImage(systemName: "cross.case.fill")
        )

        let profileVC = UINavigationController(rootViewController: ProfileViewController())
        profileVC.tabBarItem = UITabBarItem(
            title: t(.tabProfile),
            image: UIImage(systemName: "person"),
            selectedImage: UIImage(systemName: "person.fill")
        )

        viewControllers = [homeVC, healthVC, chatVC, medicalVC, profileVC]
    }

    private func setupAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppDesign.Surface.elevatedCard
        appearance.shadowColor = AppDesign.Surface.border
        let normal = appearance.stackedLayoutAppearance.normal
        normal.iconColor = UIColor(red: 113 / 255, green: 139 / 255, blue: 135 / 255, alpha: 1)
        normal.titleTextAttributes = [
            .foregroundColor: UIColor(red: 113 / 255, green: 139 / 255, blue: 135 / 255, alpha: 1),
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
        ]
        let selected = appearance.stackedLayoutAppearance.selected
        selected.iconColor = AppDesign.Color.primaryGreen
        selected.titleTextAttributes = [
            .foregroundColor: AppDesign.Color.darkTeal,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
        ]
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = AppDesign.Color.primaryGreen
        tabBar.unselectedItemTintColor = normal.iconColor
        tabBar.itemPositioning = .fill
        tabBar.selectionIndicatorImage = makeSelectionIndicator()
    }

    private func makeSelectionIndicator() -> UIImage? {
        let size = CGSize(width: max(54, view.bounds.width / 5 - 18), height: 34)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 231 / 255, green: 246 / 255, blue: 243 / 255, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 17).fill()
        }.resizableImage(withCapInsets: UIEdgeInsets(top: 16, left: 26, bottom: 16, right: 26))
    }

    /// 根据当前语言刷新所有 Tab 标题
    private func updateTabTitles() {
        let keys: [L10nKey] = [.tabHome, .tabHealth, .tabChat, .tabServices, .tabProfile]
        viewControllers?.enumerated().forEach { index, vc in
            guard index < keys.count else { return }
            vc.tabBarItem.title = t(keys[index])
        }
    }

    @objc private func languageChanged() {
        updateTabTitles()
    }

    func openChatTab(prefillText: String?) {
        selectedIndex = Tab.chat.rawValue
        guard let nav = viewControllers?[Tab.chat.rawValue] as? UINavigationController else { return }
        nav.popToRootViewController(animated: false)
        guard let chatVC = nav.viewControllers.first as? SymptomChatViewController else { return }
        chatVC.setDraftMessage(prefillText)
    }

    func openHealthTab() {
        selectedIndex = Tab.health.rawValue
    }
}
