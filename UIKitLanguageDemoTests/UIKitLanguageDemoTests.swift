import XCTest
import UIKit
@testable import UIKitLanguageDemo

final class LanguageTests: XCTestCase {
    @MainActor
    func testLanguageSwitchPreservesNavigationAndDraft() throws {
        let service = LanguageService.shared
        let originalSelection = service.selection
        service.setSelection(.english)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let home = HomeViewController()
        let navigation = LocalizedNavigationController(root: home, tabTitleKey: "home.title", symbol: "house")
        let settings = LocalizedNavigationController(root: SettingsViewController(), tabTitleKey: "settings.title", symbol: "gearshape")
        let tabs = LocalizedTabBarController(navigationControllers: [navigation, settings])
        let host = LocalizationHostController(content: tabs)
        window.rootViewController = host
        service.register(window: window)
        window.makeKeyAndVisible()
        host.loadViewIfNeeded()
        tabs.loadViewIfNeeded()
        tabs.selectedIndex = 0
        home.loadViewIfNeeded()
        let detail = DetailViewController()
        navigation.pushViewController(detail, animated: false)
        detail.loadViewIfNeeded()
        detail.draftField.text = "Draft remains 123"
        // Keyboard startup can block in unattended simulator sessions. Enable
        // VERIFY_KEYBOARD_FOCUS=1 in the test Scheme for the focused-input run.
        let hadFocus = ProcessInfo.processInfo.environment["VERIFY_KEYBOARD_FOCUS"] == "1"
            && detail.draftField.becomeFirstResponder()
        window.layoutIfNeeded()
        if hadFocus {
            let start = detail.draftField.position(from: detail.draftField.beginningOfDocument, offset: 3)!
            detail.draftField.selectedTextRange = detail.draftField.textRange(from: start, to: start)
        }
        let stackIDs = navigation.viewControllers.map(ObjectIdentifier.init)
        defer {
            service.unregister(window: window)
            window.isHidden = true
            service.setSelection(originalSelection)
            previousKeyWindow?.makeKeyAndVisible()
        }

        for selection in [LanguageSelection.simplifiedChinese, .arabic, .english] {
            service.setSelection(selection)
            window.layoutIfNeeded()
            XCTAssertTrue(window.rootViewController === host)
            XCTAssertTrue(navigation.topViewController === detail)
            XCTAssertEqual(navigation.viewControllers.map(ObjectIdentifier.init), stackIDs)
            XCTAssertEqual(tabs.selectedIndex, 0)
            XCTAssertEqual(detail.draftField.text, "Draft remains 123")
            if hadFocus {
                XCTAssertTrue(detail.draftField.isFirstResponder)
                let selectedRange = try XCTUnwrap(detail.draftField.selectedTextRange)
                XCTAssertEqual(detail.draftField.offset(from: detail.draftField.beginningOfDocument,
                                                       to: selectedRange.start), 3, "Selection: \(selection.rawValue)")
            }
            XCTAssertEqual(detail.title, service.context.text("detail.title"))
            XCTAssertEqual(home.title, service.context.text("home.title"))
            XCTAssertEqual(navigation.navigationBar.effectiveUserInterfaceLayoutDirection,
                           service.context.isRTL ? .rightToLeft : .leftToRight)
            if #available(iOS 18.0, *) {
                XCTAssertEqual(tabs.tabs.map(\.title), [service.context.text("home.title"), service.context.text("settings.title")])
            }
        }
    }

    @MainActor
    func testSelectionPersistsAndMissingKeysHaveFallback() throws {
        let name = "UIKitLanguageDemo.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let service = LanguageService(defaults: defaults)
        service.setSelection(.arabic)
        let restored = LanguageService(defaults: defaults)
        XCTAssertEqual(restored.selection, .arabic)
        XCTAssertEqual(restored.context.text("detail.title"), "التفاصيل")
        XCTAssertEqual(restored.context.text("fallback.example"), "English fallback")
        XCTAssertEqual(restored.context.text("unknown.key"), "unknown.key")
        XCTAssertEqual(LanguageResources.resolve(.system, preferences: ["ar-SA", "en"]), .arabic)
        XCTAssertEqual(LanguageResources.resolve(.simplifiedChinese, preferences: ["ar"]), .simplifiedChinese)
    }

    @MainActor
    func testExistingModalSurvivesSwitch() throws {
        let service = LanguageService.shared
        let original = service.selection
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = try XCTUnwrap(scene.windows.first(where: \.isKeyWindow))
        let host = try XCTUnwrap(window.rootViewController)
        let sheet = LocalizedTestSheet()
        let presented = expectation(description: "sheet presented")
        host.present(sheet, animated: false) { presented.fulfill() }
        wait(for: [presented], timeout: 5)
        service.setSelection(.arabic)
        XCTAssertTrue(host.presentedViewController === sheet)
        XCTAssertEqual(sheet.title, service.context.text("detail.title"))
        sheet.dismiss(animated: false)
        service.setSelection(original)
    }

    @MainActor
    func testSplitPreservesColumnsAndTheirNavigationStacks() throws {
        let split = LocalizedSplitViewController(style: .tripleColumn)
        split.preferredDisplayMode = .twoBesideSecondary
        split.minimumPrimaryColumnWidth = 180
        split.maximumPrimaryColumnWidth = 220
        split.minimumSupplementaryColumnWidth = 180
        split.maximumSupplementaryColumnWidth = 220
        let columns: [UISplitViewController.Column] = [.primary, .supplementary, .secondary]
        let navigations = columns.map { _ in
            LocalizedNavigationController(root: HomeViewController(), tabTitleKey: "home.title", symbol: "house")
        }
        for (column, navigation) in zip(columns, navigations) {
            split.setViewController(navigation, for: column)
            navigation.pushViewController(DetailViewController(), animated: false)
        }
        let fixture = try ContainerTestWindow(content: split)
        defer { fixture.close() }
        fixture.window.layoutIfNeeded()
        let identifiers = navigations.map { $0.viewControllers.map(ObjectIdentifier.init) }
        let displayMode = split.displayMode
        let preferredMode = split.preferredDisplayMode
        let collapsed = split.isCollapsed

        for selection in [LanguageSelection.arabic, .simplifiedChinese] {
            LanguageService.shared.setSelection(selection)
            fixture.window.layoutIfNeeded()
            XCTAssertEqual(split.primaryEdge, .leading)
            XCTAssertEqual(split.displayMode, displayMode)
            XCTAssertEqual(split.preferredDisplayMode, preferredMode)
            XCTAssertEqual(split.isCollapsed, collapsed)
            for (index, column) in columns.enumerated() {
                XCTAssertTrue(split.viewController(for: column) === navigations[index])
                XCTAssertEqual(navigations[index].viewControllers.map(ObjectIdentifier.init), identifiers[index])
            }
            if !split.isCollapsed, split.displayMode == .twoBesideSecondary {
                let primaryFrame = navigations[0].view.convert(navigations[0].view.bounds, to: split.view)
                let secondaryFrame = navigations[2].view.convert(navigations[2].view.bounds, to: split.view)
                if LanguageService.shared.context.isRTL {
                    XCTAssertGreaterThan(primaryFrame.midX, secondaryFrame.midX)
                } else {
                    XCTAssertLessThan(primaryFrame.midX, secondaryFrame.midX)
                }
            }
        }
    }

    @MainActor
    func testPagerPreservesPageAndReversesPhysicalNeighbors() throws {
        let pages = (1...3).map { _ in DetailViewController() }
        let pager = LocalizedPageContainerController(pages: pages.enumerated().map {
            .init(id: "page-\($0.offset)", controller: $0.element)
        }, initialPageID: "page-1")
        let fixture = try ContainerTestWindow(content: pager)
        defer { fixture.close() }
        let engine = pager.pageViewController
        let visible = try XCTUnwrap(engine.viewControllers?.first)
        pages[1].draftField.text = "Keep middle page"
        let firstBefore = try XCTUnwrap(engine.dataSource?.pageViewController(engine, viewControllerBefore: visible))
        let firstAfter = try XCTUnwrap(engine.dataSource?.pageViewController(engine, viewControllerAfter: visible))

        LanguageService.shared.setSelection(.arabic)
        fixture.window.layoutIfNeeded()
        XCTAssertTrue(pager.pageViewController === engine)
        XCTAssertTrue(engine.viewControllers?.first === visible)
        XCTAssertTrue(pager.displayedContentController === pages[1])
        XCTAssertEqual(pager.currentPageID, "page-1")
        XCTAssertEqual(pages[1].draftField.text, "Keep middle page")
        XCTAssertTrue(engine.dataSource?.pageViewController(engine, viewControllerBefore: visible) === firstAfter)
        XCTAssertTrue(engine.dataSource?.pageViewController(engine, viewControllerAfter: visible) === firstBefore)
        XCTAssertEqual(pages[1].view.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        XCTAssertEqual(engine.view.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertGreaterThan(engine.view.bounds.width, 0)
        XCTAssertEqual(engine.view.bounds.width, pager.view.bounds.width, accuracy: 1)

        XCTAssertTrue(pager.nextPage(animated: false))
        XCTAssertEqual(pager.currentPageID, "page-2")
        XCTAssertTrue(pager.displayedContentController === pages[2])
        XCTAssertFalse(pager.nextPage(animated: false))
        XCTAssertTrue(pager.previousPage(animated: false))
        XCTAssertTrue(pager.displayedContentController === pages[1])
        XCTAssertEqual(pages[1].draftField.text, "Keep middle page")
    }

    @MainActor
    func testPagerDefersAdjacencyChangeUntilCancelledSwipeEnds() throws {
        let pager = LocalizedPageContainerController(pages: (0...2).map {
            .init(id: "page-\($0)", controller: DetailViewController())
        }, initialPageID: "page-1")
        let fixture = try ContainerTestWindow(content: pager)
        defer { fixture.close() }
        let engine = pager.pageViewController
        let visible = try XCTUnwrap(engine.viewControllers?.first)
        let pending = try XCTUnwrap(engine.dataSource?.pageViewController(engine, viewControllerAfter: visible))
        // Exercise the same delegate path as an interactive swipe cancellation.
        pager.pageViewController(engine, willTransitionTo: [pending])
        LanguageService.shared.setSelection(.arabic)
        LanguageService.shared.setSelection(.simplifiedChinese)
        LanguageService.shared.setSelection(.arabic)
        XCTAssertFalse(pager.nextPage(animated: false))
        XCTAssertTrue(engine.dataSource?.pageViewController(engine, viewControllerAfter: visible) === pending)
        pager.pageViewController(engine, didFinishAnimating: true,
                                 previousViewControllers: [visible], transitionCompleted: false)
        XCTAssertEqual(pager.currentPageID, "page-1")
        XCTAssertTrue(engine.viewControllers?.first === visible)
        XCTAssertTrue(engine.dataSource?.pageViewController(engine, viewControllerBefore: visible) === pending)
    }
    @MainActor
    func testTableRefreshPreservesCellDraftSelectionAndUpdatesHeight() throws {
        let page = SettingsViewController()
        let fixture = try ContainerTestWindow(content: page)
        defer { fixture.close() }
        let table = page.tableView
        table.layoutIfNeeded()
        let path = IndexPath(row: 0, section: 0)
        let cell = try XCTUnwrap(table.cellForRow(at: path) as? DemoTableCell)
        let oldHeight = table.rectForRow(at: path).height
        cell.localizedContent.draft.text = "table draft survives"
        cell.localizedContent.draft.sendActions(for: .editingChanged)
        table.selectRow(at: path, animated: false, scrollPosition: .none)
        LanguageService.shared.setSelection(.arabic)
        fixture.window.layoutIfNeeded()
        XCTAssertTrue(table.cellForRow(at: path) === cell)
        XCTAssertEqual(cell.localizedContent.draft.text, "table draft survives")
        XCTAssertTrue(table.indexPathsForSelectedRows?.contains(path) == true)
        XCTAssertEqual(cell.localizedContent.heading.text, LanguageService.shared.context.format("list.item", 1))
        XCTAssertGreaterThan(table.rectForRow(at: path).height, oldHeight)
        let header = try XCTUnwrap(table.headerView(forSection: 0))
        XCTAssertEqual((header.contentConfiguration as? UIListContentConfiguration)?.text,
                       LanguageService.shared.context.text("list.section"))
        XCTAssertEqual(table.effectiveUserInterfaceLayoutDirection, .rightToLeft)
    }

    @MainActor
    func testTableKeepsReadingAnchorAndRefreshesReusedRows() throws {
        let page = SettingsViewController()
        let fixture = try ContainerTestWindow(content: page)
        defer { fixture.close() }
        let table = page.tableView
        table.scrollToRow(at: IndexPath(row: 30, section: 0), at: .top, animated: false)
        table.layoutIfNeeded()
        let anchor = try XCTUnwrap(table.indexPathsForVisibleRows?.min())
        let delta = table.rectForRow(at: anchor).minY - table.contentOffset.y - table.adjustedContentInset.top
        let selected = IndexPath(row: anchor.row + 1, section: 0)
        table.selectRow(at: selected, animated: false, scrollPosition: .none)
        for language in [LanguageSelection.arabic, .simplifiedChinese, .english] {
            LanguageService.shared.setSelection(language)
            fixture.window.layoutIfNeeded()
            let newDelta = table.rectForRow(at: anchor).minY - table.contentOffset.y - table.adjustedContentInset.top
            XCTAssertEqual(newDelta, delta, accuracy: 2)
            XCTAssertTrue(table.indexPathsForSelectedRows?.contains(selected) == true)
        }
        LanguageService.shared.setSelection(.arabic)
        let last = IndexPath(row: 79, section: 0)
        table.scrollToRow(at: last, at: .bottom, animated: false)
        table.layoutIfNeeded()
        let lastCell = try XCTUnwrap(table.cellForRow(at: last) as? DemoTableCell)
        XCTAssertEqual(lastCell.localizedContent.heading.text, LanguageService.shared.context.format("list.item", 80))
        lastCell.localizedContent.draft.text = "saved by stable ID"
        lastCell.localizedContent.draft.sendActions(for: .editingChanged)
        table.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
        table.layoutIfNeeded()
        table.scrollToRow(at: last, at: .bottom, animated: false)
        table.layoutIfNeeded()
        XCTAssertEqual((table.cellForRow(at: last) as? DemoTableCell)?.localizedContent.draft.text, "saved by stable ID")
    }

    @MainActor
    func testCollectionGridMirrorsAndPreservesSelectionDraftAndAnchor() throws {
        let page = CollectionDemoViewController()
        let fixture = try ContainerTestWindow(content: page)
        defer { fixture.close() }
        let collection = page.collectionView
        collection.layoutIfNeeded()
        let first = IndexPath(item: 0, section: 0)
        let second = IndexPath(item: 1, section: 0)
        let cell = try XCTUnwrap(collection.cellForItem(at: first) as? DemoCollectionCell)
        let other = try XCTUnwrap(collection.cellForItem(at: second))
        XCTAssertLessThan(cell.frame.minX, other.frame.minX)
        cell.localizedContent.draft.text = "collection draft survives"
        cell.localizedContent.draft.sendActions(for: .editingChanged)
        collection.selectItem(at: first, animated: false, scrollPosition: [])
        LanguageService.shared.setSelection(.arabic)
        fixture.window.layoutIfNeeded()
        let current = try XCTUnwrap(collection.cellForItem(at: first) as? DemoCollectionCell)
        XCTAssertEqual(current.localizedContent.draft.text, "collection draft survives")
        XCTAssertTrue(collection.indexPathsForSelectedItems?.contains(first) == true)
        XCTAssertGreaterThan(current.frame.minX, try XCTUnwrap(collection.cellForItem(at: second)).frame.minX)
        let header = try XCTUnwrap(collection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader).first as? DemoCollectionHeader)
        XCTAssertEqual(header.label.text, LanguageService.shared.context.text("list.section"))
        let anchor = IndexPath(item: 40, section: 0)
        collection.scrollToItem(at: anchor, at: .top, animated: false)
        collection.layoutIfNeeded()
        let oldFrame = try XCTUnwrap(collection.cellForItem(at: anchor)).frame
        let delta = oldFrame.minY - collection.contentOffset.y - collection.adjustedContentInset.top
        for language in [LanguageSelection.simplifiedChinese, .english, .arabic] {
            LanguageService.shared.setSelection(language)
            fixture.window.layoutIfNeeded()
            let frame = try XCTUnwrap(collection.cellForItem(at: anchor)).frame
            XCTAssertEqual(frame.minY - collection.contentOffset.y - collection.adjustedContentInset.top, delta, accuracy: 2)
            let visibleCell = try XCTUnwrap(collection.cellForItem(at: anchor) as? DemoCollectionCell)
            XCTAssertEqual(visibleCell.localizedContent.heading.text, LanguageService.shared.context.format("list.item", 41))
        }
    }

    @MainActor
    func testHorizontalCollectionKeepsLogicalLeadingItemAcrossRTL() throws {
        let page = CollectionDemoViewController(axis: .horizontal)
        let fixture = try ContainerTestWindow(content: page)
        defer { fixture.close() }
        let collection = page.collectionView
        let path = IndexPath(item: 25, section: 0)
        collection.scrollToItem(at: path, at: .left, animated: false)
        collection.layoutIfNeeded()
        let frame = try XCTUnwrap(collection.cellForItem(at: path)).frame
        let delta = frame.minX - collection.contentOffset.x - collection.adjustedContentInset.left
        collection.selectItem(at: path, animated: false, scrollPosition: [])
        let originalIDs = page.itemIDs
        for language in [LanguageSelection.arabic, .simplifiedChinese, .english] {
            LanguageService.shared.setSelection(language)
            fixture.window.layoutIfNeeded()
            let cell = try XCTUnwrap(collection.cellForItem(at: path) as? DemoCollectionCell)
            let leadingDelta: CGFloat
            if LanguageService.shared.context.isRTL {
                leadingDelta = collection.contentOffset.x + collection.bounds.width
                    - collection.adjustedContentInset.right - cell.frame.maxX
            } else {
                leadingDelta = cell.frame.minX - collection.contentOffset.x - collection.adjustedContentInset.left
            }
            XCTAssertEqual(leadingDelta, delta, accuracy: 2)
            XCTAssertEqual(cell.localizedContent.itemID, 25)
            XCTAssertEqual(page.itemIDs, originalIDs)
            XCTAssertTrue(collection.indexPathsForSelectedItems?.contains(path) == true)
        }
    }

    @MainActor
    func testCompositionalGridPreservesDraftSelectionAndReadingAnchor() throws {
        let page = CompositionalDemoViewController()
        let previous = UIViewController()
        let navigation = UINavigationController(rootViewController: previous)
        navigation.pushViewController(page, animated: false)
        let fixture = try ContainerTestWindow(content: navigation)
        defer { fixture.close() }
        let collection = page.collectionView
        let layout = collection.collectionViewLayout
        XCTAssertTrue(layout is UICollectionViewCompositionalLayout)
        let path = IndexPath(item: 30, section: 0)
        collection.scrollToItem(at: path, at: .top, animated: false)
        collection.layoutIfNeeded()
        let first = try XCTUnwrap(collection.cellForItem(at: path) as? DemoCollectionCell)
        first.localizedContent.draft.text = "compositional draft"
        first.localizedContent.draft.sendActions(for: .editingChanged)
        collection.selectItem(at: path, animated: false, scrollPosition: [])
        let englishHeight = first.frame.height
        let distance = first.frame.minY - collection.contentOffset.y - collection.adjustedContentInset.top
        for language in [LanguageSelection.arabic, .simplifiedChinese, .english] {
            LanguageService.shared.setSelection(language)
            fixture.window.layoutIfNeeded()
            let cell = try XCTUnwrap(collection.cellForItem(at: path) as? DemoCollectionCell)
            XCTAssertEqual(cell.localizedContent.draft.text, "compositional draft")
            XCTAssertEqual(cell.localizedContent.heading.text, LanguageService.shared.context.format("list.item", 31))
            XCTAssertTrue(collection.indexPathsForSelectedItems?.contains(path) == true)
            XCTAssertEqual(cell.frame.minY - collection.contentOffset.y - collection.adjustedContentInset.top, distance, accuracy: 2)
            let other = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 31, section: 0)))
            if LanguageService.shared.context.isRTL {
                XCTAssertGreaterThan(cell.convert(cell.bounds, to: fixture.window).minX, other.convert(other.bounds, to: fixture.window).minX)
                XCTAssertGreaterThan(cell.frame.height, englishHeight)
            }
            else { XCTAssertLessThan(cell.convert(cell.bounds, to: fixture.window).minX, other.convert(other.bounds, to: fixture.window).minX) }
            XCTAssertTrue(collection.collectionViewLayout is UICollectionViewCompositionalLayout)
            XCTAssertTrue(page.collectionView === collection)
            XCTAssertTrue(navigation.topViewController === page)
            XCTAssertTrue(navigation.viewControllers.first === previous)
            XCTAssertEqual(navigation.viewControllers.count, 2)
        }
        collection.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: false)
        collection.layoutIfNeeded()
        collection.setContentOffset(CGPoint(x: 0, y: -collection.adjustedContentInset.top), animated: false)
        collection.layoutIfNeeded()
        let header = try XCTUnwrap(collection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader).first as? DemoCollectionHeader)
        XCTAssertEqual(header.label.text, LanguageService.shared.context.text("compositional.grid_section"))
    }

    @MainActor
    func testCompositionalOrthogonalSectionPreservesBusinessPageAndOuterAnchor() throws {
        let page = CompositionalDemoViewController(mode: .orthogonal)
        let fixture = try ContainerTestWindow(content: page)
        defer { fixture.close() }
        let collection = page.collectionView
        let carouselPath = IndexPath(item: 12, section: 0)
        collection.scrollToItem(at: carouselPath, at: .centeredHorizontally, animated: false)
        collection.layoutIfNeeded()
        let first = try XCTUnwrap(collection.cellForItem(at: carouselPath) as? DemoCollectionCell)
        first.localizedContent.draft.text = "carousel draft"
        first.localizedContent.draft.sendActions(for: .editingChanged)
        collection.selectItem(at: carouselPath, animated: false, scrollPosition: [])
        for language in [LanguageSelection.arabic, .simplifiedChinese, .english] {
            LanguageService.shared.setSelection(language)
            fixture.window.layoutIfNeeded()
            let cell = try XCTUnwrap(collection.cellForItem(at: carouselPath) as? DemoCollectionCell)
            let frame = cell.convert(cell.bounds, to: collection)
            XCTAssertEqual(frame.midX, collection.bounds.midX, accuracy: 2)
            let neighbor = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 13, section: 0)))
            let nextX = neighbor.convert(neighbor.bounds, to: fixture.window).midX
            let currentX = cell.convert(cell.bounds, to: fixture.window).midX
            if LanguageService.shared.context.isRTL { XCTAssertLessThan(nextX, currentX) }
            else { XCTAssertGreaterThan(nextX, currentX) }
            XCTAssertEqual(page.orthogonalLocalization?.observedCenters[0], AnyHashable(12))
            XCTAssertEqual(cell.localizedContent.draft.text, "carousel draft")
            XCTAssertEqual(cell.localizedContent.heading.text, LanguageService.shared.context.format("list.item", 13))
            XCTAssertTrue(collection.indexPathsForSelectedItems?.contains(carouselPath) == true)
            XCTAssertEqual(collection.contentOffset.y, 0, accuracy: 2)
            XCTAssertTrue(collection.collectionViewLayout is UICollectionViewCompositionalLayout)
            XCTAssertTrue(page.collectionView === collection)
        }
        // A hidden orthogonal section must not pull the outer grid back to the top.
        let gridPath = IndexPath(item: 30, section: 1)
        collection.scrollToItem(at: gridPath, at: .top, animated: false)
        collection.layoutIfNeeded()
        let gridCell = try XCTUnwrap(collection.cellForItem(at: gridPath))
        let distance = gridCell.frame.minY - collection.contentOffset.y - collection.adjustedContentInset.top
        LanguageService.shared.setSelection(.arabic)
        fixture.window.layoutIfNeeded()
        let restored = try XCTUnwrap(collection.cellForItem(at: gridPath))
        XCTAssertEqual(restored.frame.minY - collection.contentOffset.y - collection.adjustedContentInset.top, distance, accuracy: 2)
        collection.setContentOffset(.zero, animated: false)
        collection.layoutIfNeeded()
        let returned = try XCTUnwrap(collection.cellForItem(at: carouselPath) as? DemoCollectionCell)
        XCTAssertEqual(returned.convert(returned.bounds, to: collection).midX, collection.bounds.midX, accuracy: 2)
        XCTAssertEqual(returned.localizedContent.draft.text, "carousel draft")
    }


    @MainActor
    func testSystemSelectionUsesAppBundlePreferences() throws {
        let name = "UIKitLanguageDemo.system.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var appPreferences = ["ar"]
        let service = LanguageService(defaults: defaults, preferredLocalizations: { appPreferences })
        XCTAssertEqual(service.selection, .system)
        XCTAssertEqual(service.context.language, .arabic)

        appPreferences = ["zh-Hans"]
        service.setSelection(.english)
        XCTAssertEqual(service.context.language, .english, "An explicit content selection still takes precedence")
        service.setSelection(.system)
        XCTAssertEqual(service.context.language, .simplifiedChinese)

        appPreferences = ["ar"]
        service.setSelection(.system)
        XCTAssertEqual(service.context.language, .arabic, "Re-read app preferences even when selection is unchanged")
        let restored = LanguageService(defaults: defaults, preferredLocalizations: { ["zh-Hans"] })
        XCTAssertEqual(restored.selection, .system)
        XCTAssertEqual(restored.context.language, .simplifiedChinese)
        let native = LanguageService(defaults: defaults)
        XCTAssertEqual(native.context.language,
            LanguageResources.resolve(.system, preferences: Bundle.main.preferredLocalizations))
    }

    @MainActor
    func testActivityRestoresNavigationPagerDraftsAndTableAnchor() throws {
        let original = LanguageService.shared.selection
        defer { LanguageService.shared.setSelection(original) }
        LanguageService.shared.setSelection(.english)
        let old = try RestoredSceneHarness()
        let first = old.coordinator.tabs.navigationControllers[0]
        let detail = DetailViewController()
        detail.draftField.text = "detail survives relaunch"
        let pager = ContainerDemos.makePager(initialPageID: "page-3")
        (pager.restorationPages[0].controller as? DemoPageViewController)?.draft.text = "page one draft"
        (pager.restorationPages[2].controller as? DemoPageViewController)?.draft.text = "page three draft"
        first.setViewControllers([first.viewControllers[0], detail, pager], animated: false)
        old.coordinator.tabs.selectedIndex = 1
        old.window.layoutIfNeeded()
        let tablePage = try XCTUnwrap(old.coordinator.tabs.navigationControllers[1].topViewController as? SettingsViewController)
        tablePage.loadViewIfNeeded()
        old.window.layoutIfNeeded()
        let path = IndexPath(row: 30, section: 0)
        tablePage.tableView.scrollToRow(at: path, at: .top, animated: false)
        tablePage.tableView.layoutIfNeeded()
        let cell = try XCTUnwrap(tablePage.tableView.cellForRow(at: path) as? DemoTableCell)
        cell.localizedContent.draft.text = "table row draft"
        tablePage.tableView.selectRow(at: path, animated: false, scrollPosition: .none)
        let activity = try XCTUnwrap(old.coordinator.activity())
        let saved = try XCTUnwrap(SceneStateCodec.decode(activity)).stacks[1][0].list!
        old.close()

        LanguageService.shared.setSelection(.arabic)
        let new = try RestoredSceneHarness(activity: activity)
        defer { new.close() }
        XCTAssertEqual(new.coordinator.restorationOrigin, "activity")
        XCTAssertEqual(new.coordinator.tabs.selectedIndex, 1)
        let restoredTable = try XCTUnwrap(new.coordinator.tabs.navigationControllers[1].topViewController as? SettingsViewController)
        new.window.layoutIfNeeded()
        ListStateRestoration.applyIfNeeded(restoredTable)
        let restoredCell = try XCTUnwrap(restoredTable.tableView.cellForRow(at: path) as? DemoTableCell)
        XCTAssertEqual(restoredCell.localizedContent.draft.text, "table row draft")
        XCTAssertTrue(restoredTable.tableView.indexPathsForSelectedRows?.contains(path) == true)
        let anchor = IndexPath(row: try XCTUnwrap(saved.anchorID), section: 0)
        XCTAssertEqual(restoredTable.tableView.rectForRow(at: anchor).minY - restoredTable.tableView.contentOffset.y
            - restoredTable.tableView.adjustedContentInset.top, saved.distance, accuracy: 2)
        let stack = new.coordinator.tabs.navigationControllers[0].viewControllers
        XCTAssertEqual(stack.count, 3)
        XCTAssertFalse(stack[1] === detail)
        XCTAssertEqual((stack[1] as? DetailViewController)?.draftField.text, "detail survives relaunch")
        let restoredPager = try XCTUnwrap(stack[2] as? LocalizedPageContainerController)
        XCTAssertEqual(restoredPager.currentPageID, "page-3")
        XCTAssertEqual((restoredPager.restorationPages[0].controller as? DemoPageViewController)?.draft.text, "page one draft")
        XCTAssertEqual((restoredPager.restorationPages[2].controller as? DemoPageViewController)?.draft.text, "page three draft")
        new.coordinator.tabs.selectedIndex = 0
        new.window.layoutIfNeeded()
        XCTAssertEqual(restoredPager.title, LanguageService.shared.context.text("pages.title"))
        XCTAssertEqual(LanguageService.shared.context.language, .arabic)
        XCTAssertFalse(new.coordinator.restoreInteractionState(activity), "Duplicate delivery must not rewind edits")
    }

    @MainActor
    func testActivityRestoresAllCollectionLayouts() throws {
        let original = LanguageService.shared.selection
        defer { LanguageService.shared.setSelection(original) }
        for route in [SavedPageState.Route.verticalCollection, .horizontalCollection, .compositionalGrid, .compositionalCarousel] {
            LanguageService.shared.setSelection(.english)
            let old = try RestoredSceneHarness()
            let controller: UIViewController
            switch route {
            case .verticalCollection: controller = CollectionDemoViewController()
            case .horizontalCollection: controller = CollectionDemoViewController(axis: .horizontal)
            case .compositionalGrid: controller = CompositionalDemoViewController()
            default: controller = CompositionalDemoViewController(mode: .orthogonal)
            }
            old.coordinator.tabs.navigationControllers[0].pushViewController(controller, animated: false)
            old.window.layoutIfNeeded()
            let page = try XCTUnwrap(controller as? any ListStateRestorable)
            let collection = try XCTUnwrap(page.restorationScrollView as? UICollectionView)
            if route == .compositionalCarousel {
                collection.scrollToItem(at: IndexPath(item: 12, section: 0), at: .centeredHorizontally, animated: false)
                collection.layoutIfNeeded()
            }
            let section = route == .compositionalCarousel ? 1 : 0
            let item = route == .horizontalCollection ? 25 : 30
            let path = IndexPath(item: item, section: section)
            collection.scrollToItem(at: path, at: route == .horizontalCollection ? .left : .top, animated: false)
            collection.layoutIfNeeded()
            let cell = try XCTUnwrap(collection.cellForItem(at: path) as? DemoCollectionCell)
            cell.localizedContent.draft.text = "draft \(route.rawValue)"
            collection.selectItem(at: path, animated: false, scrollPosition: [])
            let activity = try XCTUnwrap(old.coordinator.activity())
            let saved = try XCTUnwrap(SceneStateCodec.decode(activity)).stacks[0].last!.list!
            old.close()
            LanguageService.shared.setSelection(.arabic)
            let new = try RestoredSceneHarness(activity: activity)
            let restored = try XCTUnwrap(new.coordinator.tabs.navigationControllers[0].topViewController as? any ListStateRestorable)
            new.window.layoutIfNeeded()
            ListStateRestoration.applyIfNeeded(restored)
            let view = try XCTUnwrap(restored.restorationScrollView as? UICollectionView)
            let restoredCell = try XCTUnwrap(view.cellForItem(at: path) as? DemoCollectionCell)
            XCTAssertEqual(restoredCell.localizedContent.draft.text, "draft \(route.rawValue)", route.rawValue)
            XCTAssertTrue(view.indexPathsForSelectedItems?.contains(path) == true)
            let frame = restoredCell.convert(restoredCell.bounds, to: view)
            if route == .horizontalCollection {
                XCTAssertEqual(view.bounds.maxX - view.adjustedContentInset.right - frame.maxX, saved.distance, accuracy: 2)
            } else {
                XCTAssertEqual(frame.minY - view.bounds.minY - view.adjustedContentInset.top, saved.distance, accuracy: 2)
            }
            if route == .compositionalCarousel {
                view.setContentOffset(.zero, animated: false)
                view.layoutIfNeeded()
                let centered = try XCTUnwrap(view.cellForItem(at: IndexPath(item: 12, section: 0)))
                XCTAssertEqual(centered.convert(centered.bounds, to: view).midX, view.bounds.midX, accuracy: 2)
            }
            new.close()
        }
    }

    @MainActor
    func testSceneActivityValidationIsolationAndLateDelivery() throws {
        let scene = try RestoredSceneHarness()
        defer { scene.close() }
        let detail = DetailViewController()
        detail.draftField.text = "saved business state"
        scene.coordinator.tabs.navigationControllers[0].pushViewController(detail, animated: false)
        let activity = try XCTUnwrap(scene.coordinator.activity())
        var saved = try XCTUnwrap(SceneStateCodec.decode(activity))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SceneCheckpointStore(directory: directory)
        store.save(activity, sceneID: "scene-a")
        XCTAssertEqual(SceneStateCodec.decode(try XCTUnwrap(store.load(sceneID: "scene-a"))), saved)
        XCTAssertNil(store.load(sceneID: "scene-b"))
        store.remove(sceneID: "scene-a")
        XCTAssertNil(store.load(sceneID: "scene-a"))
        saved.version = 99
        XCTAssertNil(SceneStateCodec.activity(for: saved))
        let wrongType = NSUserActivity(activityType: "com.other.activity")
        wrongType.userInfo = activity.userInfo
        XCTAssertNil(SceneStateCodec.decode(wrongType))
        XCTAssertNil(SceneStateCodec.decode(Data(repeating: 0, count: SceneStateCodec.maximumBytes + 1)))
        let hidden = CollectionDemoViewController()
        let pending = SavedListState(anchorID: 30, distance: -12, selectedIDs: [30], drafts: [30: "hidden draft"])
        hidden.pendingListState = pending
        hidden.drafts = pending.drafts
        hidden.loadViewIfNeeded()
        XCTAssertEqual(ListStateRestoration.capture(hidden), pending,
            "Loading a hidden page must not replace its pending restoration geometry")
        let fresh = try RestoredSceneHarness()
        defer { fresh.close() }
        XCTAssertTrue(fresh.coordinator.restoreInteractionState(activity))
        let restored = try XCTUnwrap(fresh.coordinator.tabs.navigationControllers[0].topViewController as? DetailViewController)
        restored.draftField.text = "new edit after restore"
        XCTAssertFalse(fresh.coordinator.restoreInteractionState(activity))
        XCTAssertEqual(restored.draftField.text, "new edit after restore")
        let active = try RestoredSceneHarness()
        defer { active.close() }
        active.coordinator.tabs.selectedIndex = 1
        XCTAssertFalse(active.coordinator.restoreInteractionState(activity), "Late state must not overwrite a user tab change")
    }

    @MainActor
    func testActivityRestoresSplitColumnsAndDrafts() throws {
        let old = try RestoredSceneHarness()
        let split = ContainerDemos.makeSplit()
        let primaryDetail = DetailViewController()
        primaryDetail.draftField.text = "primary draft"
        split.restorationPrimary?.pushViewController(primaryDetail, animated: false)
        (split.restorationSecondary?.topViewController as? DetailViewController)?.draftField.text = "secondary draft"
        old.coordinator.tabs.present(split, animated: false)
        old.window.layoutIfNeeded()
        split.show(.secondary)
        old.window.layoutIfNeeded()
        XCTAssertTrue(split.restorationShowsSecondary)
        if split.isCollapsed {
            split.show(.primary)
            old.window.layoutIfNeeded()
            XCTAssertFalse(split.restorationShowsSecondary)
            split.show(.secondary)
            old.window.layoutIfNeeded()
            XCTAssertTrue(split.restorationShowsSecondary)
        }
        let activity = try XCTUnwrap(old.coordinator.activity())
        XCTAssertNotNil(SceneStateCodec.decode(activity)?.split)
        old.close()
        let new = try RestoredSceneHarness(activity: activity)
        defer { new.close() }
        new.window.layoutIfNeeded()
        let restored = try XCTUnwrap(new.coordinator.tabs.presentedViewController as? LocalizedSplitViewController)
        XCTAssertEqual(restored.restorationPrimary?.viewControllers.count, 2)
        XCTAssertEqual((restored.restorationPrimary?.viewControllers.last as? DetailViewController)?.draftField.text, "primary draft")
        XCTAssertEqual((restored.restorationSecondary?.viewControllers.first as? DetailViewController)?.draftField.text, "secondary draft")
        XCTAssertTrue(restored.restorationShowsSecondary)
    }

}

@MainActor
private final class ContainerTestWindow {
    let window: UIWindow
    private let previousKeyWindow: UIWindow?
    private let originalSelection: LanguageSelection

    init(content: UIViewController) throws {
        originalSelection = LanguageService.shared.selection
        LanguageService.shared.setSelection(.english)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.rootViewController = LocalizationHostController(content: content)
        LanguageService.shared.register(window: window)
        window.makeKeyAndVisible()
        content.loadViewIfNeeded()
        window.layoutIfNeeded()
    }

    func close() {
        LanguageService.shared.unregister(window: window)
        window.isHidden = true
        LanguageService.shared.setSelection(originalSelection)
        previousKeyWindow?.makeKeyAndVisible()
    }
}

@MainActor
private final class LocalizedTestSheet: LocalizedViewController {
    override func applyLocalization(_ context: LanguageContext) {
        title = context.text("detail.title")
    }
}

@MainActor
private final class RestoredSceneHarness {
    let window: UIWindow
    let coordinator = SceneStateCoordinator()
    private let previous: UIWindow?
    private var closed = false
    init(activity: NSUserActivity? = nil) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        previous = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        coordinator.connect(window: window, activity: activity)
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
