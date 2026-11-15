import UIKit

@MainActor
final class CollectionDemoViewController: LocalizedViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    let axis: CollectionLocalizationCoordinator.Axis
    let collectionView: UICollectionView
    let itemIDs = Array(0..<80)
    private let languagePicker = LanguagePickerView()
    private let stack = UIStackView()
    var drafts: [Int: String] = [:]
    var pendingListState: SavedListState?
    private(set) var localization: CollectionLocalizationCoordinator!

    init(axis: CollectionLocalizationCoordinator.Axis = .vertical) {
        self.axis = axis
        let layout = LocalizedCollectionFlowLayout()
        layout.scrollDirection = axis == .vertical ? .vertical : .horizontal
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use init(axis:)") }

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
        localization = CollectionLocalizationCoordinator(collectionView: collectionView, axis: axis,
            itemID: { [weak self] path in self?.id(at: path).map(AnyHashable.init) },
            indexPath: { [weak self] id in self?.path(for: id) },
            renderCell: { [weak self] cell, path, context in self?.render(cell, at: path, context: context) },
            renderSupplementary: { [weak self] context in
                for header in self?.collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader) ?? [] {
                    (header as? DemoCollectionHeader)?.render(context)
                }
            })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        localization.refreshAfterAppearance()
        ListStateRestoration.applyIfNeeded(self)
    }

    override func applyLocalization(_ context: LanguageContext) {
        title = context.text(axis == .vertical ? .collectionTitle : .collectionHorizontal)
        languagePicker.applyLocalization(context)
        LayoutDirection.applyScrollView(context, to: collectionView)
        LayoutDirection.applyBoundary(context, to: stack)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { itemIDs.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt path: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "card", for: path)
        render(cell, at: path, context: LanguageService.shared.context)
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt path: IndexPath) {
        // Prefetched cells also use the latest language immediately before display.
        render(cell, at: path, context: LanguageService.shared.context)
    }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! DemoCollectionHeader
        header.render(LanguageService.shared.context)
        return header
    }
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView,
                        forElementKind elementKind: String, at indexPath: IndexPath) {
        (view as? DemoCollectionHeader)?.render(LanguageService.shared.context)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt path: IndexPath) -> CGSize {
        let context = LanguageService.shared.context
        if axis == .horizontal {
            return CGSize(width: context.isRTL ? 290 : 230, height: max(180, collectionView.bounds.height - 24))
        }
        let width = max(120, floor((collectionView.bounds.width - 12) / 2))
        let heading = context.text(.listItem((id(at: path) ?? 0) + 1))
        let titleHeight = heading.boundingRect(with: CGSize(width: width - 24, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.preferredFont(forTextStyle: .headline)], context: nil).height
        let bodyHeight = context.text(.listDescription).boundingRect(with: CGSize(width: width - 24, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)], context: nil).height
        let inputHeight = max(36, UIFont.preferredFont(forTextStyle: .body).lineHeight + 12)
        return CGSize(width: width, height: ceil(titleHeight + bodyHeight + inputHeight + 40))
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        axis == .vertical ? CGSize(width: collectionView.bounds.width, height: 56)
            : CGSize(width: 120, height: collectionView.bounds.height)
    }

    private func render(_ cell: UICollectionViewCell, at path: IndexPath, context: LanguageContext) {
        guard let cell = cell as? DemoCollectionCell, let id = id(at: path) else { return }
        cell.accessibilityIdentifier = "list.cell.\(id)"
        cell.localizedContent.bind(id: id, savedDraft: drafts[id] ?? "") { [weak self] id, value in self?.drafts[id] = value }
        cell.localizedContent.render(id: id, context: context)
        LayoutDirection.applyBoundary(context, to: cell)
        LayoutDirection.applyBoundary(context, to: cell.contentView)
    }
    private func id(at path: IndexPath) -> Int? { itemIDs.indices.contains(path.item) ? itemIDs[path.item] : nil }
    private func path(for id: AnyHashable) -> IndexPath? {
        guard let id = id.base as? Int, let item = itemIDs.firstIndex(of: id) else { return nil }
        return IndexPath(item: item, section: 0)
    }
}
