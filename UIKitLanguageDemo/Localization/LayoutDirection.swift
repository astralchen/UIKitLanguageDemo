import UIKit

@MainActor
enum LayoutDirection {
    static func apply(_ context: LanguageContext, to window: UIWindow) {
        if #available(iOS 17.0, *) {
            // Scene 作用域也覆盖后续通过 present 显示的视图控制器。
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

    /// 用于 iOS 15/16 中由 App 管理的视图的兼容边界。
    /// 不要递归覆盖子视图，以保留 playback、spatial 和 LTR 等语义例外。
    static func applyBoundary(_ context: LanguageContext, to view: UIView) {
        if #available(iOS 17.0, *) { return }
        view.semanticContentAttribute = context.isRTL ? .forceRightToLeft : .forceLeftToRight
    }

    /// 在所有支持的系统上，为 App 管理的滚动视图及其原生界面元素显式指定方向，
    /// 首次加载和每次语言刷新时都要应用。
    /// 仅对 App 管理的滚动视图调用，不递归修改 UIKit 内部的滚动引擎。
    static func applyScrollView(_ context: LanguageContext, to scrollView: UIScrollView) {
        scrollView.semanticContentAttribute = context.isRTL ? .forceRightToLeft : .forceLeftToRight
        scrollView.setNeedsLayout()
    }

    /// 让草稿及其 placeholder 的对齐方向跟随 App，同时保留用户内容的 Unicode 书写方向。
    /// 此处不改写文本或选区。
    static func applyTextField(_ context: LanguageContext, to field: UITextField) {
        field.semanticContentAttribute = context.isRTL ? .forceRightToLeft : .forceLeftToRight
        field.textAlignment = context.isRTL ? .right : .left
    }
}

/// 创建窗口时仅安装一次，切换语言时不替换。
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
        // register(window:) 可能在宿主安装子控制器之前执行。
        guard isViewLoaded, content.parent === self else { return }
        if #available(iOS 17.0, *) {
            // 继承的布局方向由 Scene 提供。
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
