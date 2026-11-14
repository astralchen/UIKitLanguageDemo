import XCTest

final class UIKitLanguageDemoUITests: XCTestCase {
    @MainActor
    func testSystemSettingsLanguageRelaunchRestoresNavigationAndDraft() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        if let testingLibraries = ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"] {
            app.launchEnvironment["DYLD_LIBRARY_PATH"] = testingLibraries
        }
        app.launchArguments = ["-UITestResetRestoration", UUID().uuidString]
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        app.launch()
        var originalPreference: String?
        defer {
            app.activate()
            if app.buttons["system.language.settings"].waitForExistence(timeout: 10) {
                app.buttons["system.language.settings"].tap()
                if settings.wait(for: .runningForeground, timeout: 10), let originalPreference {
                    selectLanguage(in: settings, names: [originalPreference], requireTerminationOf: nil)
                    app.activate()
                }
            }
        }
        // Normalize this app's preference only; never change the simulator system language.
        let openSettings = app.buttons["system.language.settings"]
        XCTAssertTrue(openSettings.waitForExistence(timeout: 15))
        openSettings.tap()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 10))
        openLanguageList(in: settings)
        let selected = settings.cells.matching(NSPredicate(format: "identifier IN %@", ["English", "简体中文", "العربية"])).allElementsBoundByIndex.first { $0.isSelected }
        originalPreference = selected?.identifier
        XCTAssertNotNil(originalPreference, settings.debugDescription)
        selectLanguage(in: settings, names: ["English"], requireTerminationOf: nil)
        app.activate()
        let openDetail = app.buttons["home.openDetail"]
        XCTAssertTrue(openDetail.waitForExistence(timeout: 15))
        openDetail.tap()
        let draft = app.textFields["detail.draft"]
        XCTAssertTrue(draft.waitForExistence(timeout: 10))
        draft.tap()
        draft.typeText("Draft after system language relaunch")
        app.buttons["system.language.settings"].tap()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 10))
        selectLanguage(in: settings, names: ["العربية", "Arabic"], requireTerminationOf: app)
        app.activate()
        XCTAssertTrue(draft.waitForExistence(timeout: 20))
        XCTAssertEqual(draft.value as? String, "Draft after system language relaunch")
        XCTAssertTrue(app.navigationBars["التفاصيل"].waitForExistence(timeout: 10), "Native app language must now be Arabic")
        let source = app.windows.firstMatch.value as? String ?? "unavailable"
        XCTAssertEqual(source, "activity|ar", "UIKit must return this scene’s NSUserActivity")
        let evidence = XCTAttachment(string: "Restoration source and language: \(source)")
        evidence.lifetime = .keepAlways
        add(evidence)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Arabic detail after system-language restart"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let back = app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "رجوع")).firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(openDetail.waitForExistence(timeout: 10), "Back must return to the restored Home controller")

        // Verify an actual process restart from a scrolled self-sizing compositional grid.
        let openGrid = app.buttons["home.openCompositional"]
        if !openGrid.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(openGrid.waitForExistence(timeout: 5))
        openGrid.tap()
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        list.swipeUp()
        list.swipeUp()
        let editable = list.textFields.allElementsBoundByIndex.first { $0.isHittable }
        let field = try XCTUnwrap(editable)
        let fieldID = field.identifier
        field.tap()
        field.typeText("Saved list draft")
        let viewport = list.frame
        let visible = list.cells.allElementsBoundByIndex.filter { $0.frame.intersects(viewport) }
        let anchor = try XCTUnwrap(visible.sorted {
            if abs($0.frame.minY - $1.frame.minY) > 0.5 { return $0.frame.minY < $1.frame.minY }
            return $0.frame.maxX > $1.frame.maxX // Arabic logical leading edge.
        }.first)
        let anchorID = anchor.identifier
        XCTAssertTrue(anchorID.hasPrefix("list.cell."))
        let distance = anchor.frame.minY - list.frame.minY
        app.buttons["system.language.settings"].tap()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 10))
        selectLanguage(in: settings, names: ["English"], requireTerminationOf: app)
        app.activate()
        XCTAssertTrue(app.navigationBars["Compositional grid"].waitForExistence(timeout: 20))
        let restoredAnchor = list.cells[anchorID]
        XCTAssertTrue(restoredAnchor.waitForExistence(timeout: 10))
        XCTAssertEqual(restoredAnchor.frame.minY - list.frame.minY, distance, accuracy: 8,
            "Restore the business item and its distance from the viewport top after translation remeasurement")
        let restoredField = app.textFields[fieldID]
        XCTAssertTrue(restoredField.exists)
        XCTAssertEqual(restoredField.value as? String, "Saved list draft")
        XCTAssertEqual(app.windows.firstMatch.value as? String, "activity|en")
        let listEvidence = XCTAttachment(string: "NSUserActivity list restoration: \(anchorID), top distance before=\(distance), after=\(restoredAnchor.frame.minY - list.frame.minY), draft=Saved list draft")
        listEvidence.lifetime = .keepAlways
        add(listEvidence)
        let listImage = XCTAttachment(screenshot: app.screenshot())
        listImage.name = "Compositional grid after system-language restart"
        listImage.lifetime = .keepAlways
        add(listImage)

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
        for label in ["Change to Arabic", "Use Arabic", "Change to English", "Use English", "Continue", "更改为阿拉伯语", "使用阿拉伯语", "更改为英语", "使用英语", "继续"] {
            let button = settings.alerts.buttons[label].firstMatch
            if button.exists { button.tap(); break }
        }
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
        if !currentLanguageRow.exists, appEntry.waitForExistence(timeout: 3), appEntry.isHittable { appEntry.tap() }
        let language = settings.staticTexts.matching(NSPredicate(format: "label IN %@", ["Language", "语言", "اللغة"])).firstMatch
        XCTAssertTrue(language.waitForExistence(timeout: 12), settings.debugDescription)
        language.tap()
        XCTAssertTrue(settings.cells["العربية"].firstMatch.waitForExistence(timeout: 10), settings.debugDescription)
    }

}
