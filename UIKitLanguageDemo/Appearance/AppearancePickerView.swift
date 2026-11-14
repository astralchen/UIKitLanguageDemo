import UIKit

@MainActor
final class AppearancePickerView: UIView, LocalizationUpdatable {
    private let heading = UILabel()
    private let control = UISegmentedControl(items: AppearanceSelection.allCases.map { $0.rawValue })
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        heading.font = .preferredFont(forTextStyle: .headline)
        heading.adjustsFontForContentSizeCategory = true
        heading.numberOfLines = 0
        control.accessibilityIdentifier = "appearance.selection"
        control.addTarget(self, action: #selector(selected), for: .valueChanged)
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        [heading, control].forEach(stack.addArrangedSubview)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(refreshSelection),
            name: .appAppearanceDidChange, object: AppearanceService.shared)
        applyLocalization(LanguageService.shared.context)
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    func applyLocalization(_ context: LanguageContext) {
        let semantic: UISemanticContentAttribute = context.isRTL ? .forceRightToLeft : .forceLeftToRight
        semanticContentAttribute = semantic
        stack.semanticContentAttribute = semantic
        control.semanticContentAttribute = semantic
        heading.text = context.text(.appearanceTitle)
        heading.textAlignment = context.isRTL ? .right : .left
        control.accessibilityLabel = context.text(.appearanceTitle)
        for (index, selection) in AppearanceSelection.allCases.enumerated() {
            control.setTitle(context.text(selection.title), forSegmentAt: index)
        }
        refreshSelection()
    }

    @objc private func selected() {
        let index = control.selectedSegmentIndex
        guard AppearanceSelection.allCases.indices.contains(index) else { return }
        AppearanceService.shared.setSelection(AppearanceSelection.allCases[index])
    }

    @objc private func refreshSelection() {
        control.selectedSegmentIndex = AppearanceSelection.allCases.firstIndex(of: AppearanceService.shared.selection)!
    }
}
