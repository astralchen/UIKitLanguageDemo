import UIKit

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        let tabs = LocalizedTabBarController(navigationControllers: [
            LocalizedNavigationController(root: HomeViewController(), tabTitleKey: "home.title", symbol: "house"),
            LocalizedNavigationController(root: SettingsViewController(), tabTitleKey: "settings.title", symbol: "gearshape")
        ])
        // Root assignment happens only at window creation, never during language changes.
        window.rootViewController = LocalizationHostController(content: tabs)
        self.window = window
        LanguageService.shared.register(window: window)
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if let window { LanguageService.shared.unregister(window: window) }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Re-register windows of reconnected scenes. Weak registration is idempotent.
        if let window { LanguageService.shared.register(window: window) }
    }
}
