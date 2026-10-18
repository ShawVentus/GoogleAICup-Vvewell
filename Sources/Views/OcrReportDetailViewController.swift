import UIKit

final class OcrRowView: UIControl {
    let report: OcrReport

    init(report: OcrReport) {
        self.report = report
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class OcrReportDetailViewController: UIViewController {
    private let report: OcrReport
    private let dateFormatter: DateFormatter
    private let onDelete: ((OcrReport) -> Void)?

    init(report: OcrReport, dateFormatter: DateFormatter, onDelete: ((OcrReport) -> Void)? = nil) {
        self.report = report
        self.dateFormatter = dateFormatter
        self.onDelete = onDelete
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ocrPageBackgroundColor()
        title = t(.ocrReportDetailTitle)
        enableInteractiveBackSwipeIfNeeded()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: t(.ocrDeleteReport),
            style: .plain,
            target: self,
            action: #selector(deleteTapped)
        )

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])

        let abnormalItems = report.items.filter(\.isAbnormal)
        let normalItems = report.items.filter { !$0.isAbnormal }

        stack.addArrangedSubview(makeOverviewCard(abnormalItems: abnormalItems))

        if !abnormalItems.isEmpty {
            stack.addArrangedSubview(
                OcrDetailDisclosureSectionView(
                    title: t(.ocrReportAbnormalSectionTitle),
                    badgeText: String(format: t(.ocrReportAbnormalCountFormat), abnormalItems.count),
                    badgeTint: .systemOrange,
                    initiallyExpanded: true,
                    contentViews: abnormalItems.map(makeMetricCard)
                )
            )
        }

        if !normalItems.isEmpty {
            stack.addArrangedSubview(
                OcrDetailDisclosureSectionView(
                    title: t(.ocrReportNormalSectionTitle),
                    badgeText: "\(normalItems.count)",
                    badgeTint: AppDesign.Color.primaryGreen,
                    initiallyExpanded: abnormalItems.isEmpty,
                    contentViews: normalItems.map(makeMetricCard)
                )
            )
        }
    }

    @objc private func deleteTapped() {
        let alert = UIAlertController(title: t(.ocrDeleteReport), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        alert.addAction(UIAlertAction(title: t(.ocrDeleteReport), style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.onDelete?(self.report)
        })
        present(alert, animated: true)
    }

    private func enableInteractiveBackSwipeIfNeeded() {
        guard navigationController?.viewControllers.first !== self else { return }
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }

    private func makeOverviewCard(abnormalItems: [OcrReport.OcrItem]) -> UIView {
        let card = UIView()
        card.backgroundColor = ocrCardSurfaceColor()
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.12).cgColor
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.05
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.layer.shadowRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconWrap = UIView()
        iconWrap.backgroundColor = AppDesign.Color.primaryGreen.withAlphaComponent(0.12)
        iconWrap.layer.cornerRadius = 20
        iconWrap.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "doc.text.magnifyingglass"))
        icon.tintColor = AppDesign.Color.primaryGreen
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.addSubview(icon)

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.text = t(.ocrReportOverviewTitle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.text = overviewSummaryText(abnormalItems: abnormalItems)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let badgeRow = UIStackView(arrangedSubviews: [
            makeBadge(text: abnormalItems.isEmpty ? t(.ocrReportAllNormal) : String(format: t(.ocrReportAbnormalCountFormat), abnormalItems.count), tint: abnormalItems.isEmpty ? AppDesign.Color.primaryGreen : .systemOrange)
        ])
        badgeRow.axis = .horizontal
        badgeRow.spacing = 8
        badgeRow.alignment = .center
        badgeRow.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconWrap)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(badgeRow)

        NSLayoutConstraint.activate([
            iconWrap.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconWrap.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconWrap.widthAnchor.constraint(equalToConstant: 40),
            iconWrap.heightAnchor.constraint(equalToConstant: 40),

            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconWrap.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            badgeRow.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            badgeRow.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            badgeRow.trailingAnchor.constraint(lessThanOrEqualTo: titleLabel.trailingAnchor),
            badgeRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func overviewSummaryText(abnormalItems: [OcrReport.OcrItem]) -> String {
        let metricsSummary = abnormalItems.isEmpty
            ? String(format: t(.ocrReportMetricsNormalFormat), report.items.count)
            : String(format: t(.ocrReportMetricsAbnormalFormat), report.items.count, abnormalItems.count)
        let findingsText: String
        if abnormalItems.isEmpty {
            findingsText = t(.ocrReportAllNormal)
        } else {
            let formatter = ListFormatter()
            formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
            let names = abnormalItems.prefix(3).map(\.name)
            findingsText = formatter.string(from: names) ?? names.joined(separator: " · ")
        }
        let reportDateText: String = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: report.date)
        }()
        return [
            reportDateText,
            metricsSummary,
            findingsText
        ].joined(separator: "\n")
    }

    private func makeMetricCard(item: OcrReport.OcrItem) -> UIView {
        let card = UIView()
        card.backgroundColor = item.isAbnormal ? ocrAbnormalSurfaceColor() : ocrSecondarySurfaceColor()
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        card.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let nameLabel = UILabel()
        nameLabel.text = item.name
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.78
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = item.value
        valueLabel.font = .systemFont(ofSize: 16, weight: .bold)
        valueLabel.textColor = item.isAbnormal ? .systemOrange : .label
        valueLabel.textAlignment = .center
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.8
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let referenceLabel = UILabel()
        referenceLabel.text = item.reference.isEmpty ? "—" : item.reference
        referenceLabel.font = .systemFont(ofSize: 13)
        referenceLabel.textColor = .secondaryLabel
        referenceLabel.textAlignment = .right
        referenceLabel.numberOfLines = 1
        referenceLabel.adjustsFontSizeToFitWidth = true
        referenceLabel.minimumScaleFactor = 0.75
        referenceLabel.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [nameLabel, valueLabel, referenceLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.distribution = .fill
        row.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true
        referenceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true

        card.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])

        return card
    }

    private func makeBadge(text: String, tint: UIColor) -> UIView {
        let label = OcrDetailPaddingLabel()
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = tint
        label.backgroundColor = tint.withAlphaComponent(0.10)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.insets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        return label
    }

    private func ocrPageBackgroundColor() -> UIColor {
        UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.05, green: 0.07, blue: 0.08, alpha: 1.0)
            }
            return .systemGroupedBackground
        }
    }

    private func ocrCardSurfaceColor() -> UIColor {
        UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.10, green: 0.12, blue: 0.13, alpha: 1.0)
            }
            return .systemBackground
        }
    }

    private func ocrSecondarySurfaceColor() -> UIColor {
        UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.16, green: 0.18, blue: 0.20, alpha: 1.0)
            }
            return .secondarySystemBackground
        }
    }

    private func ocrAbnormalSurfaceColor() -> UIColor {
        UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor.systemOrange.withAlphaComponent(0.18)
            }
            return UIColor.systemOrange.withAlphaComponent(0.08)
        }
    }
}

private final class OcrDetailDisclosureSectionView: UIView {
    private let contentStack = UIStackView()
    private let toggleButton = UIButton(type: .system)
    private let titleText: String
    private var expanded: Bool
    private var contentTopConstraint: NSLayoutConstraint?
    private var contentBottomConstraint: NSLayoutConstraint?
    private var collapsedBottomConstraint: NSLayoutConstraint?

    init(
        title: String,
        badgeText: String,
        badgeTint: UIColor,
        initiallyExpanded: Bool,
        contentViews: [UIView]
    ) {
        self.titleText = title
        self.expanded = initiallyExpanded
        super.init(frame: .zero)

        backgroundColor = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.10, green: 0.12, blue: 0.13, alpha: 1.0)
            }
            return .systemBackground
        }
        layer.cornerRadius = 18
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.withAlphaComponent(0.12).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        toggleButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        toggleButton.setTitleColor(.label, for: .normal)
        toggleButton.contentHorizontalAlignment = directionalContentHorizontalAlignment()
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        toggleButton.addTarget(self, action: #selector(toggleExpanded), for: .touchUpInside)

        let badge = OcrDetailPaddingLabel()
        badge.text = badgeText
        badge.font = .systemFont(ofSize: 11, weight: .semibold)
        badge.textColor = badgeTint
        badge.backgroundColor = badgeTint.withAlphaComponent(0.10)
        badge.layer.cornerRadius = 10
        badge.layer.masksToBounds = true
        badge.insets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        badge.translatesAutoresizingMaskIntoConstraints = false

        headerRow.addArrangedSubview(toggleButton)
        headerRow.addArrangedSubview(badge)

        contentStack.axis = .vertical
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentViews.forEach { contentStack.addArrangedSubview($0) }

        addSubview(headerRow)
        addSubview(contentStack)

        let topConstraint = contentStack.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 12)
        let bottomConstraint = contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        let collapsedConstraint = headerRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        contentTopConstraint = topConstraint
        contentBottomConstraint = bottomConstraint
        collapsedBottomConstraint = collapsedConstraint

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            headerRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            headerRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            topConstraint,
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            bottomConstraint,
        ])

        updateExpandedState(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleExpanded() {
        expanded.toggle()
        updateExpandedState(animated: true)
    }

    private func updateHeader() {
        toggleButton.setTitle("\(titleText) \(expanded ? "▴" : "▾")", for: .normal)
    }

    private func updateExpandedState(animated: Bool) {
        contentStack.isHidden = !expanded
        contentTopConstraint?.isActive = expanded
        contentBottomConstraint?.isActive = expanded
        collapsedBottomConstraint?.isActive = !expanded
        updateHeader()

        guard animated else { return }
        UIView.animate(withDuration: 0.2) {
            self.superview?.layoutIfNeeded()
        }
    }
}

private final class OcrDetailPaddingLabel: UILabel {
    var insets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
