import UIKit

final class OcrHistoryListViewController: UIViewController {
    private let dateFormatter: DateFormatter
    private let remoteService: HealthRemoteServing
    private let reportLoader: OcrHistoryLoading
    private var displayedReports: [OcrReport] = []
    private var refreshTask: Task<Void, Never>?
    private lazy var manageButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: t(.ocrManageHistory), style: .plain, target: self, action: #selector(manageTapped))
        item.accessibilityLabel = t(.ocrManageHistory)
        return item
    }()

    private lazy var refreshButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: t(.symptomChatRefreshHistory), style: .plain, target: self, action: #selector(refreshTapped))
        item.accessibilityLabel = t(.symptomChatRefreshHistory)
        return item
    }()

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    init(
        dateFormatter: DateFormatter,
        remoteService: HealthRemoteServing = LiveHealthRemoteService(),
        reportLoader: OcrHistoryLoading? = nil
    ) {
        self.dateFormatter = dateFormatter
        self.remoteService = remoteService
        self.reportLoader = reportLoader ?? OcrHistoryLoader(remoteFetcher: remoteService)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ocrPageBackgroundColor()
        title = t(.healthProfileOcrHistory)
        configureBackButtonIfNeeded()
        enableInteractiveBackSwipeIfNeeded()
        navigationItem.rightBarButtonItems = [refreshButtonItem, manageButtonItem]

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(refreshTapped), name: .ocrReportsDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(authTokenChanged), name: .authTokenDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
        loadReports()
    }

    deinit {
        refreshTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    private func configureBackButtonIfNeeded() {
        guard navigationController?.viewControllers.first !== self else { return }
        let item = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
        item.accessibilityLabel = t(.back)
        navigationItem.leftBarButtonItem = item
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    private func enableInteractiveBackSwipeIfNeeded() {
        guard navigationController?.viewControllers.first !== self else { return }
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }

    @objc private func authTokenChanged() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.authTokenChanged()
            }
            return
        }
        loadReports()
    }

    @objc private func languageChanged() {
        title = t(.healthProfileOcrHistory)
        refreshButtonItem.title = t(.symptomChatRefreshHistory)
        refreshButtonItem.accessibilityLabel = t(.symptomChatRefreshHistory)
        manageButtonItem.title = t(.ocrManageHistory)
        manageButtonItem.accessibilityLabel = t(.ocrManageHistory)
        loadReports()
    }

    @objc private func refreshTapped() {
        loadReports()
    }

    @objc private func manageTapped() {
        let deviceReports = displayedDeviceReports()
        let cloudReports = displayedCloudReports()
        guard !deviceReports.isEmpty || !cloudReports.isEmpty else {
            let alert = UIAlertController(title: nil, message: t(.ocrHistoryNothingToClear), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
            present(alert, animated: true)
            return
        }

        let sheet = UIAlertController(title: t(.ocrManageHistory), message: nil, preferredStyle: .actionSheet)
        if !deviceReports.isEmpty {
            sheet.addAction(UIAlertAction(title: t(.ocrClearDeviceHistory), style: .destructive) { [weak self] _ in
                self?.clearDeviceReports(deviceReports)
            })
        }
        if !cloudReports.isEmpty {
            sheet.addAction(UIAlertAction(title: t(.ocrClearCloudHistory), style: .destructive) { [weak self] _ in
                self?.clearCloudReports(cloudReports)
            })
        }
        sheet.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.barButtonItem = manageButtonItem
        }
        present(sheet, animated: true)
    }

    private func loadReports() {
        refreshTask?.cancel()
        refreshButtonItem.isEnabled = false
        render(reports: OcrReportRepository.shared.fetchAll(), scopeText: currentScopeText())

        guard Config.useRelay, AuthTokenManager.shared.isLoggedIn else {
            refreshButtonItem.isEnabled = true
            return
        }

        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                let reports = try await reportLoader.refresh(limit: 20)
                await MainActor.run {
                    self.render(reports: reports, scopeText: self.currentScopeText())
                    self.refreshButtonItem.isEnabled = true
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    self.render(reports: OcrReportRepository.shared.fetchAll(), scopeText: self.currentScopeText())
                    self.refreshButtonItem.isEnabled = true
                }
            }
        }
    }

    private func currentScopeText() -> String? {
        if Config.useRelay, AuthTokenManager.shared.isLoggedIn {
            return t(.healthProfileCloudConnected)
        }
        if AuthManager.shared.isLoggedIn {
            return t(.healthProfilePhoneLocalMode)
        }
        return t(.healthProfileLocalOnly)
    }

    private func render(reports: [OcrReport], scopeText: String?) {
        displayedReports = reports
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        stackView.addArrangedSubview(makeOverviewCard(reports: reports, scopeText: scopeText))

        if reports.isEmpty {
            manageButtonItem.isEnabled = false
            stackView.addArrangedSubview(makeEmptyStateCard())
            return
        }

        for report in reports {
            stackView.addArrangedSubview(makeReportCard(report))
        }

        manageButtonItem.isEnabled = !displayedDeviceReports().isEmpty || !displayedCloudReports().isEmpty
    }

    private func displayedDeviceReports() -> [OcrReport] {
        displayedReports.filter { $0.source == .device }
    }

    private func displayedCloudReports() -> [OcrReport] {
        displayedReports.filter { $0.source == .cloud }
    }

    private func makeReportCard(_ report: OcrReport) -> UIView {
        let card = UIView()
        card.backgroundColor = ocrCardSurfaceColor()
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.12).cgColor
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 5)
        card.layer.shadowRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .clear
        button.accessibilityIdentifier = report.id
        button.addTarget(self, action: #selector(reportTapped(_:)), for: .touchUpInside)

        let title = UILabel()
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .label
        title.text = reportListDateText(for: report.date)
        title.translatesAutoresizingMaskIntoConstraints = false

        let metricsBadge = makeBadge(
            text: metricsSummary(for: report),
            tint: report.items.contains(where: \.isAbnormal) ? .systemOrange : .secondaryLabel
        )
        metricsBadge.translatesAutoresizingMaskIntoConstraints = false

        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle(t(.ocrDeleteReport), for: .normal)
        deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        deleteButton.accessibilityIdentifier = report.id
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.addTarget(self, action: #selector(deleteReportTapped(_:)), for: .touchUpInside)

        let summaryLabel = UILabel()
        summaryLabel.font = .systemFont(ofSize: 13)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 3
        summaryLabel.text = reportSummary(for: report)
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = UIStackView(arrangedSubviews: [title, UIView(), deleteButton])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 8
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        let metaRow = UIStackView(arrangedSubviews: [metricsBadge])
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 8
        metaRow.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView(arrangedSubviews: [headerRow, metaRow, summaryLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(button)
        card.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            button.topAnchor.constraint(equalTo: card.topAnchor),
            button.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return card
    }

    private func makeOverviewCard(reports: [OcrReport], scopeText: String?) -> UIView {
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

        let icon = UIImageView(image: UIImage(systemName: "doc.text.image"))
        icon.tintColor = AppDesign.Color.primaryGreen
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.addSubview(icon)

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.text = t(.healthProfileOcrHistory)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let abnormalCount = reports.reduce(0) { partial, report in
            partial + report.items.filter(\.isAbnormal).count
        }
        let subtitleLabel = UILabel()
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        let summaryLine = reports.isEmpty
            ? t(.healthProfileEmptyReports)
            : (abnormalCount > 0
                ? String(format: t(.ocrReportMetricsAbnormalFormat), reports.reduce(0) { $0 + $1.items.count }, abnormalCount)
                : String(format: t(.ocrReportMetricsNormalFormat), reports.reduce(0) { $0 + $1.items.count }))
        subtitleLabel.text = [scopeText, summaryLine]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: "\n")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let badgeRow = UIStackView(arrangedSubviews: [
            makeBadge(text: "\(reports.count)", tint: .secondaryLabel),
            makeBadge(text: abnormalCount > 0 ? String(format: t(.ocrReportAbnormalCountFormat), abnormalCount) : t(.ocrReportAllNormal), tint: abnormalCount > 0 ? .systemOrange : AppDesign.Color.primaryGreen)
        ])
        badgeRow.axis = .horizontal
        badgeRow.spacing = 8
        badgeRow.alignment = .center
        badgeRow.translatesAutoresizingMaskIntoConstraints = false

        let actionRow = UIStackView(arrangedSubviews: [
            makeActionButton(title: t(.symptomChatRefreshHistory), iconName: "arrow.clockwise", selector: #selector(refreshTapped)),
            makeActionButton(title: t(.ocrManageHistory), iconName: "slider.horizontal.3", selector: #selector(manageTapped))
        ])
        actionRow.axis = .horizontal
        actionRow.spacing = 8
        actionRow.distribution = .fillEqually
        actionRow.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconWrap)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(badgeRow)
        card.addSubview(actionRow)

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

            actionRow.topAnchor.constraint(equalTo: badgeRow.bottomAnchor, constant: 12),
            actionRow.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            actionRow.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            actionRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func makeEmptyStateCard() -> UIView {
        let card = UIView()
        card.backgroundColor = ocrCardSurfaceColor()
        card.layer.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = t(.healthProfileEmptyReports)
        label.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeBadge(text: String, tint: UIColor) -> UIView {
        let label = HealthPagePaddingLabel()
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = tint
        label.backgroundColor = tint.withAlphaComponent(0.10)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.insets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        return label
    }

    private func makeActionButton(title: String, iconName: String, selector: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: iconName), for: .normal)
        button.backgroundColor = ocrSecondarySurfaceColor()
        button.layer.cornerRadius = 12
        button.tintColor = AppDesign.Color.primaryGreen
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        button.semanticContentAttribute = directionalSemanticContentAttribute(for: .leading)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }

    private func metricsSummary(for report: OcrReport) -> String {
        let abnormalCount = report.items.filter(\.isAbnormal).count
        if abnormalCount > 0 {
            return String(format: t(.ocrReportAbnormalCountFormat), abnormalCount)
        }
        return t(.ocrReportAllNormal)
    }

    private func reportSummary(for report: OcrReport) -> String {
        let prioritized = report.items.sorted { lhs, rhs in
            if lhs.isAbnormal == rhs.isAbnormal { return lhs.name < rhs.name }
            return lhs.isAbnormal && !rhs.isAbnormal
        }
        let previewItems = prioritized.prefix(2).map { item in
            item.reference.isEmpty ? "\(item.name): \(item.value)" : "\(item.name): \(item.value) · \(item.reference)"
        }
        guard !previewItems.isEmpty else {
            return metricsSummary(for: report)
        }
        let formatter = ListFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        return formatter.string(from: Array(previewItems)) ?? previewItems.joined(separator: " · ")
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
            return UIColor.secondarySystemBackground.withAlphaComponent(0.85)
        }
    }

    private func reportListDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    @objc private func reportTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        if let report = displayedReports.first(where: { $0.id == id }) {
            let vc = OcrReportDetailViewController(report: report, dateFormatter: dateFormatter) { [weak self] report in
                self?.deleteReport(report, popAfterDelete: true)
            }
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc private func deleteReportTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        guard let report = displayedReports.first(where: { $0.id == id }) else { return }

        let alert = UIAlertController(title: t(.ocrDeleteReport), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        alert.addAction(UIAlertAction(title: t(.ocrDeleteReport), style: .destructive) { [weak self] _ in
            self?.deleteReport(report)
        })
        present(alert, animated: true)
    }

    private func deleteReport(_ report: OcrReport, popAfterDelete: Bool = false) {
        if report.source == .cloud, Config.useRelay, AuthTokenManager.shared.isLoggedIn {
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.remoteService.deleteOcrReport(id: report.id)
                    OcrReportRepository.shared.remove(id: report.id)
                    await MainActor.run {
                        if popAfterDelete {
                            self.navigationController?.popViewController(animated: true)
                        }
                        self.loadReports()
                    }
                } catch {
                    await MainActor.run {
                        let alert = UIAlertController(title: nil, message: t(.ocrDeleteFailed), preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        } else {
            OcrReportRepository.shared.remove(id: report.id)
            if popAfterDelete {
                navigationController?.popViewController(animated: true)
            }
            loadReports()
        }
    }

    private func clearDeviceReports(_ reports: [OcrReport]) {
        let uniqueReports = Dictionary(grouping: reports, by: \.id).compactMap { $0.value.first }
        uniqueReports.forEach { OcrReportRepository.shared.remove(id: $0.id) }
        loadReports()
    }

    private func clearCloudReports(_ reports: [OcrReport]) {
        guard !reports.isEmpty else { return }
        refreshButtonItem.isEnabled = false
        manageButtonItem.isEnabled = false

        Task { [weak self] in
            guard let self else { return }
            var failed = false
            var deletedIDs = Set<String>()
            for report in reports {
                do {
                    try await self.remoteService.deleteOcrReport(id: report.id)
                    deletedIDs.insert(report.id)
                } catch {
                    failed = true
                }
            }
            await MainActor.run {
                self.displayedReports.removeAll { deletedIDs.contains($0.id) }
                self.loadReports()
                if failed {
                    let alert = UIAlertController(title: nil, message: t(.ocrHistoryBulkDeleteFailed), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}
