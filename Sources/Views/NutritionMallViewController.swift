import UIKit
import SafariServices

final class NutritionMallViewController: UIViewController {
    private struct BannerItem {
        let titleKey: L10nKey
        let subtitleKey: L10nKey
        let accent: UIColor
        let symbolName: String
        let url: String
    }

    private struct CategoryItem {
        let id: String
        let key: L10nKey
    }

    private struct ProductItem {
        let name: String
        let subtitle: String
        let categoryId: String
        let price: String
        let marketPrice: String
        let badge: String
        let accent: UIColor
        let symbolName: String
        let url: String
    }

    private let banners: [BannerItem] = [
        BannerItem(titleKey: .nutritionBanner1Title, subtitleKey: .nutritionBanner1Subtitle, accent: UIColor(red: 0.98, green: 0.40, blue: 0.35, alpha: 1.0), symbolName: "tag.fill", url: "https://example.com/nutrition/campaign"),
        BannerItem(titleKey: .nutritionBanner2Title, subtitleKey: .nutritionBanner2Subtitle, accent: UIColor(red: 0.28, green: 0.55, blue: 0.98, alpha: 1.0), symbolName: "person.text.rectangle.fill", url: "https://example.com/nutrition/consult"),
        BannerItem(titleKey: .nutritionBanner3Title, subtitleKey: .nutritionBanner3Subtitle, accent: UIColor(red: 0.31, green: 0.73, blue: 0.54, alpha: 1.0), symbolName: "shippingbox.fill", url: "https://example.com/nutrition/global"),
    ]

    private let categoryItems: [CategoryItem] = [
        CategoryItem(id: "all", key: .nutritionCatAll),
        CategoryItem(id: "bestsellers", key: .nutritionCatBestsellers),
        CategoryItem(id: "basic", key: .nutritionCatBasic),
        CategoryItem(id: "cardio", key: .nutritionCatCardio),
        CategoryItem(id: "sleep", key: .nutritionCatSleep),
        CategoryItem(id: "antiaging", key: .nutritionCatAntiAging),
        CategoryItem(id: "gut", key: .nutritionCatGut),
    ]

    private let products: [ProductItem] = [
        ProductItem(name: "Fish Oil 95%", subtitle: "Omega-3", categoryId: "bestsellers", price: "¥59/mo", marketPrice: "¥200-¥500", badge: "In Stock · 86% Off", accent: UIColor(red: 0.28, green: 0.63, blue: 0.99, alpha: 1.0), symbolName: "drop.fill", url: "https://example.com/nutrition/fish-oil"),
        ProductItem(name: "NMN 60000", subtitle: "4-8 months", categoryId: "antiaging", price: "¥65/mo", marketPrice: "¥3200-¥5000", badge: "In Stock · 87% Off", accent: UIColor(red: 0.53, green: 0.72, blue: 0.99, alpha: 1.0), symbolName: "capsule.fill", url: "https://example.com/nutrition/nmn"),
        ProductItem(name: "CoQ10 Ubiquinol", subtitle: "Kaneka", categoryId: "cardio", price: "¥89/mo", marketPrice: "¥300-¥600", badge: "In Stock · 90% Off", accent: UIColor(red: 0.91, green: 0.30, blue: 0.28, alpha: 1.0), symbolName: "heart.circle.fill", url: "https://example.com/nutrition/q10"),
        ProductItem(name: "AKK Probiotic", subtitle: "Gut Care", categoryId: "gut", price: "¥139/mo", marketPrice: "¥700-¥3000", badge: "In Stock · 93% Off", accent: UIColor(red: 0.67, green: 0.82, blue: 0.98, alpha: 1.0), symbolName: "aqi.medium", url: "https://example.com/nutrition/akk"),
        ProductItem(name: "Magnesium L-Threonate", subtitle: "Sleep Support", categoryId: "sleep", price: "¥379/4mo", marketPrice: "¥1000/4mo", badge: "In Stock", accent: UIColor(red: 0.74, green: 0.77, blue: 0.83, alpha: 1.0), symbolName: "moon.zzz.fill", url: "https://example.com/nutrition/magnesium"),
        ProductItem(name: "Curcumin BCM-95", subtitle: "Joint & Inflammation", categoryId: "basic", price: "¥74/mo", marketPrice: "¥250-¥500", badge: "In Stock · 95% Off", accent: UIColor(red: 0.98, green: 0.73, blue: 0.22, alpha: 1.0), symbolName: "sun.max.fill", url: "https://example.com/nutrition/curcumin"),
        ProductItem(name: "Vitamin D3+K2+Ca", subtitle: "Bone & Immunity", categoryId: "basic", price: "¥58/mo", marketPrice: "¥180-¥420", badge: "Hot Combo", accent: UIColor(red: 0.98, green: 0.84, blue: 0.48, alpha: 1.0), symbolName: "bolt.heart.fill", url: "https://example.com/nutrition/d3k2"),
        ProductItem(name: "Sleep Relief Formula", subtitle: "Melatonin + L-Theanine", categoryId: "sleep", price: "¥79/mo", marketPrice: "¥220-¥480", badge: "Night Pick", accent: UIColor(red: 0.49, green: 0.57, blue: 0.98, alpha: 1.0), symbolName: "bed.double.fill", url: "https://example.com/nutrition/sleep"),
    ]

    private var selectedCategoryId = "all"
    private var categoryButtons: [UIButton] = []

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsVerticalScrollIndicator = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let categoryStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let gridStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
        applyLocalization()
        setupLayout()
        rebuildCategoryButtons()
        rebuildProductGrid()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func languageChanged() {
        applyLocalization()
        rebuildAll()
    }

    private func applyLocalization() {
        title = t(.nutritionTitle)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: t(.nutritionAllProducts), style: .plain, target: self, action: #selector(openAllProducts))
    }

    private func rebuildAll() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        contentStack.addArrangedSubview(makeSearchBar())
        contentStack.addArrangedSubview(makeBannerSection())
        contentStack.addArrangedSubview(makeCategorySection())
        contentStack.addArrangedSubview(makeConsultCard())
        contentStack.addArrangedSubview(makeProductsHeader())
        contentStack.addArrangedSubview(gridStack)
        contentStack.addArrangedSubview(makeDemoFooter())
        rebuildCategoryButtons()
        rebuildProductGrid()
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        contentStack.addArrangedSubview(makeSearchBar())
        contentStack.addArrangedSubview(makeBannerSection())
        contentStack.addArrangedSubview(makeCategorySection())
        contentStack.addArrangedSubview(makeConsultCard())
        contentStack.addArrangedSubview(makeProductsHeader())
        contentStack.addArrangedSubview(gridStack)
        contentStack.addArrangedSubview(makeDemoFooter())
    }

    private func makeSearchBar() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = .secondaryLabel
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = t(.nutritionSearchPlaceholder)
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15)
        label.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.setTitle(t(.nutritionSearchButton), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.addTarget(self, action: #selector(openAllProducts), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(icon)
        container.addSubview(label)
        container.addSubview(button)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -8)
        ])

        return container
    }

    private func makeBannerSection() -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 144).isActive = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        banners.enumerated().forEach { (_, item) in
            let card = UIButton(type: .system)
            card.backgroundColor = item.accent
            card.layer.cornerRadius = 22
            card.contentHorizontalAlignment = .fill
            card.contentVerticalAlignment = .fill
            card.heightAnchor.constraint(equalToConstant: 144).isActive = true
            card.widthAnchor.constraint(equalToConstant: 288).isActive = true
            card.accessibilityHint = item.url
            card.addTarget(self, action: #selector(bannerTapped(_:)), for: .touchUpInside)

            let symbol = UIImageView(image: UIImage(systemName: item.symbolName))
            symbol.tintColor = .white
            symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 32, weight: .bold)
            symbol.translatesAutoresizingMaskIntoConstraints = false

            let title = UILabel()
            title.text = t(item.titleKey)
            title.font = .systemFont(ofSize: 24, weight: .bold)
            title.textColor = .white
            title.numberOfLines = 2
            title.translatesAutoresizingMaskIntoConstraints = false

            let subtitle = UILabel()
            subtitle.text = t(item.subtitleKey)
            subtitle.font = .systemFont(ofSize: 13, weight: .medium)
            subtitle.textColor = UIColor.white.withAlphaComponent(0.92)
            subtitle.numberOfLines = 2
            subtitle.translatesAutoresizingMaskIntoConstraints = false

            card.addSubview(symbol)
            card.addSubview(title)
            card.addSubview(subtitle)

            NSLayoutConstraint.activate([
                symbol.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
                symbol.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
                title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
                title.trailingAnchor.constraint(equalTo: symbol.leadingAnchor, constant: -12),
                title.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
                subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                subtitle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
                subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10)
            ])

            stack.addArrangedSubview(card)
        }

        return scroll
    }

    private func makeCategorySection() -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 40).isActive = true
        scroll.addSubview(categoryStack)

        NSLayoutConstraint.activate([
            categoryStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            categoryStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            categoryStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            categoryStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            categoryStack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        return scroll
    }

    private func makeConsultCard() -> UIView {
        let button = UIButton(type: .system)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 20
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 88).isActive = true
        button.addTarget(self, action: #selector(openConsultLink), for: .touchUpInside)

        let icon = UIImageView(image: UIImage(systemName: "person.crop.circle.badge.questionmark"))
        icon.tintColor = .label
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = t(.nutritionConsultTitle)
        title.font = .systemFont(ofSize: 24, weight: .bold)
        title.textColor = .label
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = t(.nutritionConsultSubtitle)
        subtitle.font = .systemFont(ofSize: 14, weight: .medium)
        subtitle.textColor = .secondaryLabel
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let tag = UILabel()
        tag.text = t(.nutritionConsultTag)
        tag.font = .systemFont(ofSize: 12, weight: .semibold)
        tag.textColor = .white
        tag.backgroundColor = UIColor(red: 0.37, green: 0.57, blue: 1.0, alpha: 1.0)
        tag.textAlignment = .center
        tag.layer.cornerRadius = 11
        tag.clipsToBounds = true
        tag.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(icon)
        button.addSubview(title)
        button.addSubview(subtitle)
        button.addSubview(tag)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            title.topAnchor.constraint(equalTo: button.topAnchor, constant: 18),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            subtitle.trailingAnchor.constraint(lessThanOrEqualTo: tag.leadingAnchor, constant: -8),
            tag.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
            tag.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            tag.widthAnchor.constraint(equalToConstant: 76),
            tag.heightAnchor.constraint(equalToConstant: 22)
        ])

        return button
    }

    private func makeProductsHeader() -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let title = UILabel()
        title.text = t(.nutritionProductsHeader)
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let action = UIButton(type: .system)
        action.setTitle(t(.nutritionViewAll), for: .normal)
        action.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        action.addTarget(self, action: #selector(openAllProducts), for: .touchUpInside)
        action.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(title)
        row.addSubview(action)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            title.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            action.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            action.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func makeDemoFooter() -> UIView {
        let label = UILabel()
        label.text = t(.nutritionFooter)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    private func rebuildCategoryButtons() {
        categoryStack.arrangedSubviews.forEach {
            categoryStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        categoryButtons.removeAll()

        for (index, cat) in categoryItems.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(t(cat.key), for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            button.contentEdgeInsets = UIEdgeInsets(top: 9, left: 16, bottom: 9, right: 16)
            button.layer.cornerRadius = 18
            button.tag = index
            button.backgroundColor = cat.id == selectedCategoryId ? .label : .secondarySystemBackground
            button.setTitleColor(cat.id == selectedCategoryId ? .systemBackground : .label, for: .normal)
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            categoryButtons.append(button)
            categoryStack.addArrangedSubview(button)
        }
    }

    private func rebuildProductGrid() {
        gridStack.arrangedSubviews.forEach {
            gridStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let filteredProducts = selectedCategoryId == "all" ? products : products.filter { $0.categoryId == selectedCategoryId }

        stride(from: 0, to: filteredProducts.count, by: 2).forEach { index in
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12
            row.distribution = .fillEqually

            row.addArrangedSubview(makeProductCard(filteredProducts[index]))
            if index + 1 < filteredProducts.count {
                row.addArrangedSubview(makeProductCard(filteredProducts[index + 1]))
            } else {
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                row.addArrangedSubview(spacer)
            }
            gridStack.addArrangedSubview(row)
        }
    }

    private func makeProductCard(_ product: ProductItem) -> UIView {
        let button = UIButton(type: .system)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 20
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 222).isActive = true
        button.accessibilityHint = product.url
        button.addTarget(self, action: #selector(productTapped(_:)), for: .touchUpInside)

        let name = UILabel()
        name.text = product.name
        name.font = .systemFont(ofSize: 19, weight: .bold)
        name.textColor = .label
        name.numberOfLines = 2
        name.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = product.subtitle
        subtitle.font = .systemFont(ofSize: 11, weight: .semibold)
        subtitle.textColor = .secondaryLabel
        subtitle.backgroundColor = UIColor.systemGray6
        subtitle.textAlignment = .center
        subtitle.layer.cornerRadius = 8
        subtitle.clipsToBounds = true
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let price = UILabel()
        price.text = product.price
        price.font = .systemFont(ofSize: 24, weight: .bold)
        price.textColor = UIColor(red: 0.24, green: 0.49, blue: 0.98, alpha: 1.0)
        price.translatesAutoresizingMaskIntoConstraints = false

        let marketPrice = UILabel()
        marketPrice.text = "\(t(.nutritionMarketPricePrefix)) \(product.marketPrice)"
        marketPrice.font = .systemFont(ofSize: 11)
        marketPrice.textColor = .tertiaryLabel
        marketPrice.translatesAutoresizingMaskIntoConstraints = false

        let badge = UILabel()
        badge.text = product.badge
        badge.font = .systemFont(ofSize: 11, weight: .semibold)
        badge.textColor = UIColor(red: 0.24, green: 0.49, blue: 0.98, alpha: 1.0)
        badge.translatesAutoresizingMaskIntoConstraints = false

        let imagePlate = UIView()
        imagePlate.backgroundColor = product.accent.withAlphaComponent(0.16)
        imagePlate.layer.cornerRadius = 28
        imagePlate.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: product.symbolName))
        icon.tintColor = product.accent
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
        icon.translatesAutoresizingMaskIntoConstraints = false

        imagePlate.addSubview(icon)
        button.addSubview(name)
        button.addSubview(subtitle)
        button.addSubview(price)
        button.addSubview(marketPrice)
        button.addSubview(badge)
        button.addSubview(imagePlate)

        NSLayoutConstraint.activate([
            name.topAnchor.constraint(equalTo: button.topAnchor, constant: 14),
            name.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14),
            name.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
            subtitle.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 8),
            subtitle.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            subtitle.widthAnchor.constraint(greaterThanOrEqualToConstant: 54),
            subtitle.heightAnchor.constraint(equalToConstant: 18),
            price.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            price.bottomAnchor.constraint(equalTo: marketPrice.topAnchor, constant: -4),
            marketPrice.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            marketPrice.bottomAnchor.constraint(equalTo: badge.topAnchor, constant: -6),
            badge.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            badge.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -14),
            imagePlate.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
            imagePlate.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -14),
            imagePlate.widthAnchor.constraint(equalToConstant: 56),
            imagePlate.heightAnchor.constraint(equalToConstant: 56),
            icon.centerXAnchor.constraint(equalTo: imagePlate.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: imagePlate.centerYAnchor)
        ])

        return button
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index >= 0, index < categoryItems.count else { return }
        selectedCategoryId = categoryItems[index].id
        rebuildCategoryButtons()
        rebuildProductGrid()
    }

    @objc private func bannerTapped(_ sender: UIButton) {
        openPlaceholderLink(from: sender)
    }

    @objc private func productTapped(_ sender: UIButton) {
        openPlaceholderLink(from: sender)
    }

    @objc private func openConsultLink() {
        present(SFSafariViewController(url: URL(string: "https://example.com/nutrition/consult")!), animated: true)
    }

    @objc private func openAllProducts() {
        present(SFSafariViewController(url: URL(string: "https://example.com/nutrition/catalog")!), animated: true)
    }

    private func openPlaceholderLink(from sender: UIButton) {
        guard let urlString = sender.accessibilityHint, let url = URL(string: urlString) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }
}
