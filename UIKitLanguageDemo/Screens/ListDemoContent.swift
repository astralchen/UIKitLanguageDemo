import UIKit

@MainActor
final class ListDemoContent: UIView {
    let heading = UILabel()
    let detail = UILabel()
    let draft = UITextField()
    var itemID: Int?
    var draftChanged: ((Int, String) -> Void)?
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        heading.font = .preferredFont(forTextStyle: .headline)
        detail.font = .preferredFont(forTextStyle: .body)
        [heading, detail].forEach { $0.numberOfLines = 0; $0.adjustsFontForContentSizeCategory = true }
        draft.borderStyle = .roundedRect
        draft.font = .preferredFont(forTextStyle: .body)
        draft.adjustsFontForContentSizeCategory = true
        draft.addTarget(self, action: #selector(edited), for: .editingChanged)
        stack.axis = .vertical
        stack.spacing = 8
        [heading, detail, draft].forEach(stack.addArrangedSubview)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            draft.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    func bind(id: Int, savedDraft: String, changed: @escaping (Int, String) -> Void) {
        if itemID != id { draft.text = savedDraft }
        itemID = id
        heading.accessibilityIdentifier = "list.heading.\(id)"
        draft.accessibilityIdentifier = "list.draft.\(id)"
        draftChanged = changed
    }

    func render(id: Int, context: LanguageContext) {
        heading.text = context.text(.listItem(id + 1))
        detail.text = context.text(.listDescription)
        draft.placeholder = context.text(.detailPlaceholder)
        draft.accessibilityLabel = context.text(.detailDraft)
        LayoutDirection.applyTextField(context, to: draft)
        for label in [heading, detail] { label.textAlignment = context.isRTL ? .right : .left }
        // 本地化过程中不对 draft.text 赋值。
        LayoutDirection.applyBoundary(context, to: self)
        LayoutDirection.applyBoundary(context, to: stack)
    }

    @objc private func edited() {
        if let itemID { draftChanged?(itemID, draft.text ?? "") }
    }
}

@MainActor
final class DemoTableCell: UITableViewCell {
    let localizedContent = ListDemoContent()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        localizedContent.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(localizedContent)
        NSLayoutConstraint.activate([
            localizedContent.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            localizedContent.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            localizedContent.topAnchor.constraint(equalTo: contentView.topAnchor),
            localizedContent.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("Use init(style:reuseIdentifier:)") }
}

@MainActor
final class DemoCollectionCell: UICollectionViewCell {
    let localizedContent = ListDemoContent()
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        localizedContent.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(localizedContent)
        NSLayoutConstraint.activate([
            localizedContent.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            localizedContent.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            localizedContent.topAnchor.constraint(equalTo: contentView.topAnchor),
            localizedContent.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        if #available(iOS 17.0, *) {
            registerForTraitChanges(UITraitCollection.systemTraitsAffectingColorAppearance) {
                (cell: DemoCollectionCell, _: UITraitCollection) in cell.updateSelectionBorder()
            }
        }
        updateSelectionBorder()
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateSelectionBorder()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #unavailable(iOS 17.0), traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateSelectionBorder()
        }
    }

    override var isSelected: Bool {
        didSet { updateSelectionBorder() }
    }

    private func updateSelectionBorder() {
        contentView.layer.borderWidth = isSelected ? 2 : 0
        // CALayer 保存的是静态 CGColor，需要根据 cell 当前的 traits 重新解析。
        contentView.layer.borderColor = UIColor.systemBlue.resolvedColor(with: traitCollection).cgColor
    }
}

@MainActor
final class DemoCollectionHeader: UICollectionReusableView {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .preferredFont(forTextStyle: .headline)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    func render(_ context: LanguageContext, titleMessage: AppText = .listSection) {
        label.text = context.text(titleMessage)
        label.textAlignment = context.isRTL ? .right : .left
        LayoutDirection.applyBoundary(context, to: self)
    }
}
