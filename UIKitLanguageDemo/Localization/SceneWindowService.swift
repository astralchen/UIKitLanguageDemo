import UIKit

@MainActor
enum SceneWindowService {
    static func allocateWindowNumber() -> Int {
        let defaults = UserDefaults.standard
        let value = min(999_999, max(0, defaults.integer(forKey: "scene.nextWindowNumber"))) + 1
        defaults.set(value, forKey: "scene.nextWindowNumber")
        return value
    }
    static func checkpointAll() {
        for scene in UIApplication.shared.connectedScenes {
            (scene.delegate as? SceneDelegate)?.checkpoint(scene)
        }
    }
    static func requestNewWindow(copying state: SavedSceneState, onError: ((Error) -> Void)? = nil) {
        guard UIApplication.shared.supportsMultipleScenes,
              let activity = SceneStateCodec.activation(for: state) else { return }
        checkpointAll()
        if #available(iOS 17.0, *) {
            UIApplication.shared.activateSceneSession(for: UISceneSessionActivationRequest(role: .windowApplication, userActivity: activity), errorHandler: onError)
        } else {
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil, errorHandler: onError)
        }
    }
    static func activate(_ session: UISceneSession) {
        checkpointAll()
        if #available(iOS 17.0, *) {
            UIApplication.shared.activateSceneSession(for: UISceneSessionActivationRequest(session: session))
        } else { UIApplication.shared.requestSceneSessionActivation(session, userActivity: nil, options: nil) }
    }
    static func presentSwitcher(from controller: UIViewController) {
        guard let scene = controller.view.window?.windowScene,
              let delegate = scene.delegate as? SceneDelegate else { return }
        let context = LanguageService.shared.context
        let sheet = UIAlertController(title: context.text(.windowMenu), message: nil, preferredStyle: .actionSheet)
        let sessions = UIApplication.shared.openSessions.sorted { ($0.userInfo?["windowNumber"] as? Int ?? 0) < ($1.userInfo?["windowNumber"] as? Int ?? 0) }
        if UIApplication.shared.supportsMultipleScenes {
            sheet.addAction(UIAlertAction(title: context.text(.windowNew), style: .default) { [weak delegate] _ in
                guard let state = delegate?.restoration.capture() else { return }
                requestNewWindow(copying: state) { error in NSLog("Window activation failed: %@", String(describing: error)) }
            })
        }
        for other in sessions where other.persistentIdentifier != scene.session.persistentIdentifier {
            let number = other.userInfo?["windowNumber"] as? Int
                ?? other.stateRestorationActivity.flatMap(SceneStateCodec.decode)?.windowNumber ?? 0
            sheet.addAction(UIAlertAction(title: context.text(.windowName(Int32(clamping: number))), style: .default) { _ in activate(other) })
        }
        if sessions.count > 1 {
            sheet.addAction(UIAlertAction(title: context.text(.windowClose), style: .destructive) { _ in
                if let other = sessions.first(where: { $0.persistentIdentifier != scene.session.persistentIdentifier }) { activate(other) }
                UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil) { error in NSLog("Window close failed: %@", String(describing: error)) }
            })
        }
        sheet.addAction(UIAlertAction(title: context.text(.commonClose), style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = controller.navigationItem.rightBarButtonItems?.first(where: { $0.accessibilityIdentifier == "scene.windows" })
        controller.present(sheet, animated: true)
    }
}
