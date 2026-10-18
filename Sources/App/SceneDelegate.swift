import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        ThemeManager.shared.loadSavedTheme()
        let window = UIWindow(windowScene: windowScene)
        LocaleManager.shared.apply(to: window)
        window.rootViewController = LaunchViewController()
        window.enableGlobalKeyboardDismissOnTap()
        GlobalKeyboardHandler.shared.start(for: window)
        self.window = window
        ThemeManager.shared.apply(to: window)
        window.makeKeyAndVisible()
    }
}
