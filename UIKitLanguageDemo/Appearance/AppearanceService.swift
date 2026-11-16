import UIKit

enum AppearanceSelection: String, CaseIterable {
    case system, light, dark

    var style: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    var title: AppText {
        switch self {
        case .system: return .appearanceSystem
        case .light: return .appearanceLight
        case .dark: return .appearanceDark
        }
    }
}

extension Notification.Name {
    /// 已保存的外观选项发生变化。系统外观变化通过 UIKit traits 传递。
    static let appAppearanceDidChange = Notification.Name("UIKitLanguageDemo.appAppearanceDidChange")
}

@MainActor
final class AppearanceService {
    static let shared = AppearanceService()
    private static let preferenceKey = "app.appearance.selection"
    private let defaults: UserDefaults
    private let windows = NSHashTable<UIWindow>.weakObjects()
    private(set) var selection: AppearanceSelection

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = defaults.string(forKey: Self.preferenceKey)
            .flatMap(AppearanceSelection.init(rawValue:)) ?? .system
    }

    /// 注册每个由 App 管理的窗口，包括新建的 Scene 和浮层窗口。
    func register(window: UIWindow) {
        windows.add(window)
        window.overrideUserInterfaceStyle = selection.style
    }

    func unregister(window: UIWindow) { windows.remove(window) }

    func setSelection(_ selection: AppearanceSelection) {
        guard self.selection != selection else { return }
        self.selection = selection
        defaults.set(selection.rawValue, forKey: Self.preferenceKey)
        UIView.performWithoutAnimation {
            for window in windows.allObjects {
                window.overrideUserInterfaceStyle = selection.style
            }
        }
        NotificationCenter.default.post(name: .appAppearanceDidChange, object: self)
    }
}
