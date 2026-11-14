import UIKit

/// Supports the double/triple-column APIs. Install column controllers once.
/// Language changes never call setViewController, show/hide, or change display mode.
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
        // This is a logical edge: right in RTL, left in LTR. Never invert it again.
        primaryEdge = .leading
    }
    required init?(coder: NSCoder) { fatalError("Use init(style:)") }

    /// Business intent is separate from UIKit's internal show calls while rearranging sidebars.
    func selectColumn(_ column: SavedSplitColumn) {
        super.show(column.uiKit)
        restorationCompactColumn = column
    }

    override func show(_ column: UISplitViewController.Column) {
        // Persist the requested business column even before UIKit completes a transition.
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

    /// Override for app-owned split chrome. Column pages use their own refresh hooks.
    func applyLocalization(_ context: LanguageContext) {}
}

/// The demo owns this delegate. General LocalizedSplitViewController never replaces a business delegate.
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
