import UIKit

@MainActor
enum ContainerDemos {
    static func makeSplit(style: UISplitViewController.Style = .doubleColumn) -> LocalizedSplitViewController {
        let split = LocalizedSplitViewController(style: style)
        let primary = LocalizedNavigationController(root: SplitMenuViewController(),
                                                    tabTitle: .splitTitle, symbol: "sidebar.leading")
        let secondary = LocalizedNavigationController(root: DetailViewController(),
                                                      tabTitle: .detailTitle, symbol: "doc.text")
        split.restorationPrimary = primary
        split.restorationSecondary = secondary
        if style == .tripleColumn {
            let middle = LocalizedNavigationController(root: SplitMenuViewController(column: .supplementary),
                tabTitle: .splitMiddle, symbol: "list.bullet")
            split.restorationSupplementary = middle
            split.setViewController(middle, for: .supplementary)
            split.minimumPrimaryColumnWidth = 220
            split.maximumPrimaryColumnWidth = 280
            split.minimumSupplementaryColumnWidth = 240
            split.maximumSupplementaryColumnWidth = 300
        }
        split.setViewController(primary, for: .primary)
        split.setViewController(secondary, for: .secondary)
        split.setExpandedMode(style == .tripleColumn ? .twoBesideSecondary : .oneBesideSecondary)
        split.installDemoRestorationPolicy()
        split.modalPresentationStyle = .fullScreen
        return split
    }

    static func makePager(initialPageID: String = "page-2") -> LocalizedPageContainerController {
        LocalizedPageContainerController(pages: (1...3).map { index in
            .init(id: "page-\(index)", controller: DemoPageViewController(number: index))
        }, initialPageID: initialPageID, titleMessage: .pagesTitle)
    }
}

@MainActor
final class SplitMenuViewController: LocalizedViewController {
    let column: SavedSplitColumn
    let draftField = UITextField()
    init(column: SavedSplitColumn = .primary) { self.column = column; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("Use init(column:)") }
    private let picker = LanguagePickerView()
    private let showDetail = UIButton(type: .system)
    private let close = UIButton(type: .system)
    private let middle = UIButton(type: .system)
    private let push = UIButton(type: .system)
    private let expand = UIButton(type: .system)
    private let stack = UIStackView()

    override func buildUI() {
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        showDetail.configuration = .filled()
        showDetail.addAction(UIAction { [weak self] _ in
            (self?.splitViewController as? LocalizedSplitViewController)?.selectColumn(.secondary)
        }, for: .touchUpInside)
        close.configuration = .tinted()
        close.addAction(UIAction { [weak self] _ in self?.splitViewController?.dismiss(animated: true) }, for: .touchUpInside)
        draftField.borderStyle = .roundedRect
        draftField.accessibilityIdentifier = "split.\(column.rawValue).draft"
        middle.configuration = .tinted()
        middle.accessibilityIdentifier = "split.\(column.rawValue).middle"
        middle.addAction(UIAction { [weak self] _ in (self?.splitViewController as? LocalizedSplitViewController)?.selectColumn(.supplementary) }, for: .touchUpInside)
        middle.isHidden = splitViewController?.style != .tripleColumn
        push.configuration = .tinted()
        push.accessibilityIdentifier = "split.\(column.rawValue).push"
        push.addAction(UIAction { [weak self] _ in self?.navigationController?.pushViewController(DetailViewController(), animated: true) }, for: .touchUpInside)
        expand.configuration = .tinted()
        expand.accessibilityIdentifier = "split.\(column.rawValue).toggle"
        expand.addAction(UIAction { [weak self] _ in
            guard let split = self?.splitViewController as? LocalizedSplitViewController else { return }
            split.setExpandedMode(split.restorationExpandedMode == .secondaryOnly
                ? (split.style == .tripleColumn ? .twoBesideSecondary : .oneBesideSecondary) : .secondaryOnly)
        }, for: .touchUpInside)
        showDetail.accessibilityIdentifier = "split.\(column.rawValue).detail"
        close.accessibilityIdentifier = "split.\(column.rawValue).close"
        [picker, draftField, showDetail, middle, push, expand, close].forEach(stack.addArrangedSubview)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    override func applyLocalization(_ context: LanguageContext) {
        title = context.text(column == .primary ? .splitTitle : .splitMiddle)
        draftField.placeholder = context.text(.detailPlaceholder)
        draftField.accessibilityLabel = context.text(.detailDraft)
        LayoutDirection.applyTextField(context, to: draftField)
        middle.setTitle(context.text(.splitMiddle), for: .normal)
        push.setTitle(context.text(.splitPush), for: .normal)
        expand.setTitle(context.text(.splitToggle), for: .normal)
        picker.applyLocalization(context)
        showDetail.setTitle(context.text(.homeOpenDetail), for: .normal)
        close.setTitle(context.text(.commonClose), for: .normal)
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
        heading.text = context.text(.pagesNumber(number))
        heading.textAlignment = context.isRTL ? .right : .left
        draft.placeholder = context.text(.detailPlaceholder)
        draft.accessibilityLabel = context.text(.detailDraft)
        LayoutDirection.applyTextField(context, to: draft)
        previousButton.setTitle(context.text(.pagesPrevious), for: .normal)
        nextButton.setTitle(context.text(.pagesNext), for: .normal)
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
