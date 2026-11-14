import XCTest
import UIKit

final class IPadWindowUITests: XCTestCase {
    @MainActor
    func testIPadTwoWindowsRestoreThreeColumnsAfterSystemLanguageRestart() throws {
        continueAfterFailure = false
        // Device capability is available in the runner before the app's AX server starts.
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Run on the existing iPad simulator")
        }
        let app = XCUIApplication()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        if let libraries = ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"] {
            app.launchEnvironment["DYLD_LIBRARY_PATH"] = libraries
        }
        app.launchArguments = ["-UITestResetRestoration", UUID().uuidString]
        app.terminate(); app.launch()
        var originalPreference: String?
        var otherNumber: Int?
        defer {
            app.activate()
            // Close only the disposable window this test created, preserving the original scene.
            let active = app.windows.matching(NSPredicate(format: "identifier BEGINSWITH %@", "scene.window.")).allElementsBoundByIndex.first { $0.buttons["scene.windows"].firstMatch.isHittable }
            if let active, let otherNumber {
                windowButton("scene.windows", in: active).tap()
                let switchButton = app.buttons.matching(NSPredicate(format: "label IN %@", windowNames(otherNumber))).firstMatch
                if switchButton.exists { switchButton.tap() }
                let other = app.windows["scene.window.\(otherNumber)"]
                if windowButton("scene.windows", in: other).waitForExistence(timeout: 5) {
                    windowButton("scene.windows", in: other).tap()
                    let close = app.buttons.matching(NSPredicate(format: "label IN %@", ["Close This Window", "关闭当前窗口", "إغلاق هذه النافذة"])).firstMatch
                    if close.exists {
                        close.tap()
                        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: other)
                        _ = XCTWaiter.wait(for: [gone], timeout: 10)
                    }
                }
            }
            let opener = app.buttons["system.language.settings"].firstMatch
            if opener.waitForExistence(timeout: 10), let originalPreference {
                opener.tap()
                if settings.wait(for: .runningForeground, timeout: 30) {
                    selectLanguage(in: settings, names: [originalPreference], requireTerminationOf: nil)
                    app.activate()
                }
            }
        }
        let opener = app.buttons["system.language.settings"].firstMatch
        XCTAssertTrue(opener.waitForExistence(timeout: 20))
        opener.tap()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 30))
        openLanguageList(in: settings)
        originalPreference = settings.cells.matching(NSPredicate(format: "identifier IN %@", ["English", "简体中文", "العربية"])).allElementsBoundByIndex.first { $0.isSelected }?.identifier
        XCTAssertNotNil(originalPreference)
        selectLanguage(in: settings, names: ["English"], requireTerminationOf: nil)
        app.activate()
        let triple = app.buttons["home.openTripleSplit"]
        XCTAssertTrue(triple.waitForExistence(timeout: 15))
        triple.tap()
        let a = app.windows.matching(NSPredicate(format: "identifier BEGINSWITH %@", "scene.window.")).firstMatch
        let aID = a.identifier
        let aNumber = try XCTUnwrap(Int(aID.split(separator: ".").last.map(String.init) ?? ""))
        for (id, text) in [("split.primary.draft", "primary A"), ("split.supplementary.draft", "middle A"), ("detail.draft", "detail A")] {
            let field = a.textFields[id]
            XCTAssertTrue(field.waitForExistence(timeout: 10), app.debugDescription)
            field.tap(); field.typeText(text)
        }
        windowButton("scene.windows", in: a).tap()
        app.buttons["New Window"].firstMatch.tap()
        let b = app.windows.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@", "scene.window.", aID)).firstMatch
        XCTAssertTrue(b.waitForExistence(timeout: 25), app.debugDescription)
        let bID = b.identifier
        let bNumber = try XCTUnwrap(Int(bID.split(separator: ".").last.map(String.init) ?? ""))
        otherNumber = bNumber
        let bDraft = b.textFields["detail.draft"]
        XCTAssertTrue(bDraft.waitForExistence(timeout: 10))
        XCTAssertEqual(bDraft.value as? String, "detail A", "The new window must copy the complete three-column business state")
        bDraft.tap()
        bDraft.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "detail A".count) + "detail B")
        windowButton("system.language.settings", in: b).tap()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 30))
        selectLanguage(in: settings, names: ["العربية", "Arabic"], requireTerminationOf: app)
        app.activate()
        XCTAssertTrue(bDraft.waitForExistence(timeout: 20))
        XCTAssertEqual(bDraft.value as? String, "detail B")
        XCTAssertEqual(b.value as? String, "activity|ar")
        windowButton("scene.windows", in: b).tap()
        let switchA = app.buttons.matching(NSPredicate(format: "label IN %@", windowNames(aNumber))).firstMatch
        XCTAssertTrue(switchA.waitForExistence(timeout: 10), app.debugDescription)
        switchA.tap()
        XCTAssertTrue(a.textFields["split.primary.draft"].waitForExistence(timeout: 20))
        XCTAssertEqual(a.textFields["split.primary.draft"].value as? String, "primary A")
        XCTAssertEqual(a.textFields["split.supplementary.draft"].value as? String, "middle A")
        XCTAssertEqual(a.textFields["detail.draft"].value as? String, "detail A", "Window B must never overwrite window A")
        XCTAssertEqual(a.value as? String, "activity|ar")
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "iPad three columns and independent windows after native language restart"
        image.lifetime = .keepAlways; add(image)
        let text = XCTAttachment(string: "Two native scene sessions restored after OS language termination: \(aID)=primary A/middle A/detail A, \(bID)=detail B; both sources activity|ar")
        text.lifetime = .keepAlways; add(text)
    }

    @MainActor
    private func windowButton(_ id: String, in window: XCUIElement) -> XCUIElement {
        window.buttons.matching(identifier: id).allElementsBoundByIndex.first { $0.isHittable } ?? window.buttons[id].firstMatch
    }

    private func windowNames(_ number: Int) -> [String] {
        [String(format: "Window %d", locale: Locale(identifier: "en"), arguments: [number]),
         String(format: "窗口 %d", locale: Locale(identifier: "zh-Hans"), arguments: [number]),
         String(format: "النافذة %d", locale: Locale(identifier: "ar"), arguments: [number])]
    }

    @MainActor
    private func selectLanguage(in settings: XCUIApplication, names: [String], requireTerminationOf app: XCUIApplication?) {
        openLanguageList(in: settings)
        var target: XCUIElement?
        for name in names {
            let item = settings.staticTexts[name].firstMatch
            if item.waitForExistence(timeout: 3) { target = item; break }
        }
        XCTAssertNotNil(target, settings.debugDescription)
        target?.tap()
        // One scoped query avoids ten separate full AX snapshots when no alert is shown.
        let confirmation = settings.alerts.buttons.matching(
            NSPredicate(format: "label IN %@", ["Change to Arabic", "Use Arabic", "Change to English", "Use English", "Continue", "更改为阿拉伯语", "使用阿拉伯语", "更改为英语", "使用英语", "继续"])).firstMatch
        if confirmation.exists { confirmation.tap() }
        if let app {
            let stopped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "state == %d", XCUIApplication.State.notRunning.rawValue), object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: 15), .completed,
                "A real Settings language change must terminate the previous process")
        }
    }
    @MainActor
    private func openLanguageList(in settings: XCUIApplication) {
        if settings.cells["العربية"].firstMatch.exists { return }
        // iPadOS may open the Apps directory before the app-specific preferences page.
        let appEntry = settings.buttons["com.example.UIKitLanguageDemo"].firstMatch
        let currentLanguageRow = settings.staticTexts.matching(NSPredicate(format: "label IN %@", ["Language", "语言", "اللغة"])).firstMatch
        // The Apps directory is populated asynchronously. Wait for either destination,
        // instead of assuming its app entry is ready within three seconds.
        let destination = settings.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == %@ OR label IN %@", "com.example.UIKitLanguageDemo",
            ["Language", "语言", "اللغة"])).firstMatch
        XCTAssertTrue(destination.waitForExistence(timeout: 30), settings.debugDescription)
        if !currentLanguageRow.exists { appEntry.tap() }
        let language = settings.staticTexts.matching(NSPredicate(format: "label IN %@", ["Language", "语言", "اللغة"])).firstMatch
        XCTAssertTrue(language.waitForExistence(timeout: 30), settings.debugDescription)
        language.tap()
        XCTAssertTrue(settings.cells["العربية"].firstMatch.waitForExistence(timeout: 10), settings.debugDescription)
    }

}
