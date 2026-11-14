import Foundation

/// Deployment-safe messages. iOS 16+ resolves the actual Xcode-generated resource.
/// Only the iOS 15 adapter owns raw keys and CVarArg formatting.
enum AppText: Equatable {
    case homeTitle
    case homeDescription
    case homeOpenDetail
    case commonBack
    case detailTitle
    case detailDescription
    case detailDraft
    case detailPlaceholder
    case detailNumber(String)
    case languageTitle
    case languageSystem
    case appearanceTitle
    case appearanceSystem
    case appearanceLight
    case appearanceDark
    case settingsTitle
    case settingsRow(Int)
    case fallbackExample
    case splitTitle
    case pagesTitle
    case pagesNumber(Int)
    case pagesPrevious
    case pagesNext
    case commonClose
    case collectionTitle
    case collectionHorizontal
    case listItem(Int)
    case listSection
    case listDescription
    case compositionalTitle
    case compositionalOrthogonal
    case compositionalCarouselSection
    case compositionalGridSection
    case systemSettings
    case splitTriple
    case splitMiddle
    case splitPush
    case splitToggle
    case windowMenu
    case windowNew
    case windowClose
    case windowName(Int32)

    /// Stable identifiers retain the existing keys across state restoration.
    var catalogKey: String {
        if #available(iOS 16.0, *) { return resource.key }
        return legacyKey
    }

    @available(iOS 16.0, *)
    var resource: LocalizedStringResource {
        switch self {
        case .homeTitle: return .homeTitle
        case .homeDescription: return .homeDescription
        case .homeOpenDetail: return .homeOpenDetail
        case .commonBack: return .commonBack
        case .detailTitle: return .detailTitle
        case .detailDescription: return .detailDescription
        case .detailDraft: return .detailDraft
        case .detailPlaceholder: return .detailPlaceholder
        case .detailNumber(let value): return .detailNumber(value)
        case .languageTitle: return .languageTitle
        case .languageSystem: return .languageSystem
        case .appearanceTitle: return .appearanceTitle
        case .appearanceSystem: return .appearanceSystem
        case .appearanceLight: return .appearanceLight
        case .appearanceDark: return .appearanceDark
        case .settingsTitle: return .settingsTitle
        case .settingsRow(let value): return .settingsRow(value)
        case .fallbackExample: return .fallbackExample
        case .splitTitle: return .splitTitle
        case .pagesTitle: return .pagesTitle
        case .pagesNumber(let value): return .pagesNumber(value)
        case .pagesPrevious: return .pagesPrevious
        case .pagesNext: return .pagesNext
        case .commonClose: return .commonClose
        case .collectionTitle: return .collectionTitle
        case .collectionHorizontal: return .collectionHorizontal
        case .listItem(let value): return .listItem(value)
        case .listSection: return .listSection
        case .listDescription: return .listDescription
        case .compositionalTitle: return .compositionalTitle
        case .compositionalOrthogonal: return .compositionalOrthogonal
        case .compositionalCarouselSection: return .compositionalCarouselSection
        case .compositionalGridSection: return .compositionalGridSection
        case .systemSettings: return .systemSettings
        case .splitTriple: return .splitTriple
        case .splitMiddle: return .splitMiddle
        case .splitPush: return .splitPush
        case .splitToggle: return .splitToggle
        case .windowMenu: return .windowMenu
        case .windowNew: return .windowNew
        case .windowClose: return .windowClose
        case .windowName(let value): return .windowName(value)
        }
    }

    // Kept in one place for systems without LocalizedStringResource.
    var legacyKey: String {
        switch self {
        case .homeTitle: return "home.title"
        case .homeDescription: return "home.description"
        case .homeOpenDetail: return "home.open_detail"
        case .commonBack: return "common.back"
        case .detailTitle: return "detail.title"
        case .detailDescription: return "detail.description"
        case .detailDraft: return "detail.draft"
        case .detailPlaceholder: return "detail.placeholder"
        case .detailNumber: return "detail.number"
        case .languageTitle: return "language.title"
        case .languageSystem: return "language.system"
        case .appearanceTitle: return "appearance.title"
        case .appearanceSystem: return "appearance.system"
        case .appearanceLight: return "appearance.light"
        case .appearanceDark: return "appearance.dark"
        case .settingsTitle: return "settings.title"
        case .settingsRow: return "settings.row"
        case .fallbackExample: return "fallback.example"
        case .splitTitle: return "split.title"
        case .pagesTitle: return "pages.title"
        case .pagesNumber: return "pages.number"
        case .pagesPrevious: return "pages.previous"
        case .pagesNext: return "pages.next"
        case .commonClose: return "common.close"
        case .collectionTitle: return "collection.title"
        case .collectionHorizontal: return "collection.horizontal"
        case .listItem: return "list.item"
        case .listSection: return "list.section"
        case .listDescription: return "list.description"
        case .compositionalTitle: return "compositional.title"
        case .compositionalOrthogonal: return "compositional.orthogonal"
        case .compositionalCarouselSection: return "compositional.carousel_section"
        case .compositionalGridSection: return "compositional.grid_section"
        case .systemSettings: return "system.settings"
        case .splitTriple: return "split.triple"
        case .splitMiddle: return "split.middle"
        case .splitPush: return "split.push"
        case .splitToggle: return "split.toggle"
        case .windowMenu: return "window.menu"
        case .windowNew: return "window.new"
        case .windowClose: return "window.close"
        case .windowName: return "window.name"
        }
    }

    var legacyArguments: [CVarArg] {
        switch self {
        case .detailNumber(let value): return [value]
        case .settingsRow(let value): return [value]
        case .pagesNumber(let value): return [value]
        case .listItem(let value): return [value]
        case .windowName(let value): return [value]
        default: return []
        }
    }
}
