import UIKit

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let restoration = SceneStateCoordinator()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        self.window = window
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-UITestResetRestoration"), index + 1 < arguments.count,
           UserDefaults.standard.string(forKey: "UITest.lastResetToken") != arguments[index + 1] {
            UserDefaults.standard.set(arguments[index + 1], forKey: "UITest.lastResetToken")
            SceneCheckpointStore.shared.remove(sceneID: session.persistentIdentifier)
            session.stateRestorationActivity = nil
            UserDefaults.standard.removeObject(forKey: "app.language.selection")
            LanguageService.shared.setSelection(.system)
        }
        #endif
        // Each Scene owns independent state; no UI language or translated string is restored.
        restoration.connect(window: window, activity: session.stateRestorationActivity,
            fallback: SceneCheckpointStore.shared.load(sceneID: session.persistentIdentifier))
    }

    @discardableResult
    func checkpoint(_ scene: UIScene) -> NSUserActivity? {
        guard let activity = restoration.activity() else { return nil }
        scene.userActivity = activity
        scene.session.stateRestorationActivity = activity
        SceneCheckpointStore.shared.save(activity, sceneID: scene.session.persistentIdentifier)
        return activity
    }
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? { checkpoint(scene) }
    func scene(_ scene: UIScene, restoreInteractionStateWith stateRestorationActivity: NSUserActivity) {
        restoration.restoreInteractionState(stateRestorationActivity)
    }
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        restoration.restoreInteractionState(userActivity)
    }
    func sceneWillResignActive(_ scene: UIScene) { checkpoint(scene) }
    func sceneDidEnterBackground(_ scene: UIScene) { checkpoint(scene) }
    func sceneDidDisconnect(_ scene: UIScene) {
        checkpoint(scene)
        if let window { LanguageService.shared.unregister(window: window) }
    }
    func sceneWillEnterForeground(_ scene: UIScene) {
        if let window { LanguageService.shared.register(window: window) }
    }
}
