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
        // Bundle preferences include the system's per-app language matching.
        // Locale.preferredLanguages is not the running application's language.
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

    /// Call for every app-owned window, including secondary scenes/overlay windows.
    func register(window: UIWindow) {
        windows.add(window)
        LayoutDirection.apply(context, to: window)
    }

    func unregister(window: UIWindow) { windows.remove(window) }

    func setSelection(_ newSelection: LanguageSelection) {
        // An observer may request another language; defer it until this transaction finishes.
        if isApplying { deferredSelection = newSelection; return }
        apply(newSelection, force: false)
    }

    @objc nonisolated private func environmentChanged() {
        // Foundation notifications can arrive on the posting thread.
        Task { @MainActor [weak self] in self?.refreshSystemSelection() }
    }

    private func refreshSystemSelection() {
        // In explicit-language mode, system locale changes don't change UI language.
        guard selection == .system else { return }
        if isApplying { return }
        apply(.system, force: true)
    }

    private func apply(_ newSelection: LanguageSelection, force: Bool) {
        let language = LanguageResources.resolve(newSelection, preferences: preferredLocalizationsProvider())
        guard force || selection != newSelection || context.language != language else { return }
        isApplying = true
        let previous = context
        // Capture list anchors while the old direction and old row sizes still apply.
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
            // Direction changes happen before text observers run.
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
            // List coordinators restore stable-ID anchors after every page has
            // updated its chrome and window layout has settled.
            NotificationCenter.default.post(name: .appLanguageDidApplyLayout, object: self)
            // UIKit may move the caret when the input's inherited direction changes.
            for snapshot in inputSnapshots { snapshot.restoreIfUnchanged() }
        }
        isApplying = false
        if let deferred = deferredSelection {
            deferredSelection = nil
            setSelection(deferred)
        }
    }
}
