import UIKit

/// Supports the double/triple-column APIs. Install column controllers once.
/// Language changes never call setViewController, show/hide, or change display mode.
@MainActor
class LocalizedSplitViewController: UISplitViewController, LocalizationUpdatable {
    var restorationPrimary: LocalizedNavigationController?
    var restorationSecondary: LocalizedNavigationController?
    var restorationShowsSecondary = false
    private var renderedRevision = -1

    override init(style: UISplitViewController.Style) {
        precondition(style != .unspecified, "Use doubleColumn or tripleColumn")
        super.init(style: style)
        // This is a logical edge: right in RTL, left in LTR. Never invert it again.
        primaryEdge = .leading
    }
    required init?(coder: NSCoder) { fatalError("Use init(style:)") }

    override func show(_ column: UISplitViewController.Column) {
        // Persist the requested business column even before UIKit completes a transition.
        super.show(column)
        if column == .secondary { restorationShowsSecondary = true }
        if column == .primary { restorationShowsSecondary = false }
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
