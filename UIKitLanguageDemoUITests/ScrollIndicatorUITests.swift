import XCTest

final class ScrollIndicatorUITests: XCTestCase {
    @MainActor
    func testVerticalIndicatorFollowsInterfaceTrailingEdgeAfterHotSwitch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        if let path = ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"] {
            app.launchEnvironment["DYLD_LIBRARY_PATH"] = path
        }
        app.launchArguments = ["-UITestResetRestoration", UUID().uuidString]
        app.launch()
        let settings = app.tabBars.buttons["tab.settings.title"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20)); settings.tap()
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 10))
        let original = ["system", "en", "zh-Hans", "ar"].first { app.buttons["language." + $0].isSelected }
        defer { if let original { app.buttons["language." + original].tap() } }
        for (language, rtl) in [("en", false), ("ar", true), ("zh-Hans", false), ("ar", true)] {
            app.buttons["language." + language].tap()
            table.swipeUp()
            try checkIndicator(in: table, app: app, language: language, rtl: rtl)
        }
    }
    @MainActor
    func testDetailIndicatorAfterHotSwitch() throws {
        try verifyPage(openID: "home.openDetail", collection: false)
    }

    @MainActor
    func testFlowCollectionIndicatorAfterHotSwitch() throws {
        try verifyPage(openID: "home.openCollection", collection: true)
    }

    @MainActor
    func testCompositionalOrthogonalOuterIndicatorAfterHotSwitch() throws {
        try verifyPage(openID: "home.openOrthogonal", collection: true)
    }

    @MainActor
    func testCompositionalGridIndicatorAfterHotSwitch() throws {
        try verifyPage(openID: "home.openCompositional", collection: true)
    }

    @MainActor
    private func verifyPage(openID: String, collection: Bool) throws {
        let app = XCUIApplication()
        if let path = ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"] { app.launchEnvironment["DYLD_LIBRARY_PATH"] = path }
        app.launchArguments = ["-UITestResetRestoration", UUID().uuidString]
        app.launch()
        let open = app.buttons[openID]
        XCTAssertTrue(open.waitForExistence(timeout: 20)); open.tap()
        let scroll = collection ? app.collectionViews.firstMatch : app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        let original = ["system", "en", "zh-Hans", "ar"].first { app.buttons["language." + $0].isSelected }
        defer { if let original { app.buttons["language." + original].tap() } }
        for (language, rtl) in [("en", false), ("ar", true), ("zh-Hans", false), ("ar", true)] {
            app.buttons["language." + language].tap()
            scroll.swipeUp()
            try checkIndicator(in: scroll, app: app, language: language, rtl: rtl)
        }
    }

    @MainActor
    func testRestoredArabicDetailIndicatorOnLaunch() throws {
        let app = XCUIApplication()
        if let path = ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"] { app.launchEnvironment["DYLD_LIBRARY_PATH"] = path }
        app.launchArguments = ["-UITestResetRestoration", UUID().uuidString]
        app.launch()
        let open = app.buttons["home.openDetail"]
        XCTAssertTrue(open.waitForExistence(timeout: 20)); open.tap()
        XCTAssertTrue(app.buttons["language.ar"].waitForExistence(timeout: 10))
        let original = ["system", "en", "zh-Hans", "ar"].first { app.buttons["language." + $0].isSelected }
        defer { if let original, app.buttons["language." + original].exists { app.buttons["language." + original].tap() } }
        app.buttons["language.ar"].tap()
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.terminate(); app.launch()
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(app.textFields["detail.draft"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["language.ar"].isSelected)
        scroll.swipeUp()
        try checkIndicator(in: scroll, app: app, language: "ar-restored", rtl: true)
    }

    @MainActor
    private func checkIndicator(in table: XCUIElement, app: XCUIApplication, language: String, rtl: Bool) throws {
        let candidates = table.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR label CONTAINS %@ OR label CONTAINS %@",
            "scroll bar", "滚动条", "شريط التمرير")).allElementsBoundByIndex
        let indicator = try XCTUnwrap(candidates.first {
            $0.frame.width <= 45 && $0.frame.height > 100 && $0.frame.height > $0.frame.width * 2
        }, "Native vertical indicator must be exposed in the AX tree: \(table.debugDescription)")
        let frame = indicator.frame
        let note = XCTAttachment(string: "\(language): table=\(table.frame), native indicator=\(frame), label=\(indicator.label)")
        note.name = "Scroll indicator geometry \(language)"
        note.lifetime = .keepAlways; add(note)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Scroll indicator \(language)"; shot.lifetime = .keepAlways; add(shot)
        let edge = rtl ? table.frame.minX : table.frame.maxX
        XCTAssertEqual(frame.midX, edge, accuracy: 25,
                       "Native indicator should stay at the physical \(rtl ? "left" : "right") edge: \(frame)")
    }
}
