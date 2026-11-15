import XCTest
import UIKit
@testable import UIKitLanguageDemo

final class ScrollDirectionTests: XCTestCase {
    @MainActor
    func testOwnedScrollBoundariesRefreshWithoutChangingIndicatorPolicyOrPagerEngine() throws {
        let service = LanguageService.shared
        let original = service.selection
        defer { service.setSelection(original) }
        let home = HomeViewController()
        let detail = DetailViewController()
        let table = SettingsViewController()
        let flow = CollectionDemoViewController()
        let horizontal = CollectionDemoViewController(axis: .horizontal)
        let grid = CompositionalDemoViewController()
        let orthogonal = CompositionalDemoViewController(mode: .orthogonal)
        let pages: [UIViewController] = [home, detail, table, flow, horizontal, grid, orthogonal]
        for page in pages { page.loadViewIfNeeded() }
        let homeScroll = try XCTUnwrap(home.view.subviews.compactMap { $0 as? UIScrollView }.first)
        let detailScroll = try XCTUnwrap(detail.view.subviews.compactMap { $0 as? UIScrollView }.first)
        let scrolls = [homeScroll, detailScroll, table.tableView, flow.collectionView,
                       horizontal.collectionView, grid.collectionView, orthogonal.collectionView]
        let customInsets = UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
        for scroll in scrolls {
            scroll.showsVerticalScrollIndicator = false
            scroll.showsHorizontalScrollIndicator = false
            scroll.indicatorStyle = .white
            scroll.automaticallyAdjustsScrollIndicatorInsets = false
            scroll.verticalScrollIndicatorInsets = customInsets
        }
        let pager = ContainerDemos.makePager()
        pager.loadViewIfNeeded()
        let engine = try XCTUnwrap(pager.children.compactMap { $0 as? UIPageViewController }.first)
        for choice in [LanguageSelection.arabic, .english, .simplifiedChinese, .arabic] {
            service.setSelection(choice)
            for page in pages { page.view.setNeedsLayout(); page.view.layoutIfNeeded() }
            for scroll in scrolls {
                XCTAssertEqual(scroll.semanticContentAttribute, service.context.isRTL ? .forceRightToLeft : .forceLeftToRight)
                XCTAssertFalse(scroll.showsVerticalScrollIndicator)
                XCTAssertFalse(scroll.showsHorizontalScrollIndicator)
                XCTAssertEqual(scroll.indicatorStyle, .white)
                XCTAssertFalse(scroll.automaticallyAdjustsScrollIndicatorInsets)
                if let collection = scroll as? UICollectionView,
                   collection.collectionViewLayout is UICollectionViewCompositionalLayout {
                    // This demo owns the left inset to compensate its mirrored
                    // indicator track. Other caller-supplied edges are retained.
                    XCTAssertEqual(scroll.verticalScrollIndicatorInsets.top, customInsets.top)
                    XCTAssertEqual(scroll.verticalScrollIndicatorInsets.bottom, customInsets.bottom)
                    XCTAssertEqual(scroll.verticalScrollIndicatorInsets.right, customInsets.right)
                    XCTAssertGreaterThanOrEqual(scroll.verticalScrollIndicatorInsets.left, 0)
                } else {
                    XCTAssertEqual(scroll.verticalScrollIndicatorInsets, customInsets)
                }
                XCTAssertEqual(scroll.transform, .identity)
            }
            XCTAssertEqual(engine.view.semanticContentAttribute, .forceLeftToRight)
        }
    }
}
