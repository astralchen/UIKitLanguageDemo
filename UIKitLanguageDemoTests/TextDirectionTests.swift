import XCTest
import UIKit
import CoreText
@testable import UIKitLanguageDemo

final class TextDirectionTests: XCTestCase {
    @MainActor
    func testDraftsFollowAppEdgeAndPhoneKeepsLTRCharacterOrder() throws {
        let detail = DetailViewController()
        let fixture = try TextDirectionWindow(content: detail)
        defer { fixture.close() }
        let split = SplitMenuViewController()
        let page = DemoPageViewController(number: 2)
        split.loadViewIfNeeded(); page.loadViewIfNeeded()
        let list = ListDemoContent()
        let fields = [detail.draftField, split.draftField, page.draft, list.draft]
        fields.forEach { $0.text = "Draft مسودة 123" }
        func descendants(_ view: UIView) -> [UIView] {
            view.subviews.flatMap { [$0] + descendants($0) }
        }
        let phone = try XCTUnwrap(descendants(detail.view).compactMap { $0 as? UILabel }
            .first { $0.text == "+86 138 0000 0000" })
        for selection in [LanguageSelection.arabic, .english, .simplifiedChinese, .arabic] {
            LanguageService.shared.setSelection(selection)
            let context = LanguageService.shared.context
            list.render(id: 0, context: context)
            fixture.window.layoutIfNeeded()
            for field in fields {
                XCTAssertEqual(field.textAlignment, context.isRTL ? .right : .left)
                XCTAssertEqual(field.effectiveUserInterfaceLayoutDirection, context.isRTL ? .rightToLeft : .leftToRight)
                XCTAssertEqual(field.text, "Draft مسودة 123")
                XCTAssertEqual(field.placeholder, context.text(.detailPlaceholder))
            }
            XCTAssertEqual(phone.textAlignment, context.isRTL ? .right : .left)
            XCTAssertEqual(phone.semanticContentAttribute, .forceLeftToRight)
            XCTAssertEqual(phone.text, "+86 138 0000 0000")
            let attributed = try XCTUnwrap(phone.attributedText)
            let paragraph = try XCTUnwrap(attributed.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            XCTAssertEqual(paragraph.baseWritingDirection, .leftToRight)
            XCTAssertEqual(paragraph.alignment, context.isRTL ? .right : .left)
            let line = CTLineCreateWithAttributedString(attributed)
            let plusX = CTLineGetOffsetForStringIndex(line, 0, nil)
            let lastDigitX = CTLineGetOffsetForStringIndex(line, attributed.length - 1, nil)
            XCTAssertLessThan(plusX, lastDigitX, "Country code must precede the last digit visually")
        }
    }

    @MainActor
    func testFocusedDraftPreservesSelectionCompositionAndEmptyCaretEdge() async throws {
        let detail = DetailViewController()
        let fixture = try TextDirectionWindow(content: detail)
        let field = detail.draftField
        // Exercise the real UITextInput responder/selection without starting
        // a system keyboard during the simulator regression.
        field.inputView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        defer { field.resignFirstResponder(); fixture.close() }
        field.text = "Draft مسودة 123"
        XCTAssertTrue(field.becomeFirstResponder())
        let start = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 3))
        let end = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 7))
        field.selectedTextRange = field.textRange(from: start, to: end)
        for selection in [LanguageSelection.arabic, .english, .simplifiedChinese] {
            LanguageService.shared.setSelection(selection)
            await Task.yield()
            XCTAssertTrue(field.isFirstResponder)
            XCTAssertEqual(field.text, "Draft مسودة 123")
            let range = try XCTUnwrap(field.selectedTextRange)
            XCTAssertEqual(field.offset(from: field.beginningOfDocument, to: range.start), 3)
            XCTAssertEqual(field.offset(from: field.beginningOfDocument, to: range.end), 7)
        }
        field.text = ""
        for selection in [LanguageSelection.arabic, .english, .arabic] {
            LanguageService.shared.setSelection(selection)
            await Task.yield()
            fixture.window.layoutIfNeeded()
            let caret = field.caretRect(for: field.beginningOfDocument)
            let inset = LanguageService.shared.context.isRTL ? field.bounds.maxX - caret.midX : caret.midX
            XCTAssertLessThan(inset, 16, "Empty caret must follow App leading edge: \(caret)")
            XCTAssertGreaterThanOrEqual(inset, 0)
        }
        field.setMarkedText("拼音", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertNotNil(field.markedTextRange)
        for selection in [LanguageSelection.english, .arabic] {
            LanguageService.shared.setSelection(selection)
            await Task.yield()
            let marked = try XCTUnwrap(field.markedTextRange, "A language switch must not commit the IME composition")
            XCTAssertEqual(field.text(in: marked), "拼音")
            XCTAssertEqual(field.text, "拼音")
            XCTAssertTrue(field.isFirstResponder)
        }
        field.unmarkText()
    }
}

@MainActor
private final class TextDirectionWindow {
    let window: UIWindow
    private let previous: UIWindow?
    private let original: LanguageSelection
    init(content: UIViewController) throws {
        let service = LanguageService.shared
        original = service.selection
        service.setSelection(.english)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        previous = scene.windows.first { $0.isKeyWindow }
        window = UIWindow(windowScene: scene)
        window.rootViewController = LocalizationHostController(content: content)
        service.register(window: window)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
    }
    func close() {
        LanguageService.shared.unregister(window: window)
        window.isHidden = true
        LanguageService.shared.setSelection(original)
        previous?.makeKeyAndVisible()
    }
}
