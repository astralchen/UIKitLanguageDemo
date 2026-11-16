import UIKit

/// 适用于每个 group 仅含一个 item、使用 groupPagingCentered 的 Compositional Layout section。
/// 保留业务页面 ID，不暴露私有的正交滚动视图。
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

    /// 在每个正交 section 的 visibleItemsInvalidationHandler 中调用。
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
            // 滚动正交 item 时，不得改变外层阅读位置。
            collectionView.setContentOffset(outerOffset, animated: false)
            collectionView.setNeedsLayout()
            collectionView.layoutIfNeeded()
        }
        self.pendingCenters = nil
    }

    func centersForRestoration() -> [Int: LocalizationItemID] { pendingCenters ?? observedCenters }
    func restoreCenters(_ centers: [Int: LocalizationItemID]) {
        pendingCenters = centers
        finishLayout()
    }
    func refreshAfterAppearance() { finishLayout() }
}
