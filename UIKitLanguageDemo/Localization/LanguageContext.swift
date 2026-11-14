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

/// Immutable resource snapshot. No global translated-string cache.
struct LanguageContext {
    let language: AppLanguage
    let bundle: Bundle
    let fallbackBundle: Bundle
    let revision: Int

    var isRTL: Bool { language.isRTL }
    // Demo policy: UI language also determines number/date formatting.
    // A production app can inject a separate regional preference here.
    var locale: Locale { Locale(identifier: language.rawValue) }

    func text(_ message: AppText) -> String {
        if #available(iOS 16.0, *) {
            // Generated resources are values; never cache a rendered string or mutate a shared one.
            var resource = message.resource
            let missing = "__UIKitLanguageDemo_missing_translation_22C356C7__"
            let selected = bundle.localizedString(forKey: resource.key, value: missing, table: resource.table)
            // Foundation returns the key for absent generated translations. Select English
            // explicitly instead of falling through to the process's preferred language.
            resource.locale = selected == missing ? Locale(identifier: "en") : locale
            return String(localized: resource)
        }
        return legacyText(message)
    }

    /// Shared with tests so the exact iOS 15 path is exercised on the current simulator too.
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
