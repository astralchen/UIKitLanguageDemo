import UIKit

@MainActor
final class LanguagePickerView: UIView, LocalizationUpdatable {
    private let heading = UILabel()
    private let stack = UIStackView()
    private var buttons: [(LanguageSelection, UIButton)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        heading.font = .preferredFont(forTextStyle: .headline)
        heading.numberOfLines = 0
        heading.adjustsFontForContentSizeCategory = true
        stack.addArrangedSubview(heading)
        for selection in LanguageSelection.allCases {
            let button = UIButton(type: .system)
            button.configuration = .tinted()
            button.addAction(UIAction { _ in LanguageService.shared.setSelection(selection) }, for: .touchUpInside)
            buttons.append((selection, button))
            stack.addArrangedSubview(button)
        }
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        applyLocalization(LanguageService.shared.context)
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    func applyLocalization(_ context: LanguageContext) {
        // These rows follow the App's leading edge, regardless of the endonym's
        // script. Refresh explicit semantics before rebuilding configured content.
        let semantic: UISemanticContentAttribute = context.isRTL ? .forceRightToLeft : .forceLeftToRight
        semanticContentAttribute = semantic
        stack.semanticContentAttribute = semantic
        heading.text = context.text(.languageTitle)
        heading.textAlignment = context.isRTL ? .right : .left
        for (selection, button) in buttons {
            let selected = LanguageService.shared.selection == selection
            // UIKit may retain the configured content layout when an unchanged
            // endonym moves between LTR/RTL. Clear that configuration on a
            // direction change, keeping the UIButton and its actions intact.
            if button.semanticContentAttribute != semantic {
                button.configuration = nil
            }
            button.semanticContentAttribute = semantic
            button.contentHorizontalAlignment = context.isRTL ? .right : .left
            var config = UIButton.Configuration.tinted()
            config.titleAlignment = .leading
            config.title = selection.explicitLanguage?.nativeName ?? context.text(.languageSystem)
            config.image = selected ? UIImage(systemName: "checkmark.circle.fill") : nil
            config.imagePadding = 8
            config.imagePlacement = .trailing
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            button.configuration = config
            button.setNeedsLayout()
            button.accessibilityTraits = selected ? [.button, .selected] : [.button]
            button.accessibilityIdentifier = "language.\(selection.rawValue)"
        }
    }
}
