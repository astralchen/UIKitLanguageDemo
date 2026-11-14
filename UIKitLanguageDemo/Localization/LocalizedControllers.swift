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
        if let split = splitViewController as? LocalizedSplitViewController, split.isCollapsed {
            if navigationController === split.restorationPrimary { split.restorationShowsSecondary = false }
            if navigationController === split.restorationSecondary { split.restorationShowsSecondary = true }
        }
    }

    @objc private func openSystemSettings() { SystemLanguageSettings.open(from: self) }

    func buildUI() {}
    func applyLocalization(_ context: LanguageContext) {}

    @objc private func languageChanged() { refreshIfNeeded() }

    private func refreshIfNeeded() {
        guard isViewLoaded else { return }
        let context = LanguageService.shared.context
        guard context.revision != renderedRevision else { return }
        renderedRevision = context.revision
        if navigationItem.rightBarButtonItem == nil {
            let item = UIBarButtonItem(title: context.text("system.settings"), style: .plain,
                target: self, action: #selector(openSystemSettings))
            item.accessibilityIdentifier = "system.language.settings"
            navigationItem.rightBarButtonItem = item
        }
        if navigationItem.rightBarButtonItem?.accessibilityIdentifier == "system.language.settings" {
            navigationItem.rightBarButtonItem?.title = context.text("system.settings")
        }
        LayoutDirection.applyBoundary(context, to: view)
        applyLocalization(context)
        view.setNeedsLayout()
    }
    // Selector-based NotificationCenter observers are automatically cleaned up
    // on deallocation on the supported OS versions (no closure retain cycle).
}

@MainActor
final class LocalizedNavigationController: UINavigationController {
    let tabTitleKey: String

    init(root: UIViewController, tabTitleKey: String, symbol: String) {
        self.tabTitleKey = tabTitleKey
        super.init(rootViewController: root)
        tabBarItem.image = UIImage(systemName: symbol)
        tabBarItem.title = LanguageService.shared.context.text(tabTitleKey)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                              name: .appLanguageDidChange, object: LanguageService.shared)
    }
    required init?(coder: NSCoder) { fatalError("Use init(root:tabTitleKey:symbol:)") }

    override func viewDidLoad() { super.viewDidLoad(); refresh() }

    @objc private func refresh() {
        let context = LanguageService.shared.context
        tabBarItem.title = context.text(tabTitleKey)
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
                UITab(title: LanguageService.shared.context.text(navigation.tabTitleKey),
                      image: navigation.tabBarItem.image,
                      identifier: navigation.tabTitleKey) { _ in navigation }
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
            for tab in tabs { tab.title = context.text(tab.identifier) }
        }
        LayoutDirection.applyBoundary(context, to: view)
        LayoutDirection.applyBoundary(context, to: tabBar)
        tabBar.setNeedsLayout()
    }
}
