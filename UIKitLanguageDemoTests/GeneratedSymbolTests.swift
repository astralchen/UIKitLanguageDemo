import XCTest
@testable import UIKitLanguageDemo

@MainActor
final class GeneratedSymbolTests: XCTestCase {
    private var messages: [AppText] { [
        .homeTitle,
        .homeDescription,
        .homeOpenDetail,
        .commonBack,
        .detailTitle,
        .detailDescription,
        .detailDraft,
        .detailPlaceholder,
        .detailNumber("123.45"),
        .languageTitle,
        .languageSystem,
        .appearanceTitle,
        .appearanceSystem,
        .appearanceLight,
        .appearanceDark,
        .settingsTitle,
        .settingsRow(7),
        .fallbackExample,
        .splitTitle,
        .pagesTitle,
        .pagesNumber(7),
        .pagesPrevious,
        .pagesNext,
        .commonClose,
        .collectionTitle,
        .collectionHorizontal,
        .listItem(7),
        .listSection,
        .listDescription,
        .compositionalTitle,
        .compositionalOrthogonal,
        .compositionalCarouselSection,
        .compositionalGridSection,
        .systemSettings,
        .splitTriple,
        .splitMiddle,
        .splitPush,
        .splitToggle,
        .windowMenu,
        .windowNew,
        .windowClose,
        .windowName(7)
    ] }

    func testGeneratedSymbolsMatchIOS15AdapterForEveryCatalogEntry() throws {
        let resources = LanguageResources.load(from: .main)
        XCTAssertEqual(Set(messages.map(\.catalogKey)).count, 42)
        for language in AppLanguage.allCases {
            let context = LanguageContext(language: language, bundle: try XCTUnwrap(resources[language]),
                                          fallbackBundle: try XCTUnwrap(resources[.english]), revision: 0)
            for message in messages {
                if #available(iOS 16.0, *) {
                    XCTAssertEqual(message.resource.key, message.legacyKey)
                }
                XCTAssertEqual(context.text(message), context.legacyText(message),
                               "\(language.rawValue): \(message.catalogKey)")
            }
            // Keep CVarArg width and negative/large values correct on 64-bit iOS 15 too.
            for number in [-1, 0, Int.max] {
                XCTAssertEqual(context.text(.listItem(number)), context.legacyText(.listItem(number)))
            }
            for number in [Int32.min, 0, Int32.max] {
                XCTAssertEqual(context.text(.windowName(number)), context.legacyText(.windowName(number)))
            }
        }
    }

    func testGeneratedResourcesUseExplicitLanguageAndEnglishFallback() throws {
        let name = "UIKitLanguageDemo.symbols.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        // Deliberately disagree with the explicit selection to catch process-language lookup.
        let service = LanguageService(defaults: defaults, preferredLocalizations: { ["zh-Hans"] })
        let retainedMessage = AppText.homeTitle
        for (selection, expected) in [(LanguageSelection.english, "Home"), (.arabic, "الرئيسية"),
                                      (.simplifiedChinese, "首页"), (.english, "Home")] {
            service.setSelection(selection)
            XCTAssertEqual(service.context.text(retainedMessage), expected)
            XCTAssertEqual(service.context.text(.fallbackExample), "English fallback")
            XCTAssertEqual(service.context.legacyText(.fallbackExample), "English fallback")
            XCTAssertEqual(service.context.text(.detailNumber("A%123")),
                           service.context.legacyText(.detailNumber("A%123")))
        }
        service.setSelection(.system)
        XCTAssertEqual(service.context.text(retainedMessage), "首页")
        XCTAssertEqual(service.context.legacyLookup("unknown.key"), "unknown.key")
    }
}
