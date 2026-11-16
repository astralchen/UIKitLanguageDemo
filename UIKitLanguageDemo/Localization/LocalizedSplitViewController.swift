import UIKit

/// 支持双栏和三栏 API，栏控制器只安装一次。
/// 切换语言时不调用 setViewController、show/hide，也不改变显示模式。
@MainActor
class LocalizedSplitViewController: UISplitViewController, LocalizationUpdatable {
    var restorationPrimary: LocalizedNavigationController?
    var restorationSupplementary: LocalizedNavigationController?
    var restorationSecondary: LocalizedNavigationController?
    var restorationCompactColumn: SavedSplitColumn = .primary
    var restorationExpandedMode: SavedSplitDisplayMode = .oneBesideSecondary
    var restorationShowsSecondary: Bool {
        get { restorationCompactColumn == .secondary }
        set { restorationCompactColumn = newValue ? .secondary : .primary }
    }
    private var restorationPolicy: SplitRestorationPolicy?

    func installDemoRestorationPolicy() {
        precondition(delegate == nil, "Merge the restoration callbacks into an existing business delegate instead")
        let policy = SplitRestorationPolicy(owner: self)
        restorationPolicy = policy
        delegate = policy
    }

    func recordVisibleBusinessPage(_ controller: UIViewController) {
        guard isCollapsed, traitCollection.horizontalSizeClass == .compact, restorationPolicy?.adapting != true else { return }
        for (column, navigation) in [(SavedSplitColumn.primary, restorationPrimary), (.supplementary, restorationSupplementary), (.secondary, restorationSecondary)] {
            if navigation?.viewControllers.contains(where: { $0 === controller }) == true { restorationCompactColumn = column }
        }
    }

    func setExpandedMode(_ mode: SavedSplitDisplayMode) {
        restorationExpandedMode = mode
        preferredDisplayMode = mode.uiKit
    }
    private var renderedRevision = -1

    override init(style: UISplitViewController.Style) {
        precondition(style != .unspecified, "Use doubleColumn or tripleColumn")
        super.init(style: style)
        // 此处使用逻辑边缘：RTL 为右侧，LTR 为左侧，不要再次反转。
        primaryEdge = .leading
    }
    required init?(coder: NSCoder) { fatalError("Use init(style:)") }

    /// 将业务意图与 UIKit 重排侧边栏时内部触发的 show 调用分开处理。
    func selectColumn(_ column: SavedSplitColumn) {
        super.show(column.uiKit)
        restorationCompactColumn = column
    }

    override func show(_ column: UISplitViewController.Column) {
        // 即使 UIKit 尚未完成转场，也先持久化业务请求的目标栏。
        super.show(column)
        if isCollapsed, traitCollection.horizontalSizeClass == .compact, restorationPolicy?.adapting != true,
           let column = SavedSplitColumn(column) { restorationCompactColumn = column }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                              name: .appLanguageDidChange, object: LanguageService.shared)
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    @objc private func refresh() {
        guard isViewLoaded else { return }
        let context = LanguageService.shared.context
        guard renderedRevision != context.revision else { return }
        renderedRevision = context.revision
        LayoutDirection.applyBoundary(context, to: view)
        applyLocalization(context)
        view.setNeedsLayout()
    }

    /// 由子类重写，以刷新 App 管理的分栏界面元素；各栏页面使用自身的刷新钩子。
    func applyLocalization(_ context: LanguageContext) {}
}

/// 此 delegate 由 Demo 管理；通用的 LocalizedSplitViewController 不替换业务 delegate。
@MainActor
private final class SplitRestorationPolicy: NSObject, UISplitViewControllerDelegate {
    weak var owner: LocalizedSplitViewController?
    var adapting = false
    init(owner: LocalizedSplitViewController) { self.owner = owner }
    func splitViewController(_ svc: UISplitViewController,
        topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        adapting = true
        return owner?.restorationCompactColumn.uiKit ?? proposedTopColumn
    }
    func splitViewController(_ svc: UISplitViewController,
        displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode) -> UISplitViewController.DisplayMode {
        adapting = true
        return owner?.restorationExpandedMode.uiKit ?? proposedDisplayMode
    }
    func splitViewControllerDidCollapse(_ svc: UISplitViewController) { adapting = false }
    func splitViewControllerDidExpand(_ svc: UISplitViewController) { adapting = false }
    func splitViewController(_ svc: UISplitViewController, willChangeTo mode: UISplitViewController.DisplayMode) {
        if !adapting, !svc.isCollapsed, svc.traitCollection.horizontalSizeClass != .compact, let mode = SavedSplitDisplayMode(mode) { owner?.restorationExpandedMode = mode }
    }
    func splitViewController(_ svc: UISplitViewController, willShow column: UISplitViewController.Column) {
        if !adapting, svc.isCollapsed, let column = SavedSplitColumn(column) { owner?.restorationCompactColumn = column }
    }
}
