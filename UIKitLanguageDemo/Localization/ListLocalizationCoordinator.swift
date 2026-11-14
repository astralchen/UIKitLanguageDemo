import UIKit

/// Stable business IDs work with regular and diffable data sources.
typealias LocalizationItemID = AnyHashable

@MainActor
private struct ListReadingState {
    let anchorID: LocalizationItemID?
    let distanceFromLeadingEdge: CGFloat
    let selectedIDs: [LocalizationItemID]
}

@MainActor
class ListLocalizationObserver: NSObject {
    init(languageService: LanguageService) {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(languageWillChange), name: .appLanguageWillChange, object: languageService)
        center.addObserver(self, selector: #selector(languageDidChange), name: .appLanguageDidChange, object: languageService)
        center.addObserver(self, selector: #selector(languageDidLayout), name: .appLanguageDidApplyLayout, object: languageService)
    }
    func captureState() {}
    func updateContent(_ context: LanguageContext) {}
    func finishLayout() {}
    @objc private func languageWillChange() { captureState() }
    @objc private func languageDidChange() { updateContent(LanguageService.shared.context) }
    @objc private func languageDidLayout() { finishLayout() }
}

@MainActor
final class TableLocalizationCoordinator: ListLocalizationObserver {
    private weak var tableView: UITableView?
    private let itemID: (IndexPath) -> LocalizationItemID?
    private let indexPath: (LocalizationItemID) -> IndexPath?
    private let renderCell: (UITableViewCell, IndexPath, LanguageContext) -> Void
    private let renderSupplementary: (LanguageContext) -> Void
    private var readingState: ListReadingState?
    private var needsMeasurement = false

    init(tableView: UITableView,
         itemID: @escaping (IndexPath) -> LocalizationItemID?,
         indexPath: @escaping (LocalizationItemID) -> IndexPath?,
         renderCell: @escaping (UITableViewCell, IndexPath, LanguageContext) -> Void,
         renderSupplementary: @escaping (LanguageContext) -> Void = { _ in }) {
        self.tableView = tableView
        self.itemID = itemID
        self.indexPath = indexPath
        self.renderCell = renderCell
        self.renderSupplementary = renderSupplementary
        super.init(languageService: .shared)
    }

    override func captureState() {
        guard let tableView else { return }
        let top = tableView.indexPathsForVisibleRows?.min()
        let canAnchor = !tableView.isTracking && !tableView.isDragging && !tableView.isDecelerating
        let anchor = canAnchor ? top : nil
        readingState = ListReadingState(
            anchorID: anchor.flatMap(itemID),
            distanceFromLeadingEdge: anchor.map {
                tableView.rectForRow(at: $0).minY - tableView.contentOffset.y - tableView.adjustedContentInset.top
            } ?? 0,
            selectedIDs: (tableView.indexPathsForSelectedRows ?? []).compactMap(itemID)
        )
    }

    override func updateContent(_ context: LanguageContext) {
        guard let tableView else { return }
        LayoutDirection.applyBoundary(context, to: tableView)
        for path in tableView.indexPathsForVisibleRows ?? [] {
            if let cell = tableView.cellForRow(at: path) { renderCell(cell, path, context) }
        }
        renderSupplementary(context)
        tableView.setNeedsLayout()
        needsMeasurement = true
    }

    override func finishLayout() {
        guard needsMeasurement, let tableView, tableView.window != nil,
              !tableView.hasUncommittedUpdates else { return }
        // Re-measure self-sizing rows without recreating cells or editing controls.
        UIView.performWithoutAnimation {
            tableView.beginUpdates()
            tableView.endUpdates()
            tableView.layoutIfNeeded()
            if let state = readingState {
                restoreSelection(state, in: tableView)
                if let id = state.anchorID, let path = indexPath(id), valid(path, in: tableView),
                   !tableView.isTracking && !tableView.isDragging && !tableView.isDecelerating {
                    if tableView.cellForRow(at: path) == nil {
                        tableView.scrollToRow(at: path, at: .top, animated: false)
                        tableView.layoutIfNeeded()
                    }
                    let y = tableView.rectForRow(at: path).minY
                        - state.distanceFromLeadingEdge - tableView.adjustedContentInset.top
                    tableView.setContentOffset(ListGeometry.clamp(CGPoint(x: tableView.contentOffset.x, y: y), in: tableView), animated: false)
                    tableView.layoutIfNeeded()
                }
            }
        }
        readingState = nil
        needsMeasurement = false
    }

    /// Call after reappearing, or after a business-owned batch update finishes.
    func refreshAfterAppearance() {
        if readingState == nil { captureState() }
        updateContent(LanguageService.shared.context)
        finishLayout()
    }

    private func restoreSelection(_ state: ListReadingState, in table: UITableView) {
        let desired = Set(state.selectedIDs.compactMap(indexPath).filter { valid($0, in: table) })
        for path in table.indexPathsForSelectedRows ?? [] where !desired.contains(path) {
            table.deselectRow(at: path, animated: false)
        }
        for path in desired where table.indexPathsForSelectedRows?.contains(path) != true {
            table.selectRow(at: path, animated: false, scrollPosition: .none)
        }
    }

    private func valid(_ path: IndexPath, in table: UITableView) -> Bool {
        path.section >= 0 && path.section < table.numberOfSections
            && path.row >= 0 && path.row < table.numberOfRows(inSection: path.section)
    }
}

@MainActor
final class CollectionLocalizationCoordinator: ListLocalizationObserver {
    enum Axis { case vertical, horizontal }
    private weak var collectionView: UICollectionView?
    private let axis: Axis
    private let itemID: (IndexPath) -> LocalizationItemID?
    private let indexPath: (LocalizationItemID) -> IndexPath?
    private let renderCell: (UICollectionViewCell, IndexPath, LanguageContext) -> Void
    private let renderSupplementary: (LanguageContext) -> Void
    private var readingState: ListReadingState?
    private var needsMeasurement = false

    init(collectionView: UICollectionView, axis: Axis,
         itemID: @escaping (IndexPath) -> LocalizationItemID?,
         indexPath: @escaping (LocalizationItemID) -> IndexPath?,
         renderCell: @escaping (UICollectionViewCell, IndexPath, LanguageContext) -> Void,
         renderSupplementary: @escaping (LanguageContext) -> Void = { _ in }) {
        self.collectionView = collectionView
        self.axis = axis
        self.itemID = itemID
        self.indexPath = indexPath
        self.renderCell = renderCell
        self.renderSupplementary = renderSupplementary
        super.init(languageService: .shared)
    }

    override func captureState() {
        guard let collectionView else { return }
        let rtl = collectionView.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let viewport = collectionView.bounds.inset(by: collectionView.adjustedContentInset)
        let visible = collectionView.indexPathsForVisibleItems.compactMap { path -> (IndexPath, CGRect)? in
            guard let cell = collectionView.cellForItem(at: path), cell.frame.intersects(viewport) else { return nil }
            return (path, cell.frame)
        }.sorted { a, b in
            if axis == .vertical, abs(a.1.minY - b.1.minY) > 0.5 { return a.1.minY < b.1.minY }
            if abs(a.1.minX - b.1.minX) > 0.5 { return rtl ? a.1.maxX > b.1.maxX : a.1.minX < b.1.minX }
            return a.1.minY < b.1.minY
        }
        let canAnchor = !collectionView.isTracking && !collectionView.isDragging && !collectionView.isDecelerating
        let first = canAnchor ? visible.first : nil
        let distance: CGFloat
        if let frame = first?.1 {
            distance = axis == .vertical ? frame.minY - viewport.minY
                : (rtl ? viewport.maxX - frame.maxX : frame.minX - viewport.minX)
        } else { distance = 0 }
        readingState = ListReadingState(anchorID: first.flatMap { itemID($0.0) },
                                        distanceFromLeadingEdge: distance,
                                        selectedIDs: (collectionView.indexPathsForSelectedItems ?? []).compactMap(itemID))
    }

    override func updateContent(_ context: LanguageContext) {
        guard let collectionView else { return }
        LayoutDirection.applyBoundary(context, to: collectionView)
        for path in collectionView.indexPathsForVisibleItems {
            if let cell = collectionView.cellForItem(at: path) { renderCell(cell, path, context) }
        }
        renderSupplementary(context)
        if let flow = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let invalidation = UICollectionViewFlowLayoutInvalidationContext()
            invalidation.invalidateFlowLayoutDelegateMetrics = true
            invalidation.invalidateFlowLayoutAttributes = true
            flow.invalidateLayout(with: invalidation)
        } else {
            collectionView.collectionViewLayout.invalidateLayout()
        }
        collectionView.setNeedsLayout()
        needsMeasurement = true
    }

    override func finishLayout() {
        guard needsMeasurement, let collectionView, collectionView.window != nil,
              !collectionView.hasUncommittedUpdates else { return }
        UIView.performWithoutAnimation {
            collectionView.layoutIfNeeded()
            if let state = readingState {
                restoreSelection(state, in: collectionView)
                if let id = state.anchorID, let path = indexPath(id), valid(path, in: collectionView),
                   !collectionView.isTracking && !collectionView.isDragging && !collectionView.isDecelerating {
                    restoreAnchor(path, distance: state.distanceFromLeadingEdge, in: collectionView)
                }
            }
        }
        readingState = nil
        needsMeasurement = false
    }

    func refreshAfterAppearance() {
        if readingState == nil { captureState() }
        updateContent(LanguageService.shared.context)
        finishLayout()
    }

    private func restoreAnchor(_ path: IndexPath, distance: CGFloat, in collection: UICollectionView) {
        let rtl = collection.effectiveUserInterfaceLayoutDirection == .rightToLeft
        if collection.cellForItem(at: path) == nil {
            let position: UICollectionView.ScrollPosition = axis == .vertical ? .top : (rtl ? .right : .left)
            collection.scrollToItem(at: path, at: position, animated: false)
            collection.layoutIfNeeded()
        }
        // Existing cells may still carry their pre-invalidation frame. Query the
        // layout's newly measured attributes instead of that stale view geometry.
        guard let frame = collection.collectionViewLayout.layoutAttributesForItem(at: path)?.frame else { return }
        var offset = collection.contentOffset
        if axis == .vertical {
            offset.y = frame.minY - distance - collection.adjustedContentInset.top
        } else if rtl {
            offset.x = frame.maxX + distance - collection.bounds.width + collection.adjustedContentInset.right
        } else {
            offset.x = frame.minX - distance - collection.adjustedContentInset.left
        }
        collection.setContentOffset(ListGeometry.clamp(offset, in: collection), animated: false)
        collection.setNeedsLayout()
        collection.layoutIfNeeded()
    }

    private func restoreSelection(_ state: ListReadingState, in collection: UICollectionView) {
        let desired = Set(state.selectedIDs.compactMap(indexPath).filter { valid($0, in: collection) })
        for path in collection.indexPathsForSelectedItems ?? [] where !desired.contains(path) {
            collection.deselectItem(at: path, animated: false)
        }
        for path in desired where collection.indexPathsForSelectedItems?.contains(path) != true {
            collection.selectItem(at: path, animated: false, scrollPosition: [])
        }
    }

    private func valid(_ path: IndexPath, in collection: UICollectionView) -> Bool {
        path.section >= 0 && path.section < collection.numberOfSections
            && path.item >= 0 && path.item < collection.numberOfItems(inSection: path.section)
    }
}

@MainActor
private enum ListGeometry {
    static func clamp(_ point: CGPoint, in scroll: UIScrollView) -> CGPoint {
        let inset = scroll.adjustedContentInset
        return CGPoint(x: min(max(point.x, -inset.left), max(-inset.left, scroll.contentSize.width - scroll.bounds.width + inset.right)),
                       y: min(max(point.y, -inset.top), max(-inset.top, scroll.contentSize.height - scroll.bounds.height + inset.bottom)))
    }
}

/// FlowLayout handles RTL internally; do not add a second automatic flip or transform.
final class LocalizedCollectionFlowLayout: UICollectionViewFlowLayout {}
