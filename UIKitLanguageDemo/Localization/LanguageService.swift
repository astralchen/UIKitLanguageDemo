import UIKit

extension Notification.Name {
    static let appLanguageWillChange = Notification.Name("UIKitLanguageDemo.appLanguageWillChange")
    static let appLanguageDidApplyLayout = Notification.Name("UIKitLanguageDemo.appLanguageDidApplyLayout")
    static let appLanguageDidChange = Notification.Name("UIKitLanguageDemo.appLanguageDidChange")
}

@MainActor
final class LanguageService: NSObject {
    static let shared = LanguageService()
    private static let preferenceKey = "app.language.selection"

    private let defaults: UserDefaults
    private let resources: [AppLanguage: Bundle]
    private let preferredLocalizationsProvider: () -> [String]
    private let windows = NSHashTable<UIWindow>.weakObjects()
    private var isApplying = false
    private var deferredSelection: LanguageSelection?

    private(set) var selection: LanguageSelection
    private(set) var context: LanguageContext

    init(resourceBundle: Bundle = .main, defaults: UserDefaults = .standard,
         preferredLocalizations: (() -> [String])? = nil) {
        self.defaults = defaults
        // Bundle 的语言偏好包含系统对单个 App 的语言匹配结果。
        // Locale.preferredLanguages 不代表当前运行的 App 语言。
        let provider = preferredLocalizations ?? { resourceBundle.preferredLocalizations }
        self.preferredLocalizationsProvider = provider
        let resources = LanguageResources.load(from: resourceBundle)
        self.resources = resources
        let selection = defaults.string(forKey: Self.preferenceKey)
            .flatMap(LanguageSelection.init(rawValue:)) ?? .system
        self.selection = selection
        let language = LanguageResources.resolve(selection, preferences: provider())
        context = LanguageContext(language: language, bundle: resources[language]!,
                                  fallbackBundle: resources[.english]!, revision: 0)
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(environmentChanged),
                                              name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(environmentChanged),
                                              name: NSLocale.currentLocaleDidChangeNotification, object: nil)
    }

    /// 为每个由 App 管理的窗口调用，包括次级 Scene 和浮层窗口。
    func register(window: UIWindow) {
        windows.add(window)
        LayoutDirection.apply(context, to: window)
    }

    func unregister(window: UIWindow) { windows.remove(window) }

    func setSelection(_ newSelection: LanguageSelection) {
        // 观察者可能请求切换到另一种语言；将该请求延迟到本次事务完成后处理。
        if isApplying { deferredSelection = newSelection; return }
        apply(newSelection, force: false)
    }

    @objc nonisolated private func environmentChanged() {
        // Foundation 通知可能在发送通知的线程上回调。
        Task { @MainActor [weak self] in self?.refreshSystemSelection() }
    }

    private func refreshSystemSelection() {
        // 显式选择语言时，系统 locale 的变化不影响 UI 语言。
        guard selection == .system else { return }
        if isApplying { return }
        apply(.system, force: true)
    }

    private func apply(_ newSelection: LanguageSelection, force: Bool) {
        let language = LanguageResources.resolve(newSelection, preferences: preferredLocalizationsProvider())
        guard force || selection != newSelection || context.language != language else { return }
        isApplying = true
        let previous = context
        // 在旧布局方向和旧行尺寸仍然生效时，捕获列表阅读锚点。
        NotificationCenter.default.post(name: .appLanguageWillChange, object: self, userInfo: [
            "oldLanguageID": previous.language.rawValue,
            "newLanguageID": language.rawValue,
            "revision": previous.revision + 1
        ])
        selection = newSelection
        context = LanguageContext(language: language, bundle: resources[language]!,
                                  fallbackBundle: resources[.english]!, revision: previous.revision + 1)
        defaults.set(newSelection.rawValue, forKey: Self.preferenceKey)

        UIView.performWithoutAnimation {
            // 先更新方向，再执行文本观察者的回调。
            let registeredWindows = windows.allObjects
            let inputSnapshots = registeredWindows.compactMap { TextInputSnapshot.capture(in: $0) }
            for window in registeredWindows { LayoutDirection.apply(context, to: window) }
            NotificationCenter.default.post(name: .appLanguageDidChange, object: self, userInfo: [
                "oldLanguageID": previous.language.rawValue,
                "newLanguageID": context.language.rawValue,
                "directionChanged": previous.isRTL != context.isRTL,
                "revision": context.revision
            ])
            for window in registeredWindows {
                window.setNeedsLayout()
                window.layoutIfNeeded()
            }
            // 所有页面更新完界面元素且窗口布局稳定后，
            // 列表协调器再根据稳定 ID 恢复阅读锚点。
            NotificationCenter.default.post(name: .appLanguageDidApplyLayout, object: self)
            // 输入控件继承的方向变化时，UIKit 可能移动插入光标。
            for snapshot in inputSnapshots { snapshot.restoreIfUnchanged() }
        }
        isApplying = false
        if let deferred = deferredSelection {
            deferredSelection = nil
            setSelection(deferred)
        }
    }
}
