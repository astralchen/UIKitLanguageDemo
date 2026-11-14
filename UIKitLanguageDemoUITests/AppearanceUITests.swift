import XCTest

final class AppearanceUITests: XCTestCase {
    @MainActor
    func testAppearanceChoiceSurvivesRelaunchAndArabicSwitchWithoutLosingDetail() {
        continueAfterFailure = false
        let app = XCUIApplication()
        if let path = ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"] {
            app.launchEnvironment["DYLD_LIBRARY_PATH"] = path
        }
        app.launchArguments = ["-UITestResetRestoration", UUID().uuidString]
        app.launch()
        let open = app.buttons["home.openDetail"]
        XCTAssertTrue(open.waitForExistence(timeout: 20)); open.tap()
        let detail = app.textFields["detail.draft"]
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        let originalLanguage = ["system", "en", "zh-Hans", "ar"].first { app.buttons["language." + $0].isSelected }
        app.buttons["language.en"].tap()
        XCTAssertTrue(app.navigationBars["Detail"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["tab.settings.title"].waitForExistence(timeout: 10))
        app.tabBars.buttons["tab.settings.title"].tap()
        let control = app.segmentedControls["appearance.selection"]
        XCTAssertTrue(control.waitForExistence(timeout: 10))
        let originalAppearance = ["System", "Light", "Dark"].first { control.buttons[$0].isSelected }
        defer {
            if control.exists {
                app.buttons["language.en"].tap()
                if let originalAppearance { control.buttons[originalAppearance].tap() }
                if let originalLanguage { app.buttons["language." + originalLanguage].tap() }
            }
        }
        control.buttons["Dark"].tap()
        XCTAssertTrue(control.buttons["Dark"].isSelected)
        capture("English dark settings", app)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(control.waitForExistence(timeout: 20))
        XCTAssertTrue(control.buttons["Dark"].isSelected, "Saved choice must survive process restart")
        app.buttons["language.ar"].tap()
        XCTAssertTrue(control.buttons["داكن"].isSelected)
        capture("Arabic dark settings", app)
        app.tabBars.buttons["tab.home.title"].tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "The original detail stack must survive appearance/language changes")
        capture("Arabic dark detail", app)
        app.tabBars.buttons["tab.settings.title"].tap()
        control.buttons["فاتح"].tap()
        XCTAssertTrue(control.buttons["فاتح"].isSelected)
        app.tabBars.buttons["tab.home.title"].tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        capture("Arabic light detail", app)
        app.tabBars.buttons["tab.settings.title"].tap()
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
