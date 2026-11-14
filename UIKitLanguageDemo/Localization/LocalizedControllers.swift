import UIKit

@MainActor
protocol LocalizationUpdatable: AnyObject {
    func applyLocalization(_ context: LanguageContext)
}

@MainActor
class LocalizedViewController: UIViewController, LocalizationUpdatable {
    private var renderedRevision = -1

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // Set up controls before the first localization pass.
        buildUI()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged),
                                              name: .appLanguageDidChange, object: LanguageService.shared)
        refreshIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Observe the demo's business columns without replacing the split delegate.
        // This also records the native compact Back gesture returning to primary.
        (splitViewController as? LocalizedSplitViewController)?.recordVisibleBusinessPage(self)
    }

    @objc private func openSystemSettings() { SystemLanguageSettings.open(from: self) }

    @objc private func showWindows() { SceneWindowService.presentSwitcher(from: self) }

    func buildUI() {}
    func applyLocalization(_ context: LanguageContext) {}

    @objc private func languageChanged() { refreshIfNeeded() }

    private func refreshIfNeeded() {
        guard isViewLoaded else { return }
        let context = LanguageService.shared.context
        guard context.revision != renderedRevision else { return }
        renderedRevision = context.revision
        if navigationItem.rightBarButtonItem == nil {
            let item = UIBarButtonItem(image: UIImage(systemName: "globe"), style: .plain,
                target: self, action: #selector(openSystemSettings))
            item.accessibilityIdentifier = "system.language.settings"
            item.accessibilityLabel = context.text(.systemSettings)
            navigationItem.rightBarButtonItem = item
        }
        if navigationItem.rightBarButtonItem?.accessibilityIdentifier == "system.language.settings" {
            navigationItem.rightBarButtonItem?.accessibilityLabel = context.text(.systemSettings)
        }
        if navigationItem.rightBarButtonItems?.contains(where: { $0.accessibilityIdentifier == "scene.windows" }) != true {
            let windows = UIBarButtonItem(image: UIImage(systemName: "macwindow.on.rectangle"), style: .plain,
                target: self, action: #selector(showWindows))
            windows.accessibilityIdentifier = "scene.windows"
            windows.accessibilityLabel = context.text(.windowMenu)
            navigationItem.rightBarButtonItems = (navigationItem.rightBarButtonItems ?? []) + [windows]
        }
        navigationItem.rightBarButtonItems?.first(where: { $0.accessibilityIdentifier == "scene.windows" })?.accessibilityLabel = context.text(.windowMenu)
        LayoutDirection.applyBoundary(context, to: view)
        applyLocalization(context)
        view.setNeedsLayout()
    }
    // Selector-based NotificationCenter observers are automatically cleaned up
    // on deallocation on the supported OS versions (no closure retain cycle).
}

@MainActor
final class LocalizedNavigationController: UINavigationController {
    let tabTitle: AppText

    init(root: UIViewController, tabTitle: AppText, symbol: String) {
        self.tabTitle = tabTitle
        super.init(rootViewController: root)
        tabBarItem.image = UIImage(systemName: symbol)
        tabBarItem.title = LanguageService.shared.context.text(tabTitle)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                              name: .appLanguageDidChange, object: LanguageService.shared)
    }
    required init?(coder: NSCoder) { fatalError("Use init(root:tabTitle:symbol:)") }

    override func viewDidLoad() { super.viewDidLoad(); refresh() }

    @objc private func refresh() {
        let context = LanguageService.shared.context
        // iOS 18+ titles belong to the stable UITab models in LocalizedTabBarController.
        // A retired navigation controller can outlive UIKit's tab view during scene restoration;
        // updating that bridged legacy item can dereference a released UIKit view provider.
        if #unavailable(iOS 18.0) { tabBarItem.title = context.text(tabTitle) }
        guard isViewLoaded else { return }
        LayoutDirection.applyBoundary(context, to: view)
        LayoutDirection.applyBoundary(context, to: navigationBar)
        LayoutDirection.applyBoundary(context, to: toolbar)
        navigationBar.setNeedsLayout()
    }

    override var childForStatusBarStyle: UIViewController? { topViewController }
    override var childForStatusBarHidden: UIViewController? { topViewController }
}

@MainActor
final class LocalizedTabBarController: UITabBarController {
    let navigationControllers: [LocalizedNavigationController]

    init(navigationControllers: [LocalizedNavigationController]) {
        self.navigationControllers = navigationControllers
        super.init(nibName: nil, bundle: nil)
        if #available(iOS 18.0, *) {
            // Keep stable UITab objects too. Updating only tabBarItem can leave
            // the new tab/sidebar model with an old title on recent systems.
            tabs = navigationControllers.map { navigation in
                UITab(title: LanguageService.shared.context.text(navigation.tabTitle),
                      image: navigation.tabBarItem.image,
                      identifier: navigation.tabTitle.catalogKey) { _ in navigation }
            }
        } else {
            viewControllers = navigationControllers
        }
    }
    required init?(coder: NSCoder) { fatalError("Use init(navigationControllers:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                              name: .appLanguageDidChange, object: LanguageService.shared)
        refresh()
    }

    @objc private func refresh() {
        let context = LanguageService.shared.context
        if #available(iOS 18.0, *) {
            for (tab, navigation) in zip(tabs, navigationControllers) {
                tab.title = context.text(navigation.tabTitle)
            }
        }
        LayoutDirection.applyBoundary(context, to: view)
        LayoutDirection.applyBoundary(context, to: tabBar)
        tabBar.setNeedsLayout()
    }
}
