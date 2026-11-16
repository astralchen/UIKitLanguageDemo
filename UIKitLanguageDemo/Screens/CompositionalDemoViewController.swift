import UIKit

@MainActor
final class CompositionalDemoViewController: LocalizedViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    enum Mode { case grid, orthogonal }
    let mode: Mode
    let collectionView: UICollectionView
    let itemIDsBySection: [[Int]]
    private let languagePicker = LanguagePickerView()
    private let stack = UIStackView()
    var drafts: [Int: String] = [:]
    var pendingListState: SavedListState?
    private var renderedRTL = LanguageService.shared.context.isRTL
    private(set) var localization: CollectionLocalizationCoordinator!
    private(set) var orthogonalLocalization: OrthogonalLocalizationCoordinator?

    init(mode: Mode = .grid) {
        self.mode = mode
        itemIDsBySection = mode == .grid ? [Array(0..<80)] : [Array(0..<30), Array(100..<180)]
        // 在 self 初始化完成后安装 section provider。
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        super.init(nibName: nil, bundle: nil)
        collectionView.setCollectionViewLayout(makeLayout(), animated: false)
    }
    required init?(coder: NSCoder) { fatalError("Use init(mode:)") }

    override func buildUI() {
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = true
        collectionView.register(DemoCollectionCell.self, forCellWithReuseIdentifier: "card")
        collectionView.register(DemoCollectionHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: "header")
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(languagePicker)
        stack.addArrangedSubview(collectionView)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        localization = CollectionLocalizationCoordinator(collectionView: collectionView, axis: .vertical,
            itemID: { [weak self] in self?.id(at: $0).map(AnyHashable.init) },
            indexPath: { [weak self] in self?.path(for: $0) },
            renderCell: { [weak self] in self?.render($0, at: $1, context: $2) },
            renderSupplementary: { [weak self] context in
                guard let self else { return }
                for path in self.collectionView.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader) {
                    if let header = self.collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: path) as? DemoCollectionHeader {
                        self.render(header, section: path.section, context: context)
                    }
                }
            },
            anchorFilter: { [weak self] path in
                guard let self else { return false }
                if self.mode == .grid { return true }
                guard path.section != 0,
                      let header = self.collectionView.collectionViewLayout.layoutAttributesForSupplementaryView(
                        ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 1)) else { return false }
                return self.collectionView.bounds.minY + self.collectionView.adjustedContentInset.top >= header.frame.minY
            })
        if mode == .orthogonal {
            orthogonalLocalization = OrthogonalLocalizationCoordinator(collectionView: collectionView,
                itemID: { [weak self] in self?.id(at: $0).map(AnyHashable.init) },
                indexPath: { [weak self] in self?.path(for: $0) })
        }
    }

    override func applyLocalization(_ context: LanguageContext) {
        title = context.text(mode == .grid ? .compositionalTitle : .compositionalOrthogonal)
        languagePicker.applyLocalization(context)
        LayoutDirection.applyBoundary(context, to: stack)
        LayoutDirection.applyScrollView(context, to: collectionView)
        // 只重建布局几何信息，使两个方向的切换都能刷新镜像布局。
        if renderedRTL != context.isRTL {
            renderedRTL = context.isRTL
            collectionView.setCollectionViewLayout(makeLayout(), animated: false)
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        localization.refreshAfterAppearance()
        orthogonalLocalization?.refreshAfterAppearance()
        ListStateRestoration.applyIfNeeded(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // iOS 26+ 会镜像 Compositional Layout 指示器的坐标系：
        // 其 RTL 轨道需要通过左侧 inset 补偿移到物理左侧。
        // iOS 18 已将原生 RTL 轨道放在物理左侧，同样的补偿
        // 反而会把它推回右侧（已在 XR 上验证）。
        let edgeSpacing: CGFloat = 4
        var inset = collectionView.verticalScrollIndicatorInsets
        if #available(iOS 26.0, *) {
            inset.left = LanguageService.shared.context.isRTL
                ? max(0, collectionView.bounds.width - 2 * edgeSpacing) : 0
        } else {
            inset.left = 0
        }
        if collectionView.verticalScrollIndicatorInsets != inset {
            collectionView.verticalScrollIndicatorInsets = inset
        }
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.contentInsetsReference = .none
        configuration.interSectionSpacing = 20
        return LocalizedCompositionalLayout(sectionProvider: { [weak self] sectionIndex, _ in
            guard let self else { return nil }
            let carousel = self.mode == .orthogonal && sectionIndex == 0
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1), heightDimension: .estimated(220)))
            let group: NSCollectionLayoutGroup
            if carousel {
                group = .horizontal(layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(LanguageService.shared.context.isRTL ? 0.9 : 0.82),
                    heightDimension: .estimated(220)), subitems: [item])
            } else {
                group = .horizontal(layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1), heightDimension: .estimated(220)), subitem: item, count: 2)
                group.interItemSpacing = .fixed(12)
            }
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 12
            section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
            let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1), heightDimension: .estimated(56)),
                elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            section.boundarySupplementaryItems = [header]
            if carousel {
                section.orthogonalScrollingBehavior = .groupPagingCentered
                section.visibleItemsInvalidationHandler = { [weak self] items, offset, environment in
                    self?.orthogonalLocalization?.record(section: sectionIndex, items: items, offset: offset, environment: environment)
                }
            }
            return section
        }, configuration: configuration)
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int { itemIDsBySection.count }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { itemIDsBySection[section].count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt path: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "card", for: path)
        render(cell, at: path, context: LanguageService.shared.context)
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt path: IndexPath) {
        render(cell, at: path, context: LanguageService.shared.context)
    }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at path: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: path) as! DemoCollectionHeader
        render(header, section: path.section, context: LanguageService.shared.context)
        return header
    }
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView,
                        forElementKind elementKind: String, at path: IndexPath) {
        if let header = view as? DemoCollectionHeader { render(header, section: path.section, context: LanguageService.shared.context) }
    }
    private func render(_ header: DemoCollectionHeader, section: Int, context: LanguageContext) {
        header.render(context, titleMessage: mode == .orthogonal && section == 0 ? .compositionalCarouselSection : .compositionalGridSection)
    }
    private func render(_ cell: UICollectionViewCell, at path: IndexPath, context: LanguageContext) {
        guard let cell = cell as? DemoCollectionCell, let id = id(at: path) else { return }
        cell.accessibilityIdentifier = "list.cell.\(id)"
        cell.localizedContent.bind(id: id, savedDraft: drafts[id] ?? "") { [weak self] id, value in self?.drafts[id] = value }
        cell.localizedContent.render(id: id, context: context)
        LayoutDirection.applyBoundary(context, to: cell)
        LayoutDirection.applyBoundary(context, to: cell.contentView)
    }
    private func id(at path: IndexPath) -> Int? {
        guard itemIDsBySection.indices.contains(path.section), itemIDsBySection[path.section].indices.contains(path.item) else { return nil }
        return itemIDsBySection[path.section][path.item]
    }
    private func path(for id: AnyHashable) -> IndexPath? {
        guard let id = id.base as? Int else { return nil }
        for (section, ids) in itemIDsBySection.enumerated() {
            if let item = ids.firstIndex(of: id) { return IndexPath(item: item, section: section) }
        }
        return nil
    }
}

/// 使用固定的 LTR 开发布局基准；UIKit 根据当前视图方向进行镜像。
final class LocalizedCompositionalLayout: UICollectionViewCompositionalLayout {
    override var developmentLayoutDirection: UIUserInterfaceLayoutDirection { .leftToRight }
    override var flipsHorizontallyInOppositeLayoutDirection: Bool { true }
}
