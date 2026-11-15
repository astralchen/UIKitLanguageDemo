import UIKit

@MainActor
enum LayoutDirection {
    static func apply(_ context: LanguageContext, to window: UIWindow) {
        if #available(iOS 17.0, *) {
            // Scene scope also covers view controllers presented later.
            if let scene = window.windowScene {
                scene.traitOverrides.layoutDirection = context.isRTL ? .rightToLeft : .leftToRight
            } else {
                window.traitOverrides.layoutDirection = context.isRTL ? .rightToLeft : .leftToRight
            }
        } else {
            window.semanticContentAttribute = context.isRTL ? .forceRightToLeft : .forceLeftToRight
        }
        (window.rootViewController as? LocalizationHostController)?.apply(context)
        window.setNeedsLayout()
    }

    /// Compatibility boundary for app-owned views on iOS 15/16.
    /// Do not recursively overwrite children: playback/spatial/LTR exceptions must survive.
    static func applyBoundary(_ context: LanguageContext, to view: UIView) {
        if #available(iOS 17.0, *) { return }
        view.semanticContentAttribute = context.isRTL ? .forceRightToLeft : .forceLeftToRight
    }

    /// Give app-owned scrolling surfaces an explicit direction on every supported
    /// OS at initial load and on each language refresh, including native chrome.
    /// Only call for app-owned scroll views, never recursively for UIKit engines.
    static func applyScrollView(_ context: LanguageContext, to scrollView: UIScrollView) {
        scrollView.semanticContentAttribute = context.isRTL ? .forceRightToLeft : .forceLeftToRight
        scrollView.setNeedsLayout()
    }

    /// Align the draft and its placeholder with the App. Keep the Unicode
    /// writing direction of user content; never rewrite text or selection here.
    static func applyTextField(_ context: LanguageContext, to field: UITextField) {
        field.semanticContentAttribute = context.isRTL ? .forceRightToLeft : .forceLeftToRight
        field.textAlignment = context.isRTL ? .right : .left
    }
}

/// Installed once when creating a window; never replaced when changing language.
@MainActor
final class LocalizationHostController: UIViewController {
    let content: UIViewController

    init(content: UIViewController) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use init(content:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content.view)
        NSLayoutConstraint.activate([
            content.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.view.topAnchor.constraint(equalTo: view.topAnchor),
            content.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        content.didMove(toParent: self)
        apply(LanguageService.shared.context)
    }

    func apply(_ context: LanguageContext) {
        // register(window:) can run before the host has installed its child.
        guard isViewLoaded, content.parent === self else { return }
        if #available(iOS 17.0, *) {
            // Scene supplies the inherited direction.
        } else {
            setOverrideTraitCollection(UITraitCollection(layoutDirection:
                context.isRTL ? .rightToLeft : .leftToRight), forChild: content)
        }
        if let view = viewIfLoaded { LayoutDirection.applyBoundary(context, to: view) }
    }

    override var childForStatusBarStyle: UIViewController? { content }
    override var childForStatusBarHidden: UIViewController? { content }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { content.supportedInterfaceOrientations }
    override var shouldAutorotate: Bool { content.shouldAutorotate }
    override var preferredStatusBarStyle: UIStatusBarStyle { content.preferredStatusBarStyle }
}
