import XCTest
import UIKit
@testable import UIKitLanguageDemo

final class NavigationDirectionTests: XCTestCase {
    @MainActor
    func testHotSwitchUpdatesNavigationSemanticsAndPreservesSystemGestures() throws {
        let service = LanguageService.shared
        let original = service.selection
        service.setSelection(.english)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let navigation = LocalizedNavigationController(root: HomeViewController(), tabTitle: .homeTitle, symbol: "house")
        window.rootViewController = LocalizationHostController(content: navigation)
        service.register(window: window)
        window.makeKeyAndVisible()
        let detail = DetailViewController()
        navigation.pushViewController(detail, animated: false)
        window.layoutIfNeeded()
        detail.draftField.text = "Keep draft during direction change"
        let ltrException = UIView(); ltrException.semanticContentAttribute = .forceLeftToRight
        detail.view.addSubview(ltrException)
        let recognizer = try XCTUnwrap(navigation.interactivePopGestureRecognizer)
        let originalDelegate = recognizer.delegate
        let stack = navigation.viewControllers.map(ObjectIdentifier.init)
        let contentRecognizer: UIGestureRecognizer?
        if #available(iOS 26.0, *) { contentRecognizer = navigation.interactiveContentPopGestureRecognizer }
        else { contentRecognizer = nil }
        defer {
            service.unregister(window: window); window.isHidden = true
            service.setSelection(original); previous?.makeKeyAndVisible()
        }
        for selection in [LanguageSelection.arabic, .simplifiedChinese, .english, .arabic] {
            service.setSelection(selection)
            window.layoutIfNeeded()
            let rtl = service.context.isRTL
            let semantic: UISemanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            XCTAssertEqual(navigation.view.semanticContentAttribute, semantic)
            XCTAssertEqual(navigation.navigationBar.semanticContentAttribute, semantic)
            XCTAssertEqual(navigation.toolbar.semanticContentAttribute, semantic)
            XCTAssertEqual(navigation.view.effectiveUserInterfaceLayoutDirection, rtl ? .rightToLeft : .leftToRight)
            XCTAssertTrue(navigation.interactivePopGestureRecognizer === recognizer)
            XCTAssertTrue(recognizer.delegate === originalDelegate)
            if #available(iOS 26.0, *) { XCTAssertTrue(navigation.interactiveContentPopGestureRecognizer === contentRecognizer) }
            XCTAssertEqual(navigation.viewControllers.map(ObjectIdentifier.init), stack)
            XCTAssertEqual(detail.draftField.text, "Keep draft during direction change")
            XCTAssertEqual(ltrException.semanticContentAttribute, .forceLeftToRight)
        }
    }
}
