import XCTest

final class NavigationGestureUITests: XCTestCase {
    @MainActor
    func testBackGestureChangesFromRightEdgeInArabicToLeftEdgeInChinese() {
        continueAfterFailure = false
        let app = XCUIApplication()
        if let libraries = ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"] {
            app.launchEnvironment["DYLD_LIBRARY_PATH"] = libraries
        }
        app.launchArguments = ["-UITestResetRestoration", UUID().uuidString]
        app.launch()
        let open = app.buttons["home.openDetail"]
        XCTAssertTrue(open.waitForExistence(timeout: 20)); open.tap()
        let detail = app.textFields["detail.draft"]
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        let languageIDs = ["language.system", "language.en", "language.zh-Hans", "language.ar"]
        let originalLanguageID = languageIDs.first { app.buttons[$0].isSelected }
        defer {
            if let originalLanguageID {
                if !detail.exists, open.exists { open.tap() }
                if app.buttons[originalLanguageID].exists { app.buttons[originalLanguageID].tap() }
            }
        }
        let english = app.buttons["language.en"]
        XCTAssertTrue(english.waitForExistence(timeout: 10))
        app.buttons["language.zh-Hans"].tap()
        expectBackTitle("返回", in: app)
        // Backgrounding checkpoints the stack; reusing the reset token preserves
        // that state so Home is restored below Detail without loading its view.
        XCUIDevice.shared.press(.home)
        app.terminate()
        app.launch()
        XCTAssertTrue(detail.waitForExistence(timeout: 20))
        XCTAssertTrue(app.navigationBars["详情"].waitForExistence(timeout: 10))
        english.tap()
        expectBackTitle("Back", in: app)
        app.buttons["language.ar"].tap()
        expectBackTitle("رجوع", in: app)
        XCTAssertTrue(app.navigationBars["التفاصيل"].waitForExistence(timeout: 5))
        drag(in: app, from: 0.003, to: 0.85)
        XCTAssertTrue(detail.exists, "Arabic must not pop from the physical left edge")
        drag(in: app, from: 0.997, to: 0.15)
        expectPopped(detail)
        XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
        app.buttons["language.zh-Hans"].tap()
        expectBackTitle("返回", in: app)
        XCTAssertTrue(app.navigationBars["详情"].waitForExistence(timeout: 5))
        drag(in: app, from: 0.997, to: 0.15)
        XCTAssertTrue(detail.exists, "Chinese must not pop from the physical right edge")
        drag(in: app, from: 0.003, to: 0.85)
        expectPopped(detail)
        XCTAssertTrue(open.waitForExistence(timeout: 10))
    }

    @MainActor
    private func expectBackTitle(_ title: String, in app: XCUIApplication) {
        let button = app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Expected a visible localized Back title: \(title)")
    }

    @MainActor
    private func drag(in app: XCUIApplication, from x: CGFloat, to endX: CGFloat) {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.25))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: 0.25))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func expectPopped(_ detail: XCUIElement) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: detail)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed)
    }
}
