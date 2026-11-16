import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case arabic = "ar"

    var isRTL: Bool { self == .arabic }
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .arabic: return "العربية"
        }
    }
}

enum LanguageSelection: String, CaseIterable {
    case system, english = "en", simplifiedChinese = "zh-Hans", arabic = "ar"
    var explicitLanguage: AppLanguage? { AppLanguage(rawValue: rawValue) }
}

/// 不可变的资源快照，不使用全局已翻译字符串缓存。
struct LanguageContext {
    let language: AppLanguage
    let bundle: Bundle
    let fallbackBundle: Bundle
    let revision: Int

    var isRTL: Bool { language.isRTL }
    // Demo 策略：UI 语言同时决定数字和日期的格式。
    // 实际 App 可在此注入独立的地区偏好。
    var locale: Locale { Locale(identifier: language.rawValue) }

    func text(_ message: AppText) -> String {
        if #available(iOS 16.0, *) {
            // 生成的资源具有值语义；不要缓存已渲染的字符串，也不要修改共享字符串。
            var resource = message.resource
            let missing = "__UIKitLanguageDemo_missing_translation_22C356C7__"
            let selected = bundle.localizedString(forKey: resource.key, value: missing, table: resource.table)
            // 生成的翻译缺失时，Foundation 会返回 key。
            // 应显式选择英语回退，避免使用进程的首选语言。
            resource.locale = selected == missing ? Locale(identifier: "en") : locale
            return String(localized: resource)
        }
        return legacyText(message)
    }

    /// 与测试共享，使当前模拟器也能验证完全相同的 iOS 15 兼容路径。
    func legacyText(_ message: AppText) -> String {
        let value = legacyLookup(message.legacyKey)
        let arguments = message.legacyArguments
        return arguments.isEmpty ? value : String(format: value, locale: locale, arguments: arguments)
    }

    func legacyLookup(_ key: String, table: String? = nil) -> String {
        let fallback = fallbackBundle.localizedString(forKey: key, value: key, table: table)
        return bundle.localizedString(forKey: key, value: fallback, table: table)
    }

}

enum LanguageResources {
    static func load(from resourceBundle: Bundle) -> [AppLanguage: Bundle] {
        Dictionary(uniqueKeysWithValues: AppLanguage.allCases.map { language in
            guard let url = resourceBundle.url(forResource: language.rawValue, withExtension: "lproj"),
                  let bundle = Bundle(url: url) else {
                preconditionFailure("Missing \(language.rawValue).lproj. Check target resource membership.")
            }
            return (language, bundle)
        })
    }

    static func resolve(_ selection: LanguageSelection, preferences: [String]) -> AppLanguage {
        if let explicit = selection.explicitLanguage { return explicit }
        let best = Bundle.preferredLocalizations(
            from: AppLanguage.allCases.map(\.rawValue), forPreferences: preferences
        ).first
        return best.flatMap(AppLanguage.init(rawValue:)) ?? .english
    }
}
