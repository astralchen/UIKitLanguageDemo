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
        heading.text = context.format("list.item", id + 1)
        detail.text = context.text("list.description")
        draft.placeholder = context.text("detail.placeholder")
        draft.accessibilityLabel = context.text("detail.draft")
        for label in [heading, detail] { label.textAlignment = context.isRTL ? .right : .left }
        // No assignment to draft.text during localization.
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
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    override var isSelected: Bool {
        didSet {
            contentView.layer.borderWidth = isSelected ? 2 : 0
            contentView.layer.borderColor = UIColor.systemBlue.cgColor
        }
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
    func render(_ context: LanguageContext, titleKey: String = "list.section") {
        label.text = context.text(titleKey)
        label.textAlignment = context.isRTL ? .right : .left
        LayoutDirection.applyBoundary(context, to: self)
    }
}
