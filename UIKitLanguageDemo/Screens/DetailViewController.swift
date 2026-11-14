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
        draftField.textAlignment = .natural
        draftField.accessibilityIdentifier = "detail.draft"
        // A semantic exception: phone numbers retain LTR even inside an RTL page.
        phoneLabel.text = "+86 138 0000 0000"
        phoneLabel.textAlignment = .left
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
        title = context.text("detail.title")
        heading.text = context.text("detail.description")
        draftLabel.text = context.text("detail.draft")
        draftField.placeholder = context.text("detail.placeholder")
        draftField.accessibilityLabel = context.text("detail.draft")
        // Never assign draftField.text here. The same input and VC instances survive.
        let formatter = NumberFormatter()
        formatter.locale = context.locale
        formatter.numberStyle = .decimal
        let number = formatter.string(from: NSNumber(value: 12345.67)) ?? "12345.67"
        numberLabel.text = context.format("detail.number", number)
        for label in [heading, draftLabel, numberLabel] {
            label.textAlignment = context.isRTL ? .right : .left
        }
        languagePicker.applyLocalization(context)
        LayoutDirection.applyBoundary(context, to: scrollView)
        LayoutDirection.applyBoundary(context, to: stack)
    }
}
