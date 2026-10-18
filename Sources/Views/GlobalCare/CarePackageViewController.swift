import UIKit

class CarePackageViewController: UIViewController {

    var context = GlobalCareFlowContext()
    private var packages: [GlobalCarePackage] = []
    private var packageCards: [UIView] = []
    private var selectedIndex: Int = 1

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let confirmButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = AppDesign.Color.primaryGreen
        btn.layer.cornerRadius = AppDesign.CornerRadius.button
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        navigationItem.title = t(.packageTitle)
        packages = GlobalCareMock.packages()
        setupLayout()
        renderPackages()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        confirmButton.setTitle(t(.packageConfirm), for: .normal)
        confirmButton.addTarget(self, action: #selector(goNext), for: .touchUpInside)
        view.addSubview(confirmButton)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: confirmButton.topAnchor, constant: -8),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: AppDesign.Layout.horizontalPadding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -AppDesign.Layout.horizontalPadding),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -AppDesign.Layout.horizontalPadding * 2),
            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppDesign.Layout.horizontalPadding),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppDesign.Layout.horizontalPadding),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            confirmButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func renderPackages() {
        clearPackageCards()
        packageCards = []
        for (i, pkg) in packages.enumerated() {
            let card = makePackageCard(pkg, index: i)
            packageCards.append(card)
            contentStack.addArrangedSubview(card)
        }
        updateSelection()
    }

    private func makePackageCard(_ pkg: GlobalCarePackage, index: Int) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.layer.borderWidth = 2
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        card.layer.shadowOffset = AppDesign.Shadow.cardOffset
        card.layer.shadowRadius = AppDesign.Shadow.cardRadius
        card.translatesAutoresizingMaskIntoConstraints = false
        card.tag = index

        let tap = UITapGestureRecognizer(target: self, action: #selector(selectPackage(_:)))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true

        let nameLabel = UILabel()
        nameLabel.text = pkg.tier.name(language: LocaleManager.shared.current)
        nameLabel.font = .systemFont(ofSize: 18, weight: .bold)
        nameLabel.textColor = .label
        nameLabel.textAlignment = .natural
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let priceLabel = UILabel()
        priceLabel.text = "USD $\(pkg.priceUSD)"
        priceLabel.font = .systemFont(ofSize: 22, weight: .heavy)
        priceLabel.textColor = AppDesign.Color.primaryGreen
        priceLabel.textAlignment = .natural
        priceLabel.translatesAutoresizingMaskIntoConstraints = false

        let featureStack = UIStackView()
        featureStack.axis = .vertical
        featureStack.spacing = 6
        featureStack.translatesAutoresizingMaskIntoConstraints = false
        pkg.features.forEach { feature in
            let row = UILabel()
            row.text = "✓  " + feature
            row.font = .systemFont(ofSize: 13)
            row.textColor = .secondaryLabel
            row.numberOfLines = 0
            row.textAlignment = .natural
            featureStack.addArrangedSubview(row)
        }

        card.addSubview(nameLabel)
        card.addSubview(priceLabel)
        card.addSubview(featureStack)
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            priceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            priceLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            featureStack.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 12),
            featureStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            featureStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            featureStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func updateSelection() {
        for (i, card) in packageCards.enumerated() {
            if i == selectedIndex {
                card.layer.borderColor = AppDesign.Color.primaryGreen.cgColor
            } else {
                card.layer.borderColor = UIColor.clear.cgColor
            }
        }
    }

    @objc private func selectPackage(_ gesture: UITapGestureRecognizer) {
        guard let idx = gesture.view?.tag else { return }
        selectedIndex = idx
        updateSelection()
    }

    @objc private func goNext() {
        context.selectedPackage = packages[selectedIndex]
        let vc = OrderConfirmViewController()
        vc.context = context
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func languageChanged() {
        navigationItem.title = t(.packageTitle)
        confirmButton.setTitle(t(.packageConfirm), for: .normal)
        renderPackages()
    }

    private func clearPackageCards() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }
}
