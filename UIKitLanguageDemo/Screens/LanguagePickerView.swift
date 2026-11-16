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
        // 这些行始终对齐 App 的 leading 边缘，不受语言自称所用文字的影响。
        // 重建配置内容前，先刷新显式语义方向。
        let semantic: UISemanticContentAttribute = context.isRTL ? .forceRightToLeft : .forceLeftToRight
        semanticContentAttribute = semantic
        stack.semanticContentAttribute = semantic
        heading.text = context.text(.languageTitle)
        heading.textAlignment = context.isRTL ? .right : .left
        for (selection, button) in buttons {
            let selected = LanguageService.shared.selection == selection
            // 同一语言自称在 LTR/RTL 之间切换时，UIKit 可能保留原有的配置内容布局。
            // 因此在方向变化时清除该配置，
            // 同时保留 UIButton 及其 actions。
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
