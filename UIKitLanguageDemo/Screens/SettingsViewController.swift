import UIKit

@MainActor
final class SettingsViewController: LocalizedViewController, UITableViewDataSource, UITableViewDelegate {
    private let languagePicker = LanguagePickerView()
    private let appearancePicker = AppearancePickerView()
    let tableView = UITableView(frame: .zero, style: .plain)
    private let stack = UIStackView()
    let itemIDs = Array(0..<80)
    var drafts: [Int: String] = [:]
    var pendingListState: SavedListState?
    private(set) var localization: TableLocalizationCoordinator!

    override func buildUI() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.register(DemoTableCell.self, forCellReuseIdentifier: "row")
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "header")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 180
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 44
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(languagePicker)
        stack.addArrangedSubview(appearancePicker)
        stack.addArrangedSubview(tableView)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        localization = TableLocalizationCoordinator(tableView: tableView,
            itemID: { [weak self] path in self?.id(at: path).map(AnyHashable.init) },
            indexPath: { [weak self] id in self?.path(for: id) },
            renderCell: { [weak self] cell, path, context in self?.render(cell, at: path, context: context) },
            renderSupplementary: { [weak self] context in
                if let header = self?.tableView.headerView(forSection: 0) { self?.renderHeader(header, context) }
            })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        localization.refreshAfterAppearance()
        ListStateRestoration.applyIfNeeded(self)
    }

    override func applyLocalization(_ context: LanguageContext) {
        title = context.text(.settingsTitle)
        languagePicker.applyLocalization(context)
        LayoutDirection.applyScrollView(context, to: tableView)
        appearancePicker.applyLocalization(context)
        LayoutDirection.applyBoundary(context, to: stack)
        // Cells and scroll state are handled by the coordinator after window layout.
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { itemIDs.count }
    func tableView(_ tableView: UITableView, cellForRowAt path: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: path)
        render(cell, at: path, context: LanguageService.shared.context)
        return cell
    }
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt path: IndexPath) {
        render(cell, at: path, context: LanguageService.shared.context)
    }
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView { renderHeader(header, LanguageService.shared.context) }
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header")!
        renderHeader(header, LanguageService.shared.context)
        return header
    }

    private func renderHeader(_ header: UITableViewHeaderFooterView, _ context: LanguageContext) {
        var content = header.defaultContentConfiguration()
        content.text = context.text(.listSection)
        content.textProperties.alignment = .natural
        header.contentConfiguration = content
        LayoutDirection.applyBoundary(context, to: header)
    }
    private func render(_ cell: UITableViewCell, at path: IndexPath, context: LanguageContext) {
        guard let cell = cell as? DemoTableCell, let id = id(at: path) else { return }
        cell.accessibilityIdentifier = "list.cell.\(id)"
        cell.localizedContent.bind(id: id, savedDraft: drafts[id] ?? "") { [weak self] id, value in self?.drafts[id] = value }
        cell.localizedContent.render(id: id, context: context)
        LayoutDirection.applyBoundary(context, to: cell)
        LayoutDirection.applyBoundary(context, to: cell.contentView)
    }
    private func id(at path: IndexPath) -> Int? { itemIDs.indices.contains(path.row) ? itemIDs[path.row] : nil }
    private func path(for id: AnyHashable) -> IndexPath? {
        guard let id = id.base as? Int, let row = itemIDs.firstIndex(of: id) else { return nil }
        return IndexPath(row: row, section: 0)
    }
}
