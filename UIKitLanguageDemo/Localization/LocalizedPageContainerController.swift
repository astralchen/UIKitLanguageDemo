import UIKit

/// 保持 UIPageViewController 及内容控制器实例稳定。
/// 适用范围：水平、单页、scroll 转场（不包含 pageCurl）。
@MainActor
class LocalizedPageContainerController: UIViewController, LocalizationUpdatable,
                                        UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    struct Page {
        let id: String
        let controller: UIViewController
    }

    let pageViewController = UIPageViewController(transitionStyle: .scroll,
                                                 navigationOrientation: .horizontal)
    private let pages: [Page]
    var restorationPages: [Page] { pages }
    private let hosts: [LocalizedPageContentHost]
    private let titleMessage: AppText?
    private var pagingIsRTL: Bool
    private var pendingContext: LanguageContext?
    private var isTransitioning = false
    private var renderedRevision = -1
    private(set) var currentPageID: String
    var displayedContentController: UIViewController? {
        pages.first(where: { $0.id == currentPageID })?.controller
    }
    var onCurrentPageChanged: ((String) -> Void)?

    init(pages: [Page], initialPageID: String? = nil, titleMessage: AppText? = nil) {
        precondition(!pages.isEmpty, "A pager needs at least one page")
        precondition(Set(pages.map(\.id)).count == pages.count, "Page IDs must be unique")
        precondition(Set(pages.map { ObjectIdentifier($0.controller) }).count == pages.count,
                     "Each page must own a distinct controller")
        precondition(pages.allSatisfy { $0.controller.parent == nil }, "Pages must not have a parent")
        let initialID = initialPageID ?? pages[0].id
        precondition(pages.contains(where: { $0.id == initialID }), "Unknown initial page ID")
        self.pages = pages
        self.hosts = pages.map { LocalizedPageContentHost(id: $0.id, content: $0.controller) }
        self.titleMessage = titleMessage
        currentPageID = initialID
        pagingIsRTL = LanguageService.shared.context.isRTL
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use init(pages:initialPageID:titleMessage:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        addChild(pageViewController)
        // 固定物理方向为 LTR 的分页承载面，明确 before/after 的含义。
        // 每个内容宿主独立恢复 App 所选的布局方向。
        if #available(iOS 17.0, *) {
            pageViewController.traitOverrides.layoutDirection = .leftToRight
        } else {
            setOverrideTraitCollection(UITraitCollection(layoutDirection: .leftToRight),
                                       forChild: pageViewController)
        }
        pageViewController.view.semanticContentAttribute = .forceLeftToRight
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageViewController.view)
        NSLayoutConstraint.activate([
            // 此边界需要连接方向相反的布局；使用物理边缘约束，
            // 避免将 RTL 的 leading 边缘与 LTR 的 leading 边缘等同。
            pageViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
            pageViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor),
            pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        pageViewController.didMove(toParent: self)
        pageViewController.delegate = self
        pageViewController.dataSource = self
        let initial = hosts.first(where: { $0.id == currentPageID })!
        pageViewController.setViewControllers([initial], direction: .forward, animated: false)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                              name: .appLanguageDidChange, object: LanguageService.shared)
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    @objc private func refresh() {
        let context = LanguageService.shared.context
        guard renderedRevision != context.revision else { return }
        renderedRevision = context.revision
        LayoutDirection.applyBoundary(context, to: view)
        for host in hosts { host.apply(context) }
        applyLocalization(context)
        // 在交互式或程序触发的转场结束前，保持相邻页面关系稳定，
        // 即使期间收到多次语言切换请求也不改变。
        if isTransitioning { pendingContext = context }
        else { updatePagingDirection(context) }
    }

    @objc private func showWindows() { SceneWindowService.presentSwitcher(from: self) }

    @objc private func openSystemSettings() { SystemLanguageSettings.open(from: self) }

    func applyLocalization(_ context: LanguageContext) {
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
            let windows = UIBarButtonItem(image: UIImage(systemName: "macwindow.on.rectangle"), style: .plain, target: self, action: #selector(showWindows))
            windows.accessibilityIdentifier = "scene.windows"
            navigationItem.rightBarButtonItems = (navigationItem.rightBarButtonItems ?? []) + [windows]
        }
        navigationItem.rightBarButtonItems?.first(where: { $0.accessibilityIdentifier == "scene.windows" })?.accessibilityLabel = context.text(.windowMenu)
        if let titleMessage { title = context.text(titleMessage) }
    }

    private func updatePagingDirection(_ context: LanguageContext) {
        guard pagingIsRTL != context.isRTL else { return }
        pagingIsRTL = context.isRTL
        // 重新查询相邻页面，同时保留当前显示的宿主实例。
        guard let visible = pageViewController.viewControllers, !visible.isEmpty else { return }
        pageViewController.dataSource = nil
        pageViewController.setViewControllers(visible, direction: .forward, animated: false)
        pageViewController.dataSource = self
    }

    private func finishTransition() {
        isTransitioning = false
        var changedID: String?
        if let visible = pageViewController.viewControllers?.first as? LocalizedPageContentHost,
           currentPageID != visible.id {
            currentPageID = visible.id
            changedID = visible.id
        }
        if let context = pendingContext {
            pendingContext = nil
            updatePagingDirection(context)
        }
        // 业务回调可能再次导航或切换语言。先完成本次事务，
        // 避免旧的 context 覆盖业务回调产生的新状态。
        if let changedID { onCurrentPageChanged?(changedID) }
    }

    @discardableResult
    func showPage(id: String, animated: Bool = true) -> Bool {
        loadViewIfNeeded()
        guard !isTransitioning, let target = hosts.firstIndex(where: { $0.id == id }),
              let current = hosts.firstIndex(where: { $0.id == currentPageID }) else { return false }
        guard target != current else { return true }
        let forward = (target > current) != pagingIsRTL
        isTransitioning = true
        pageViewController.setViewControllers([hosts[target]], direction: forward ? .forward : .reverse,
                                              animated: animated) { [weak self] _ in
            self?.finishTransition()
        }
        return true
    }

    @discardableResult
    func nextPage(animated: Bool = true) -> Bool { move(by: 1, animated: animated) }
    @discardableResult
    func previousPage(animated: Bool = true) -> Bool { move(by: -1, animated: animated) }
    private func move(by offset: Int, animated: Bool) -> Bool {
        guard let current = pages.firstIndex(where: { $0.id == currentPageID }),
              pages.indices.contains(current + offset) else { return false }
        return showPage(id: pages[current + offset].id, animated: animated)
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        neighbor(of: viewController, delta: pagingIsRTL ? 1 : -1)
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        neighbor(of: viewController, delta: pagingIsRTL ? -1 : 1)
    }

    private func neighbor(of controller: UIViewController, delta: Int) -> UIViewController? {
        guard let index = hosts.firstIndex(where: { $0 === controller }),
              hosts.indices.contains(index + delta) else { return nil }
        return hosts[index + delta]
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            willTransitionTo pendingViewControllers: [UIViewController]) {
        isTransitioning = true
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        // 滑动取消时也要提交待处理状态；当前 ID 以可见 VC 为准。
        finishTransition()
    }
}

/// 将页面内容方向与 pager 固定的物理承载面分离。
@MainActor
private final class LocalizedPageContentHost: UIViewController {
    let id: String
    let content: UIViewController
    private var context: LanguageContext

    init(id: String, content: UIViewController) {
        self.id = id
        self.content = content
        context = LanguageService.shared.context
        super.init(nibName: nil, bundle: nil)
        apply(context)
    }
    required init?(coder: NSCoder) { fatalError("Use init(id:content:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(content)
        apply(context)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content.view)
        NSLayoutConstraint.activate([
            content.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.view.topAnchor.constraint(equalTo: view.topAnchor),
            content.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        content.didMove(toParent: self)
    }

    func apply(_ context: LanguageContext) {
        self.context = context
        if #available(iOS 17.0, *) {
            traitOverrides.layoutDirection = context.isRTL ? .rightToLeft : .leftToRight
        } else if content.parent === self {
            setOverrideTraitCollection(UITraitCollection(layoutDirection:
                context.isRTL ? .rightToLeft : .leftToRight), forChild: content)
        }
        if let view = viewIfLoaded {
            view.semanticContentAttribute = context.isRTL ? .forceRightToLeft : .forceLeftToRight
            view.setNeedsLayout()
        }
    }
}
