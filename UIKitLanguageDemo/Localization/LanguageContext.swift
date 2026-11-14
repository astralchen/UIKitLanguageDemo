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

    func text(_ key: String, table: String? = nil) -> String {
        let fallback = fallbackBundle.localizedString(forKey: key, value: key, table: table)
        return bundle.localizedString(forKey: key, value: fallback, table: table)
    }

    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
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
