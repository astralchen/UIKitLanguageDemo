import XCTest
import UIKit
@testable import UIKitLanguageDemo

final class LanguagePickerAlignmentTests: XCTestCase {
    @MainActor
    func testEveryLanguageRowFollowsAppLeadingEdgeAfterRepeatedSwitches() async throws {
        let service = LanguageService.shared
        let original = service.selection
        service.setSelection(.english)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let detail = DetailViewController()
        window.rootViewController = LocalizationHostController(content: detail)
        service.register(window: window)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer {
            service.unregister(window: window)
            window.isHidden = true
            service.setSelection(original)
            previous?.makeKeyAndVisible()
        }
        func descendants(_ view: UIView) -> [UIView] {
            view.subviews.flatMap { [$0] + descendants($0) }
        }
        let buttons = descendants(detail.view).compactMap { $0 as? UIButton }
            .filter { $0.accessibilityIdentifier?.hasPrefix("language.") == true }
        XCTAssertEqual(buttons.count, 4)
        let identities = buttons.map(ObjectIdentifier.init)
        // Use the same actions as a tap; every endonym must align to the App's
        // leading edge even when its script differs from the selected language.
        for selection in [LanguageSelection.english, .arabic, .simplifiedChinese, .english, .arabic] {
            let selected = try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "language.\(selection.rawValue)" })
            selected.sendActions(for: .touchUpInside)
            await Task.yield()
            for highlighted in [false, true, false] {
                selected.isHighlighted = highlighted
                await Task.yield()
                window.layoutIfNeeded()
                for button in buttons {
                    button.layoutIfNeeded()
                    let title = try XCTUnwrap(button.titleLabel)
                    XCTAssertFalse(title.isHidden)
                    XCTAssertGreaterThan(title.bounds.width, 0)
                    var content = title.convert(title.bounds, to: button)
                    if button.configuration?.image != nil {
                        let image = try XCTUnwrap(button.imageView)
                        let imageFrame = image.convert(image.bounds, to: button)
                        content = content.union(imageFrame)
                        if service.context.isRTL {
                            XCTAssertLessThan(imageFrame.maxX, title.convert(title.bounds, to: button).minX)
                        } else {
                            XCTAssertGreaterThan(imageFrame.minX, title.convert(title.bounds, to: button).maxX)
                        }
                    }
                    let inset = service.context.isRTL ? button.bounds.width - content.maxX : content.minX
                    XCTAssertEqual(inset, 16, accuracy: 2,
                        "\(selection.rawValue): \(button.accessibilityIdentifier ?? "") highlighted=\(highlighted), frame=\(content), alignment=\(button.contentHorizontalAlignment.rawValue), semantic=\(button.semanticContentAttribute.rawValue), effective=\(button.effectiveUserInterfaceLayoutDirection.rawValue)")
                }
            }
        }
        let remaining = descendants(detail.view).compactMap { $0 as? UIButton }
            .filter { $0.accessibilityIdentifier?.hasPrefix("language.") == true }
        XCTAssertEqual(remaining.map(ObjectIdentifier.init), identities)
    }
}
