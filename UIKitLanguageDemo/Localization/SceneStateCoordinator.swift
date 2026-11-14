import UIKit
import CryptoKit

/// Checkpoint fallback is isolated by UISceneSession.persistentIdentifier.
@MainActor
final class SceneCheckpointStore {
    static let shared = SceneCheckpointStore()
    private let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SceneCheckpoints", isDirectory: true)
    }
    private func url(_ sceneID: String) -> URL {
        let digest = SHA256.hash(data: Data(sceneID.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest).appendingPathExtension("json")
    }
    func save(_ activity: NSUserActivity, sceneID: String) {
        guard let state = SceneStateCodec.decode(activity),
              state.sceneSessionID == nil || state.sceneSessionID == sceneID,
              let data = activity.userInfo?[SceneStateCodec.payloadKey] as? Data else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url(sceneID), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { NSLog("Scene checkpoint save failed: %@", String(describing: error)) }
    }
    func load(sceneID: String) -> NSUserActivity? {
        guard let data = try? Data(contentsOf: url(sceneID)), let state = SceneStateCodec.decode(data),
              state.sceneSessionID == nil || state.sceneSessionID == sceneID else { return nil }
        return SceneStateCodec.activity(for: state)
    }
    func remove(sceneID: String) { try? FileManager.default.removeItem(at: url(sceneID)) }
}

@MainActor
final class SceneStateCoordinator {
    private(set) var tabs: LocalizedTabBarController!
    private(set) var appliedActivityID: String?
    private(set) var restorationOrigin = "fresh"
    private weak var window: UIWindow?
    private(set) var sceneSessionID: String?
    private(set) var windowNumber: Int?
    private var launchBaseline: SavedSceneState?

    func connect(window: UIWindow, activity: NSUserActivity?, fallback: NSUserActivity? = nil, sessionID: String? = nil, activation: NSUserActivity? = nil, number: Int? = nil) {
        self.window = window
        self.sceneSessionID = sessionID
        self.windowNumber = number
        if let state = activity.flatMap(ownedState) {
            install(state, in: window); appliedActivityID = state.identifier; restorationOrigin = "activity"
        } else if let state = fallback.flatMap(ownedState) {
            install(state, in: window); appliedActivityID = state.identifier; restorationOrigin = "checkpoint"
        } else if let state = activation.flatMap(SceneStateCodec.decodeActivation) {
            install(state, in: window); appliedActivityID = state.identifier; restorationOrigin = "activation"
        } else { install(nil, in: window) }
        launchBaseline = capture()
        window.accessibilityIdentifier = windowNumber.map { "scene.window.\($0)" } ?? "scene.window"
        window.accessibilityValue = "\(restorationOrigin)|\(LanguageService.shared.context.language.rawValue)"
    }

    /// Handles encrypted restoration data that UIKit delivers after connection.
    @discardableResult
    func restoreInteractionState(_ activity: NSUserActivity) -> Bool {
        guard let state = ownedState(activity), state.identifier != appliedActivityID,
              appliedActivityID == nil, let window,
              let baseline = launchBaseline, let current = capture(),
              current.stacks == baseline.stacks, current.selectedTab == baseline.selectedTab,
              current.split == baseline.split else { return false }
        install(state, in: window)
        appliedActivityID = state.identifier
        restorationOrigin = "activity"
        window.accessibilityValue = "activity|\(LanguageService.shared.context.language.rawValue)"
        return true
    }

    private func ownedState(_ activity: NSUserActivity) -> SavedSceneState? {
        guard let state = SceneStateCodec.decode(activity),
              state.sceneSessionID == nil || sceneSessionID == nil || state.sceneSessionID == sceneSessionID else { return nil }
        return state
    }

    func activity() -> NSUserActivity? { capture().flatMap(SceneStateCodec.activity) }

    func capture() -> SavedSceneState? {
        guard tabs != nil else { return nil }
        let stacks = tabs.navigationControllers.map { $0.viewControllers.compactMap(capturePage) }
        guard stacks.count == 2 else { return nil }
        let split = topPresentedSplit(from: tabs).flatMap { split -> SavedSplitState? in
            guard let primary = split.restorationPrimary, let secondary = split.restorationSecondary else { return nil }
            return SavedSplitState(primary: primary.viewControllers.compactMap(capturePage),
                secondary: secondary.viewControllers.compactMap(capturePage), showsSecondary: split.restorationShowsSecondary,
                style: split.style == .tripleColumn ? .tripleColumn : .doubleColumn,
                supplementary: split.restorationSupplementary?.viewControllers.compactMap(capturePage),
                compactColumn: split.restorationCompactColumn, expandedMode: split.restorationExpandedMode)
        }
        return SavedSceneState(sceneSessionID: sceneSessionID, windowNumber: windowNumber, selectedTab: tabs.selectedIndex, stacks: stacks, split: split)
    }

    private func topPresentedSplit(from controller: UIViewController) -> LocalizedSplitViewController? {
        if let split = controller as? LocalizedSplitViewController { return split }
        if let presented = controller.presentedViewController, let split = topPresentedSplit(from: presented) { return split }
        return controller.selectedOrVisibleChild.flatMap { topPresentedSplit(from: $0) }
    }

    private func capturePage(_ controller: UIViewController) -> SavedPageState? {
        var state: SavedPageState
        switch controller {
        case is HomeViewController: state = SavedPageState(route: .home)
        case let page as SettingsViewController: state = SavedPageState(route: .settings, list: ListStateRestoration.capture(page))
        case let page as DetailViewController: state = SavedPageState(route: .detail, draft: page.draftField.text ?? "")
        case let page as CollectionDemoViewController:
            state = SavedPageState(route: page.axis == .vertical ? .verticalCollection : .horizontalCollection, list: ListStateRestoration.capture(page))
        case let page as CompositionalDemoViewController:
            state = SavedPageState(route: page.mode == .grid ? .compositionalGrid : .compositionalCarousel, list: ListStateRestoration.capture(page))
        case let pager as LocalizedPageContainerController:
            state = SavedPageState(route: .pager, currentPageID: pager.currentPageID,
                pageDrafts: Dictionary(uniqueKeysWithValues: pager.restorationPages.compactMap { page in
                    (page.controller as? DemoPageViewController).map { (page.id, $0.draft.text ?? "") }
                }))
        case let menu as SplitMenuViewController:
            state = SavedPageState(route: menu.column == .supplementary ? .splitSupplementary : .splitMenu, draft: menu.draftField.text ?? "")
        default: return nil // UIKit's own collapse/transition controllers are never serialized.
        }
        return state
    }

    private func makePage(_ state: SavedPageState) -> UIViewController {
        let page: UIViewController
        switch state.route {
        case .home: page = HomeViewController()
        case .settings: page = SettingsViewController()
        case .detail:
            let detail = DetailViewController(); detail.draftField.text = state.draft; page = detail
        case .verticalCollection: page = CollectionDemoViewController()
        case .horizontalCollection: page = CollectionDemoViewController(axis: .horizontal)
        case .compositionalGrid: page = CompositionalDemoViewController()
        case .compositionalCarousel: page = CompositionalDemoViewController(mode: .orthogonal)
        case .pager:
            let pager = ContainerDemos.makePager(initialPageID: state.currentPageID ?? "page-2")
            for item in pager.restorationPages {
                (item.controller as? DemoPageViewController)?.draft.text = state.pageDrafts[item.id]
            }
            page = pager
        case .splitMenu, .splitSupplementary:
            let menu = SplitMenuViewController(column: state.route == .splitMenu ? .primary : .supplementary)
            menu.draftField.text = state.draft; page = menu
        }
        if let list = page as? any ListStateRestorable, let saved = state.list {
            list.restorationDrafts = saved.drafts
            list.pendingListState = saved
        }
        page.navigationItem.backButtonTitle = LanguageService.shared.context.text("common.back")
        return page
    }

    private func install(_ state: SavedSceneState?, in window: UIWindow) {
        if let number = state?.windowNumber, windowNumber == nil { windowNumber = number }
        let defaults = [[SavedPageState(route: .home)], [SavedPageState(route: .settings)]]
        let stacks = state?.stacks ?? defaults
        let navigations = stacks.enumerated().map { index, stack in
            let controllers = stack.map(makePage)
            let navigation = LocalizedNavigationController(root: controllers[0],
                tabTitleKey: index == 0 ? "home.title" : "settings.title", symbol: index == 0 ? "house" : "gearshape")
            navigation.setViewControllers(controllers, animated: false)
            return navigation
        }
        tabs = LocalizedTabBarController(navigationControllers: navigations)
        tabs.selectedIndex = state?.selectedTab ?? 0
        window.rootViewController = LocalizationHostController(content: tabs)
        LanguageService.shared.register(window: window)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        if let saved = state?.split {
            let split = ContainerDemos.makeSplit(style: saved.style == .tripleColumn ? .tripleColumn : .doubleColumn)
            split.restorationPrimary?.setViewControllers(saved.primary.map(makePage), animated: false)
            split.restorationSecondary?.setViewControllers(saved.secondary.map(makePage), animated: false)
            split.restorationSupplementary?.setViewControllers((saved.supplementary ?? []).map(makePage), animated: false)
            split.restorationCompactColumn = saved.compactColumn
            split.setExpandedMode(saved.expandedMode)
            tabs.present(split, animated: false) {
                if split.isCollapsed { split.selectColumn(saved.compactColumn) }
                window.layoutIfNeeded()
            }
        }
    }
}

@MainActor
private extension UIViewController {
    var selectedOrVisibleChild: UIViewController? {
        if let tabs = self as? UITabBarController { return tabs.selectedViewController }
        if let navigation = self as? UINavigationController { return navigation.visibleViewController }
        return nil
    }
}

@MainActor
enum SystemLanguageSettings {
    static func open(from controller: UIViewController) {
        guard let scene = controller.view.window?.windowScene,
              scene.delegate is SceneDelegate,
              let url = URL(string: UIApplication.openSettingsURLString) else { return }
        LanguageService.shared.setSelection(.system)
        SceneWindowService.checkpointAll()
        UIApplication.shared.open(url)
    }
}
