import XCTest
import UIKit
@testable import UIKitLanguageDemo

final class IPadRestorationTests: XCTestCase {
    @MainActor
    func testVersionOneMigrationAndSessionOwnership() throws {
        let legacy: [String: Any] = ["version": 1, "identifier": UUID().uuidString, "selectedTab": 0,
            "stacks": [[ ["route": "home", "pageDrafts": [:]] ], [ ["route": "settings", "pageDrafts": [:]] ]],
            "split": ["primary": [["route": "splitMenu", "pageDrafts": [:]]],
                      "secondary": [["route": "detail", "draft": "old draft", "pageDrafts": [:]]], "showsSecondary": true]]
        let decoded = try XCTUnwrap(SceneStateCodec.decode(JSONSerialization.data(withJSONObject: legacy)))
        XCTAssertEqual(decoded.split?.style, .doubleColumn)
        XCTAssertEqual(decoded.split?.compactColumn, .secondary)
        XCTAssertEqual(decoded.split?.secondary.first?.draft, "old draft")
        var owned = decoded; owned.version = 2; owned.sceneSessionID = "scene-A"
        let a = try XCTUnwrap(SceneStateCodec.activity(for: owned))
        let foreign = try IPadWindowFixture(activity: a, sessionID: "scene-B")
        defer { foreign.close() }
        XCTAssertEqual(foreign.coordinator.restorationOrigin, "fresh")
        XCTAssertFalse(foreign.coordinator.restoreInteractionState(a))
        let copy = try XCTUnwrap(SceneStateCodec.activation(for: owned))
        XCTAssertNil(SceneStateCodec.decode(copy))
        XCTAssertNil(SceneStateCodec.decodeActivation(copy)?.sceneSessionID)
        let cloned = try IPadWindowFixture(sessionID: "scene-B", activation: copy)
        defer { cloned.close() }
        XCTAssertEqual(cloned.coordinator.restorationOrigin, "activation")
        XCTAssertEqual(SceneStateCodec.decode(try XCTUnwrap(cloned.coordinator.activity()))?.sceneSessionID, "scene-B")
        var invalid = owned
        invalid.split?.style = .tripleColumn
        XCTAssertNil(SceneStateCodec.activity(for: invalid), "Three-column snapshots require the middle stack")
        invalid = owned; invalid.split?.compactColumn = .supplementary
        XCTAssertNil(SceneStateCodec.activity(for: invalid), "Two-column snapshots cannot select a missing middle column")
    }

    @MainActor
    func testTripleColumnRestoresAllStacksAndPendingLists() throws {
        let old = try IPadWindowFixture(sessionID: "triple-scene")
        let split = ContainerDemos.makeSplit(style: .tripleColumn)
        (split.restorationPrimary?.topViewController as? SplitMenuViewController)?.draftField.text = "primary root"
        (split.restorationSupplementary?.topViewController as? SplitMenuViewController)?.draftField.text = "middle root"
        let detail = DetailViewController(); detail.draftField.text = "primary pushed"
        split.restorationPrimary?.pushViewController(detail, animated: false)
        let grid = CompositionalDemoViewController()
        let list = SavedListState(anchorID: 20, distance: -9, selectedIDs: [20], drafts: [20: "middle item"])
        grid.pendingListState = list; grid.drafts = list.drafts
        split.restorationSupplementary?.pushViewController(grid, animated: false)
        let pager = ContainerDemos.makePager(initialPageID: "page-3")
        (pager.restorationPages[2].controller as? DemoPageViewController)?.draft.text = "secondary page three"
        split.restorationSecondary?.pushViewController(pager, animated: false)
        old.coordinator.tabs.present(split, animated: false)
        old.window.layoutIfNeeded()
        split.selectColumn(.supplementary)
        split.setExpandedMode(.twoBesideSecondary)
        let activity = try XCTUnwrap(old.coordinator.activity())
        let saved = try XCTUnwrap(SceneStateCodec.decode(activity)?.split)
        XCTAssertEqual(saved.style, .tripleColumn)
        XCTAssertEqual(saved.supplementary?.count, 2)
        old.close()
        let restored = try IPadWindowFixture(activity: activity, sessionID: "triple-scene")
        defer { restored.close() }
        let actual = try XCTUnwrap(restored.coordinator.tabs.presentedViewController as? LocalizedSplitViewController)
        XCTAssertEqual(actual.style, .tripleColumn)
        XCTAssertEqual(actual.restorationCompactColumn, .supplementary)
        XCTAssertEqual(actual.restorationExpandedMode, .twoBesideSecondary)
        XCTAssertEqual(actual.restorationPrimary?.viewControllers.count, 2)
        XCTAssertEqual((actual.restorationPrimary?.viewControllers[0] as? SplitMenuViewController)?.draftField.text, "primary root")
        XCTAssertEqual((actual.restorationPrimary?.topViewController as? DetailViewController)?.draftField.text, "primary pushed")
        XCTAssertEqual((actual.restorationSupplementary?.viewControllers[0] as? SplitMenuViewController)?.draftField.text, "middle root")
        let middle = try XCTUnwrap(actual.restorationSupplementary?.topViewController as? CompositionalDemoViewController)
        XCTAssertEqual(middle.drafts[20], "middle item")
        let newPager = try XCTUnwrap(actual.restorationSecondary?.topViewController as? LocalizedPageContainerController)
        XCTAssertEqual(newPager.currentPageID, "page-3")
        XCTAssertEqual((newPager.restorationPages[2].controller as? DemoPageViewController)?.draft.text, "secondary page three")
        let newState = try XCTUnwrap(SceneStateCodec.decode(try XCTUnwrap(restored.coordinator.activity()))?.split)
        XCTAssertEqual(newState.supplementary?.last?.list?.anchorID, 20)
        XCTAssertEqual(newState.supplementary?.last?.list?.selectedIDs, [20])
    }

    @MainActor
    func testSplitActuallyCollapsesExpandsAndRestoresSidebarMode() async throws {
        guard #available(iOS 17.0, *), UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Trait override verification requires iPadOS 17+") }
        let fixture = try IPadWindowFixture(sessionID: "adaptive-scene")
        defer { fixture.close() }
        let split = ContainerDemos.makeSplit(style: .tripleColumn)
        fixture.coordinator.tabs.present(split, animated: false)
        fixture.window.layoutIfNeeded()
        XCTAssertFalse(split.isCollapsed)
        let identities = [split.restorationPrimary!, split.restorationSupplementary!, split.restorationSecondary!].map(ObjectIdentifier.init)
        split.selectColumn(.supplementary)
        split.traitOverrides.horizontalSizeClass = .compact
        try await waitFor { fixture.window.layoutIfNeeded(); return split.isCollapsed && split.transitionCoordinator == nil }
        XCTAssertEqual(split.restorationCompactColumn, .supplementary)
        XCTAssertEqual(split.restorationExpandedMode, .twoBesideSecondary)
        let compact = try XCTUnwrap(fixture.coordinator.activity())
        XCTAssertEqual(SceneStateCodec.decode(compact)?.split?.compactColumn, .supplementary)
        let compactRestored = try IPadWindowFixture(activity: compact, sessionID: "adaptive-scene", widthClass: .compact)
        let compactSplit = try XCTUnwrap(compactRestored.coordinator.tabs.presentedViewController as? LocalizedSplitViewController)
        try await waitFor { compactRestored.window.layoutIfNeeded(); return compactSplit.isCollapsed }
        XCTAssertEqual(compactSplit.restorationCompactColumn, .supplementary)
        if #available(iOS 26.0, *) { XCTAssertTrue(compactSplit.isShowing(.supplementary)) }
        compactRestored.close()
        split.traitOverrides.horizontalSizeClass = .regular
        try await waitFor { fixture.window.layoutIfNeeded(); return !split.isCollapsed && split.transitionCoordinator == nil }
        XCTAssertEqual([split.restorationPrimary!, split.restorationSupplementary!, split.restorationSecondary!].map(ObjectIdentifier.init), identities)
        XCTAssertEqual(split.restorationExpandedMode, .twoBesideSecondary)
        split.setExpandedMode(.secondaryOnly)
        try await waitFor { fixture.window.layoutIfNeeded(); return split.displayMode == .secondaryOnly }
        XCTAssertEqual(split.restorationCompactColumn, .supplementary)
        let activity = try XCTUnwrap(fixture.coordinator.activity())
        fixture.close()
        let restored = try IPadWindowFixture(activity: activity, sessionID: "adaptive-scene")
        defer { restored.close() }
        let actual = try XCTUnwrap(restored.coordinator.tabs.presentedViewController as? LocalizedSplitViewController)
        try await waitFor { restored.window.layoutIfNeeded(); return actual.displayMode == .secondaryOnly }
        XCTAssertEqual(actual.restorationExpandedMode, .secondaryOnly)
        XCTAssertEqual(actual.restorationCompactColumn, .supplementary, "Hiding sidebars must not erase the compact business selection")
        actual.setExpandedMode(.twoBesideSecondary)
        try await waitFor { restored.window.layoutIfNeeded(); return actual.displayMode == .twoBesideSecondary }
    }

    @MainActor
    func testTwoRealSceneSessionsRestoreIndependently() async throws {
        guard UIApplication.shared.supportsMultipleScenes else { throw XCTSkip("Requires iPad multi-window support") }
        let app = UIApplication.shared
        let first = try XCTUnwrap(app.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let a = try XCTUnwrap(first.delegate as? SceneDelegate)
        let original = try XCTUnwrap(a.restoration.activity())
        let window = try XCTUnwrap(a.window)
        let number = a.restoration.windowNumber
        let previousIDs = Set(app.openSessions.map(\.persistentIdentifier))
        var created: UISceneSession?
        defer {
            a.restoration.connect(window: window, activity: original, sessionID: first.session.persistentIdentifier, number: number)
            a.checkpoint(first)
            if let created { app.requestSceneSessionDestruction(created, options: nil) }
        }
        a.restoration.connect(window: window, activity: nil, sessionID: first.session.persistentIdentifier, number: number)
        let detail = DetailViewController(); detail.draftField.text = "window A draft"
        a.restoration.tabs.navigationControllers[0].pushViewController(detail, animated: false)
        let activityA = try XCTUnwrap(a.checkpoint(first))
        var copy = try XCTUnwrap(a.restoration.capture())
        copy.stacks[0][1].draft = "window B draft"
        var activationError: Error?
        SceneWindowService.requestNewWindow(copying: copy) { activationError = $0 }
        try await waitFor(timeout: 20) { app.connectedScenes.contains { !previousIDs.contains($0.session.persistentIdentifier) } }
        let second = try XCTUnwrap(app.connectedScenes.compactMap { $0 as? UIWindowScene }.first { !previousIDs.contains($0.session.persistentIdentifier) })
        created = second.session
        XCTAssertNil(activationError)
        let b = try XCTUnwrap(second.delegate as? SceneDelegate)
        XCTAssertEqual(b.restoration.restorationOrigin, "activation")
        let activityB = try XCTUnwrap(b.checkpoint(second))
        XCTAssertNotEqual(SceneStateCodec.decode(activityA)?.sceneSessionID, SceneStateCodec.decode(activityB)?.sceneSessionID)
        XCTAssertNotEqual(a.restoration.windowNumber, b.restoration.windowNumber)
        XCTAssertEqual(detail.draftField.text, "window A draft")
        XCTAssertEqual((b.restoration.tabs.navigationControllers[0].topViewController as? DetailViewController)?.draftField.text, "window B draft")
        a.restoration.connect(window: window, activity: activityA, sessionID: first.session.persistentIdentifier, number: number)
        b.restoration.connect(window: try XCTUnwrap(b.window), activity: activityB,
            sessionID: second.session.persistentIdentifier, number: b.restoration.windowNumber)
        XCTAssertEqual(a.restoration.restorationOrigin, "activity")
        XCTAssertEqual(b.restoration.restorationOrigin, "activity")
        XCTAssertEqual((a.restoration.tabs.navigationControllers[0].topViewController as? DetailViewController)?.draftField.text, "window A draft")
        XCTAssertEqual((b.restoration.tabs.navigationControllers[0].topViewController as? DetailViewController)?.draftField.text, "window B draft")
        XCTAssertFalse(a.restoration.restoreInteractionState(activityB))
        let attachment = XCTAttachment(string: "Actual UIScene sessions: A=\(first.session.persistentIdentifier), B=\(second.session.persistentIdentifier); independent NSUserActivity drafts restored")
        attachment.lifetime = .keepAlways; add(attachment)
        app.requestSceneSessionDestruction(second.session, options: nil)
        try await waitFor(timeout: 15) { !app.openSessions.contains { $0.persistentIdentifier == second.session.persistentIdentifier } }
        created = nil
    }

    @MainActor
    private func waitFor(timeout: TimeInterval = 5, _ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate(), Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertTrue(predicate(), "UIKit condition timed out")
    }
}

@MainActor
private final class IPadWindowFixture {
    let window: UIWindow
    let coordinator = SceneStateCoordinator()
    private let previous: UIWindow?
    private var closed = false
    init(activity: NSUserActivity? = nil, sessionID: String, activation: NSUserActivity? = nil, widthClass: UIUserInterfaceSizeClass? = nil) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        previous = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        if #available(iOS 17.0, *), let widthClass { window.traitOverrides.horizontalSizeClass = widthClass }
        coordinator.connect(window: window, activity: activity, sessionID: sessionID, activation: activation)
        window.layoutIfNeeded()
    }
    func close() {
        guard !closed else { return }; closed = true
        window.rootViewController?.dismiss(animated: false)
        LanguageService.shared.unregister(window: window)
        window.isHidden = true
        previous?.makeKeyAndVisible()
    }
}
