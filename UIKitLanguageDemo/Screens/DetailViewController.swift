import UIKit

@MainActor
final class DetailViewController: LocalizedViewController {
    let draftField = UITextField()
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let heading = UILabel()
    private let draftLabel = UILabel()
    private let numberLabel = UILabel()
    private let languagePicker = LanguagePickerView()
    private let phoneLabel = UILabel()

    override func buildUI() {
        view.accessibilityIdentifier = "detail.screen"
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        for label in [heading, draftLabel, numberLabel, phoneLabel] {
            label.numberOfLines = 0
            label.font = .preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true
        }
        draftField.borderStyle = .roundedRect
        draftField.font = .preferredFont(forTextStyle: .body)
        draftField.adjustsFontForContentSizeCategory = true
        draftField.accessibilityIdentifier = "detail.draft"
        // 语义方向的例外：电话号码即使位于 RTL 页面中，也保持 LTR。
        phoneLabel.text = "+86 138 0000 0000"
        phoneLabel.accessibilityIdentifier = "detail.phone"
        phoneLabel.semanticContentAttribute = .forceLeftToRight
        for item in [heading, draftLabel, draftField, numberLabel, languagePicker, phoneLabel] {
            stack.addArrangedSubview(item)
        }
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
            draftField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    override func applyLocalization(_ context: LanguageContext) {
        title = context.text(.detailTitle)
        heading.text = context.text(.detailDescription)
        draftLabel.text = context.text(.detailDraft)
        draftField.placeholder = context.text(.detailPlaceholder)
        draftField.accessibilityLabel = context.text(.detailDraft)
        LayoutDirection.applyTextField(context, to: draftField)
        // 此处不得给 draftField.text 赋值，以保留原有输入控件和 VC 实例。
        let formatter = NumberFormatter()
        formatter.locale = context.locale
        formatter.numberStyle = .decimal
        let number = formatter.string(from: NSNumber(value: 12345.67)) ?? "12345.67"
        numberLabel.text = context.text(.detailNumber(number))
        for label in [heading, draftLabel, numberLabel] {
            label.textAlignment = context.isRTL ? .right : .left
        }
        // 位置跟随 App 方向，但完整的国际电话号码作为一个 LTR 段落处理，
        // 确保 +86 和所有数字保持正确的视觉顺序。
        let phoneParagraph = NSMutableParagraphStyle()
        phoneParagraph.baseWritingDirection = .leftToRight
        phoneParagraph.alignment = context.isRTL ? .right : .left
        phoneLabel.textAlignment = phoneParagraph.alignment
        phoneLabel.attributedText = NSAttributedString(string: "+86 138 0000 0000",
            attributes: [.paragraphStyle: phoneParagraph])
        languagePicker.applyLocalization(context)
        LayoutDirection.applyScrollView(context, to: scrollView)
        LayoutDirection.applyBoundary(context, to: stack)
    }
}
