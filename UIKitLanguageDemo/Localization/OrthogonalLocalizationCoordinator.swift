import UIKit

/// For one-item-per-group, groupPagingCentered compositional sections.
/// Retains a business page ID; it does not expose a private orthogonal scroll view.
@MainActor
final class OrthogonalLocalizationCoordinator: ListLocalizationObserver {
    private weak var collectionView: UICollectionView?
    private let itemID: (IndexPath) -> LocalizationItemID?
    private let indexPath: (LocalizationItemID) -> IndexPath?
    private(set) var observedCenters: [Int: LocalizationItemID] = [:]
    private var pendingCenters: [Int: LocalizationItemID]?

    init(collectionView: UICollectionView,
         itemID: @escaping (IndexPath) -> LocalizationItemID?,
         indexPath: @escaping (LocalizationItemID) -> IndexPath?) {
        self.collectionView = collectionView
        self.itemID = itemID
        self.indexPath = indexPath
        super.init(languageService: .shared)
    }

    /// Call from each orthogonal section's visibleItemsInvalidationHandler.
    func record(section: Int, items: [any NSCollectionLayoutVisibleItem],
                offset: CGPoint, environment: any NSCollectionLayoutEnvironment) {
        let center = offset.x + environment.container.effectiveContentSize.width / 2
        let cell = items.filter { $0.representedElementCategory == .cell }
            .min { abs($0.frame.midX - center) < abs($1.frame.midX - center) }
        if let path = cell?.indexPath, let id = itemID(path) { observedCenters[section] = id }
    }

    override func captureState() { pendingCenters = observedCenters }
    override func finishLayout() {
        guard let collectionView, collectionView.window != nil,
              !collectionView.hasUncommittedUpdates, let pendingCenters else { return }
        let outerOffset = collectionView.contentOffset
        UIView.performWithoutAnimation {
            for (section, id) in pendingCenters.sorted(by: { $0.key < $1.key }) {
                guard let path = indexPath(id), path.section == section,
                      section < collectionView.numberOfSections,
                      path.item < collectionView.numberOfItems(inSection: section) else { continue }
                collectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: false)
                collectionView.layoutIfNeeded()
            }
            // Scrolling an orthogonal item must not move the outer reading position.
            collectionView.setContentOffset(outerOffset, animated: false)
            collectionView.setNeedsLayout()
            collectionView.layoutIfNeeded()
        }
        self.pendingCenters = nil
    }

    func refreshAfterAppearance() { finishLayout() }
}
