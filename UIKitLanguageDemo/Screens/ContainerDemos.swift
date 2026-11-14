import UIKit

@MainActor
enum ContainerDemos {
    static func makeSplit() -> LocalizedSplitViewController {
        let split = LocalizedSplitViewController(style: .doubleColumn)
        let primary = LocalizedNavigationController(root: SplitMenuViewController(),
                                                    tabTitleKey: "split.title", symbol: "sidebar.leading")
        let secondary = LocalizedNavigationController(root: DetailViewController(),
                                                      tabTitleKey: "detail.title", symbol: "doc.text")
        split.restorationPrimary = primary
        split.restorationSecondary = secondary
        split.setViewController(primary, for: .primary)
        split.setViewController(secondary, for: .secondary)
        split.preferredDisplayMode = .oneBesideSecondary
        split.modalPresentationStyle = .fullScreen
        return split
    }

    static func makePager(initialPageID: String = "page-2") -> LocalizedPageContainerController {
        LocalizedPageContainerController(pages: (1...3).map { index in
            .init(id: "page-\(index)", controller: DemoPageViewController(number: index))
        }, initialPageID: initialPageID, titleKey: "pages.title")
    }
}

@MainActor
final class SplitMenuViewController: LocalizedViewController {
    private let picker = LanguagePickerView()
    private let showDetail = UIButton(type: .system)
    private let close = UIButton(type: .system)
    private let stack = UIStackView()

    override func buildUI() {
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        showDetail.configuration = .filled()
        showDetail.addAction(UIAction { [weak self] _ in
            (self?.splitViewController as? LocalizedSplitViewController)?.restorationShowsSecondary = true
            self?.splitViewController?.show(.secondary)
        }, for: .touchUpInside)
        close.configuration = .tinted()
        close.addAction(UIAction { [weak self] _ in self?.splitViewController?.dismiss(animated: true) }, for: .touchUpInside)
        [picker, showDetail, close].forEach(stack.addArrangedSubview)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    override func applyLocalization(_ context: LanguageContext) {
        title = context.text("split.title")
        picker.applyLocalization(context)
        showDetail.setTitle(context.text("home.open_detail"), for: .normal)
        close.setTitle(context.text("common.close"), for: .normal)
        LayoutDirection.applyBoundary(context, to: stack)
    }
}

@MainActor
final class DemoPageViewController: LocalizedViewController {
    private let number: Int
    private let heading = UILabel()
    let draft = UITextField()
    private let picker = LanguagePickerView()
    private let previousButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let buttons = UIStackView()
    private let stack = UIStackView()

    init(number: Int) { self.number = number; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("Use init(number:)") }

    override func buildUI() {
        view.accessibilityIdentifier = "pager.page-\(number)"
        heading.font = .preferredFont(forTextStyle: .title2)
        heading.adjustsFontForContentSizeCategory = true
        heading.numberOfLines = 0
        draft.borderStyle = .roundedRect
        draft.accessibilityIdentifier = "pager.draft-\(number)"
        previousButton.configuration = .tinted()
        nextButton.configuration = .filled()
        previousButton.addAction(UIAction { [weak self] _ in self?.pager?.previousPage() }, for: .touchUpInside)
        nextButton.addAction(UIAction { [weak self] _ in self?.pager?.nextPage() }, for: .touchUpInside)
        buttons.spacing = 12
        buttons.distribution = .fillEqually
        buttons.addArrangedSubview(previousButton)
        buttons.addArrangedSubview(nextButton)
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        [heading, draft, buttons, picker].forEach(stack.addArrangedSubview)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            draft.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    override func applyLocalization(_ context: LanguageContext) {
        heading.text = context.format("pages.number", number)
        heading.textAlignment = context.isRTL ? .right : .left
        draft.placeholder = context.text("detail.placeholder")
        previousButton.setTitle(context.text("pages.previous"), for: .normal)
        nextButton.setTitle(context.text("pages.next"), for: .normal)
        previousButton.isEnabled = number > 1
        nextButton.isEnabled = number < 3
        picker.applyLocalization(context)
        LayoutDirection.applyBoundary(context, to: stack)
        LayoutDirection.applyBoundary(context, to: buttons)
    }

    private var pager: LocalizedPageContainerController? {
        var ancestor = parent
        while let controller = ancestor {
            if let pager = controller as? LocalizedPageContainerController { return pager }
            ancestor = controller.parent
        }
        return nil
    }
}
