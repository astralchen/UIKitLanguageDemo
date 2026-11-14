import UIKit

@MainActor
final class HomeViewController: LocalizedViewController {
    private let heading = UILabel()
    private let openButton = UIButton(type: .system)
    private let tripleButton = UIButton(type: .system)
    private let splitButton = UIButton(type: .system)
    private let collectionButton = UIButton(type: .system)
    private let horizontalButton = UIButton(type: .system)
    private let compositionalButton = UIButton(type: .system)
    private let orthogonalButton = UIButton(type: .system)
    private let pageButton = UIButton(type: .system)

    override func buildUI() {
        heading.numberOfLines = 0
        heading.font = .preferredFont(forTextStyle: .title2)
        heading.adjustsFontForContentSizeCategory = true
        openButton.configuration = .filled()
        openButton.accessibilityIdentifier = "home.openDetail"
        openButton.addAction(UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(DetailViewController(), animated: true)
        }, for: .touchUpInside)
        splitButton.configuration = .tinted()
        splitButton.accessibilityIdentifier = "home.openSplit"
        splitButton.addAction(UIAction { [weak self] _ in
            self?.present(ContainerDemos.makeSplit(), animated: true)
        }, for: .touchUpInside)
        tripleButton.configuration = .tinted()
        tripleButton.accessibilityIdentifier = "home.openTripleSplit"
        tripleButton.addAction(UIAction { [weak self] _ in
            self?.present(ContainerDemos.makeSplit(style: .tripleColumn), animated: true)
        }, for: .touchUpInside)
        pageButton.configuration = .tinted()
        pageButton.accessibilityIdentifier = "home.openPager"
        pageButton.addAction(UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(ContainerDemos.makePager(), animated: true)
        }, for: .touchUpInside)
        collectionButton.configuration = .tinted()
        collectionButton.accessibilityIdentifier = "home.openCollection"
        collectionButton.addAction(UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(CollectionDemoViewController(), animated: true)
        }, for: .touchUpInside)
        horizontalButton.configuration = .tinted()
        horizontalButton.accessibilityIdentifier = "home.openHorizontalCollection"
        horizontalButton.addAction(UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(CollectionDemoViewController(axis: .horizontal), animated: true)
        }, for: .touchUpInside)
        compositionalButton.configuration = .tinted()
        compositionalButton.accessibilityIdentifier = "home.openCompositional"
        compositionalButton.addAction(UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(CompositionalDemoViewController(), animated: true)
        }, for: .touchUpInside)
        orthogonalButton.configuration = .tinted()
        orthogonalButton.accessibilityIdentifier = "home.openOrthogonal"
        orthogonalButton.addAction(UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(CompositionalDemoViewController(mode: .orthogonal), animated: true)
        }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [heading, openButton, splitButton, tripleButton, pageButton,
            collectionButton, horizontalButton, compositionalButton, orthogonalButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    override func applyLocalization(_ context: LanguageContext) {
        title = context.text(.homeTitle)
        // App-owned back title on the next screen; no reliance on the OS-generated "Back".
        navigationItem.backButtonTitle = context.text(.commonBack)
        heading.text = context.text(.homeDescription)
        heading.textAlignment = context.isRTL ? .right : .left
        var config = openButton.configuration!
        config.title = context.text(.homeOpenDetail)
        openButton.configuration = config
        tripleButton.setTitle(context.text(.splitTriple), for: .normal)
        splitButton.setTitle(context.text(.splitTitle), for: .normal)
        pageButton.setTitle(context.text(.pagesTitle), for: .normal)
        collectionButton.setTitle(context.text(.collectionTitle), for: .normal)
        horizontalButton.setTitle(context.text(.collectionHorizontal), for: .normal)
        compositionalButton.setTitle(context.text(.compositionalTitle), for: .normal)
        orthogonalButton.setTitle(context.text(.compositionalOrthogonal), for: .normal)
    }
}
