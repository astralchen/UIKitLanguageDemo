import XCTest
import UIKit
@testable import UIKitLanguageDemo

final class AppearanceTests: XCTestCase {
    @MainActor
    func testSavedChoiceSyncsRegisteredAndLateWindowsWithoutChangingNavigation() async throws {
        let fixture = try AppearanceWindowFixture()
        defer { fixture.close() }
        let service = fixture.service
        let root = HomeViewController()
        let navigation = LocalizedNavigationController(root: root, tabTitle: .homeTitle, symbol: "house")
        fixture.first.rootViewController = LocalizationHostController(content: navigation)
        fixture.first.makeKeyAndVisible()
        let detail = DetailViewController()
        navigation.pushViewController(detail, animated: false)
        detail.draftField.text = "Keep عربي draft"
        let identities = navigation.viewControllers.map(ObjectIdentifier.init)
        let originalLanguage = LanguageService.shared.selection
        defer { LanguageService.shared.setSelection(originalLanguage) }
        LanguageService.shared.register(window: fixture.first)
        defer { LanguageService.shared.unregister(window: fixture.first) }
        for choice in [AppearanceSelection.dark, .light, .system, .dark] {
            service.setSelection(choice)
            await Task.yield()
            fixture.first.layoutIfNeeded(); fixture.second.layoutIfNeeded()
            XCTAssertEqual(fixture.first.overrideUserInterfaceStyle, choice.style)
            XCTAssertEqual(fixture.second.overrideUserInterfaceStyle, choice.style)
            if choice != .system {
                XCTAssertEqual(detail.traitCollection.userInterfaceStyle, choice.style)
            }
            XCTAssertEqual(navigation.viewControllers.map(ObjectIdentifier.init), identities)
            XCTAssertEqual(detail.draftField.text, "Keep عربي draft")
            XCTAssertEqual(LanguageService.shared.selection, originalLanguage)
        }
        LanguageService.shared.setSelection(.arabic)
        XCTAssertEqual(fixture.first.overrideUserInterfaceStyle, .dark)
        service.setSelection(.light)
        XCTAssertEqual(LanguageService.shared.selection, .arabic)
        XCTAssertEqual(navigation.view.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        let late = UIWindow(windowScene: fixture.scene)
        service.register(window: late)
        XCTAssertEqual(late.overrideUserInterfaceStyle, .light)
        let relaunchedService = AppearanceService(defaults: fixture.defaults)
        XCTAssertEqual(relaunchedService.selection, .light)
        relaunchedService.register(window: late)
        XCTAssertEqual(late.overrideUserInterfaceStyle, .light)
        service.unregister(window: fixture.second)
        service.setSelection(.dark)
        XCTAssertEqual(fixture.first.overrideUserInterfaceStyle, .dark)
        XCTAssertEqual(fixture.second.overrideUserInterfaceStyle, .light)
        late.isHidden = true
    }

    @MainActor
    func testSystemChoiceTracksInheritedAppearanceAndExplicitChoiceOverridesIt() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Controlled Scene trait simulation requires iOS 17+") }
        let fixture = try AppearanceWindowFixture()
        let scene = fixture.scene
        let hadOverride = scene.traitOverrides.contains(UITraitUserInterfaceStyle.self)
        let previous = hadOverride ? scene.traitOverrides.userInterfaceStyle : .unspecified
        defer {
            if hadOverride { scene.traitOverrides.userInterfaceStyle = previous }
            else { scene.traitOverrides.remove(UITraitUserInterfaceStyle.self) }
            fixture.close()
        }
        for inherited in [UIUserInterfaceStyle.light, .dark, .light] {
            scene.traitOverrides.userInterfaceStyle = inherited
            fixture.service.setSelection(.system)
            fixture.first.layoutIfNeeded()
            XCTAssertEqual(fixture.first.overrideUserInterfaceStyle, .unspecified)
            XCTAssertEqual(fixture.first.rootViewController?.traitCollection.userInterfaceStyle, inherited)
            fixture.service.setSelection(inherited == .light ? .dark : .light)
            fixture.first.layoutIfNeeded()
            XCTAssertNotEqual(fixture.first.rootViewController?.traitCollection.userInterfaceStyle, inherited)
            fixture.service.setSelection(.system)
            fixture.first.layoutIfNeeded()
            XCTAssertEqual(fixture.first.rootViewController?.traitCollection.userInterfaceStyle, inherited)
        }
        XCTAssertEqual(AppearanceService(defaults: fixture.defaults).selection, .system)
    }

    @MainActor
    func testSelectedCollectionBorderResolvesAgainWhenAppearanceChanges() async throws {
        let fixture = try AppearanceWindowFixture()
        defer { fixture.close() }
        let cell = DemoCollectionCell(frame: CGRect(x: 0, y: 0, width: 250, height: 180))
        fixture.first.rootViewController!.view.addSubview(cell)
        cell.isSelected = true
        var colors: [[CGFloat]] = []
        for choice in [AppearanceSelection.light, .dark, .light] {
            fixture.service.setSelection(choice)
            await Task.yield()
            fixture.first.layoutIfNeeded()
            XCTAssertEqual(cell.traitCollection.userInterfaceStyle, choice.style)
            let actual = try XCTUnwrap(cell.contentView.layer.borderColor)
            let expected = UIColor.systemBlue.resolvedColor(with: cell.traitCollection).cgColor
            XCTAssertEqual(actual.components, expected.components)
            XCTAssertEqual(cell.contentView.layer.borderWidth, 2)
            colors.append(try XCTUnwrap(actual.components))
        }
        XCTAssertNotEqual(colors[0], colors[1])
        XCTAssertEqual(colors[0], colors[2])
    }
    @MainActor
    func testMultiplePickersAndRenderedTabsStaySynchronized() throws {
        let fixture = try AppearanceWindowFixture()
        let service = AppearanceService.shared
        let originalAppearance = service.selection
        let language = LanguageService.shared
        let originalLanguage = language.selection
        defer {
            service.setSelection(originalAppearance)
            language.unregister(window: fixture.first)
            language.setSelection(originalLanguage)
            fixture.close()
        }
        let pickers = [AppearancePickerView(), AppearancePickerView()]
        func descendants(_ view: UIView) -> [UIView] {
            view.subviews.flatMap { [$0] + descendants($0) }
        }
        let controls = try pickers.map { picker in
            try XCTUnwrap(descendants(picker).compactMap { $0 as? UISegmentedControl }.first)
        }
        for choice in [AppearanceSelection.light, .dark, .system] {
            service.setSelection(choice)
            for control in controls {
                XCTAssertEqual(control.selectedSegmentIndex, AppearanceSelection.allCases.firstIndex(of: choice))
            }
        }
        let tabs = LocalizedTabBarController(navigationControllers: [
            LocalizedNavigationController(root: HomeViewController(), tabTitle: .homeTitle, symbol: "house"),
            LocalizedNavigationController(root: SettingsViewController(), tabTitle: .settingsTitle, symbol: "gearshape")
        ])
        fixture.first.rootViewController = LocalizationHostController(content: tabs)
        language.register(window: fixture.first)
        fixture.first.makeKeyAndVisible()
        fixture.first.layoutIfNeeded()
        for choice in [LanguageSelection.english, .arabic, .simplifiedChinese] {
            language.setSelection(choice)
            fixture.first.layoutIfNeeded()
            XCTAssertEqual(tabs.tabBar.items?.map { $0.title ?? "" },
                [language.context.text(.homeTitle), language.context.text(.settingsTitle)])
        }
    }

}

@MainActor
private final class AppearanceWindowFixture {
    let scene: UIWindowScene
    let first: UIWindow
    let second: UIWindow
    let service: AppearanceService
    let defaults: UserDefaults
    private let suite = "appearance.tests." + UUID().uuidString
    private let previous: UIWindow?
    init() throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        previous = scene.windows.first { $0.isKeyWindow }
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        service = AppearanceService(defaults: defaults)
        first = UIWindow(windowScene: scene)
        second = UIWindow(windowScene: scene)
        for window in [first, second] {
            let root = UIViewController()
            root.view.backgroundColor = .systemBackground
            window.rootViewController = root
            service.register(window: window)
            window.isHidden = false
        }
        first.makeKeyAndVisible()
    }
    func close() {
        for window in [first, second] { service.unregister(window: window); window.isHidden = true }
        defaults.removePersistentDomain(forName: suite)
        previous?.makeKeyAndVisible()
    }
}
