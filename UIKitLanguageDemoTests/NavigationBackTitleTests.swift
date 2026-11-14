import XCTest
import UIKit
@testable import UIKitLanguageDemo

final class NavigationBackTitleTests: XCTestCase {
    @MainActor
    func testRestoredUnloadedPredecessorsRefreshBackTitlesWithoutLoadingViews() throws {
        let service = LanguageService.shared
        let original = service.selection
        service.setSelection(.simplifiedChinese)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let state = SavedSceneState(stacks: [
            [SavedPageState(route: .home), SavedPageState(route: .detail, draft: "middle draft"),
             SavedPageState(route: .detail, draft: "visible draft")],
            [SavedPageState(route: .settings)]
        ])
        let coordinator = SceneStateCoordinator()
        coordinator.connect(window: window, activity: SceneStateCodec.activity(for: state))
        defer {
            service.unregister(window: window)
            window.isHidden = true
            service.setSelection(original)
            previous?.makeKeyAndVisible()
        }
        let navigation = coordinator.tabs.navigationControllers[0]
        let root = try XCTUnwrap(navigation.viewControllers.first)
        let detail = try XCTUnwrap(navigation.topViewController as? DetailViewController)
        XCTAssertFalse(root.isViewLoaded, "Restoring directly into Detail should not load Home")
        let identities = navigation.viewControllers.map(ObjectIdentifier.init)
        for selection in [LanguageSelection.english, .arabic, .simplifiedChinese, .english] {
            service.setSelection(selection)
            window.layoutIfNeeded()
            for page in navigation.viewControllers {
                XCTAssertEqual(page.navigationItem.backButtonTitle, service.context.text(.commonBack))
            }
            XCTAssertFalse(root.isViewLoaded, "Updating navigation metadata must not load predecessor views")
            XCTAssertEqual(navigation.viewControllers.map(ObjectIdentifier.init), identities)
            XCTAssertEqual(detail.draftField.text, "visible draft")
        }
        let pushed = DetailViewController()
        navigation.pushViewController(pushed, animated: false)
        XCTAssertEqual(pushed.navigationItem.backButtonTitle, "Back")
        service.setSelection(.arabic)
        XCTAssertEqual(detail.navigationItem.backButtonTitle, "رجوع")
        let replacement = UIViewController()
        navigation.setViewControllers([replacement, pushed], animated: false)
        XCTAssertEqual(replacement.navigationItem.backButtonTitle, "رجوع")
        XCTAssertFalse(replacement.isViewLoaded)
    }
}
