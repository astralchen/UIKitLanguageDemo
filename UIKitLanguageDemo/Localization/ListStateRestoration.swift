import UIKit

@MainActor
protocol ListStateRestorable: UIViewController {
    var pendingListState: SavedListState? { get set }
    var restorationDrafts: [Int: String] { get set }
    var restorationScrollView: UIScrollView { get }
    var restorationTableCoordinator: TableLocalizationCoordinator? { get }
    var restorationCollectionCoordinator: CollectionLocalizationCoordinator? { get }
    var restorationOrthogonalCoordinator: OrthogonalLocalizationCoordinator? { get }
}

@MainActor
enum ListStateRestoration {
    static func capture(_ page: any ListStateRestorable) -> SavedListState {
        // A hidden page can already have loaded its view without having appeared.
        // Preserve its saved geometry until the first attached-window application.
        if let pending = page.pendingListState { return pending }
        guard page.isViewLoaded else { return SavedListState(drafts: page.restorationDrafts) }
        let scroll = page.restorationScrollView
        var drafts = page.restorationDrafts
        if let table = scroll as? UITableView {
            for case let cell as DemoTableCell in table.visibleCells {
                if let id = cell.localizedContent.itemID { drafts[id] = cell.localizedContent.draft.text ?? "" }
            }
        } else if let collection = scroll as? UICollectionView {
            for case let cell as DemoCollectionCell in collection.visibleCells {
                if let id = cell.localizedContent.itemID { drafts[id] = cell.localizedContent.draft.text ?? "" }
            }
        }
        let reading = page.restorationTableCoordinator?.readingStateForRestoration()
            ?? page.restorationCollectionCoordinator?.readingStateForRestoration()
        return SavedListState(anchorID: reading?.anchorID?.base as? Int,
            distance: Double(reading?.distanceFromLeadingEdge ?? 0),
            selectedIDs: reading?.selectedIDs.compactMap { $0.base as? Int } ?? [], drafts: drafts,
            startDistance: Double(scroll.contentOffset.y + scroll.adjustedContentInset.top),
            orthogonalCenters: page.restorationOrthogonalCoordinator?.centersForRestoration().compactMapValues { $0.base as? Int } ?? [:])
    }

    static func applyIfNeeded(_ page: any ListStateRestorable) {
        guard let saved = page.pendingListState, page.isViewLoaded, page.view.window != nil else { return }
        page.pendingListState = nil
        let reading = ListReadingState(anchorID: saved.anchorID.map(AnyHashable.init),
            distanceFromLeadingEdge: CGFloat(saved.distance), selectedIDs: saved.selectedIDs.map(AnyHashable.init))
        page.restorationTableCoordinator?.restoreReadingState(reading)
        page.restorationCollectionCoordinator?.restoreReadingState(reading, startDistance: CGFloat(saved.startDistance))
        page.restorationOrthogonalCoordinator?.restoreCenters(saved.orthogonalCenters.mapValues(AnyHashable.init))
    }
}

extension SettingsViewController: ListStateRestorable {
    var restorationDrafts: [Int: String] { get { drafts } set { drafts = newValue } }
    var restorationScrollView: UIScrollView { tableView }
    var restorationTableCoordinator: TableLocalizationCoordinator? { localization }
    var restorationCollectionCoordinator: CollectionLocalizationCoordinator? { nil }
    var restorationOrthogonalCoordinator: OrthogonalLocalizationCoordinator? { nil }
}
extension CollectionDemoViewController: ListStateRestorable {
    var restorationDrafts: [Int: String] { get { drafts } set { drafts = newValue } }
    var restorationScrollView: UIScrollView { collectionView }
    var restorationTableCoordinator: TableLocalizationCoordinator? { nil }
    var restorationCollectionCoordinator: CollectionLocalizationCoordinator? { localization }
    var restorationOrthogonalCoordinator: OrthogonalLocalizationCoordinator? { nil }
}
extension CompositionalDemoViewController: ListStateRestorable {
    var restorationDrafts: [Int: String] { get { drafts } set { drafts = newValue } }
    var restorationScrollView: UIScrollView { collectionView }
    var restorationTableCoordinator: TableLocalizationCoordinator? { nil }
    var restorationCollectionCoordinator: CollectionLocalizationCoordinator? { localization }
    var restorationOrthogonalCoordinator: OrthogonalLocalizationCoordinator? { orthogonalLocalization }
}
