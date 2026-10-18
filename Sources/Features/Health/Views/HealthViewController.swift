import UIKit
import Combine

// MARK: - HealthViewController

final class HealthViewController: UIViewController {

    let themeColor = AppDesign.Color.primaryGreen
    let remoteService: HealthRemoteServing
    var vitalTitleLabels: [HealthMetricType: UILabel] = [:]
    var vitalUnitLabels: [HealthMetricType: UILabel] = [:]
    var selectedHistoryMetric: HealthMetricType = .heartRate
    private var cancellables = Set<AnyCancellable>()
    var isSyncActionInFlight = false

    enum HealthMetricType: Int, CaseIterable {
        case heartRate
        case spo2
        case respiratoryRate
        case stress
    }

    // MARK: - ScrollView

    let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Header

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Latest Vitals

    let hrValueLabel = HealthViewController.makeBigValueLabel()
    let spo2ValueLabel = HealthViewController.makeBigValueLabel()
    let rrValueLabel = HealthViewController.makeBigValueLabel()
    let stressValueLabel = HealthViewController.makeBigValueLabel()

    let vitalsCardTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    lazy var newCheckButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: - Basic Info

    let basicInfoTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    lazy var editProfileButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        btn.setTitleColor(themeColor, for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    let nameValueLabel = HealthViewController.makeInfoValueLabel()
    let genderValueLabel = HealthViewController.makeInfoValueLabel()
    let birthdayValueLabel = HealthViewController.makeInfoValueLabel()
    let heightValueLabel = HealthViewController.makeInfoValueLabel()
    let weightValueLabel = HealthViewController.makeInfoValueLabel()
    let bloodTypeValueLabel = HealthViewController.makeInfoValueLabel()
    let familyProfilesStatusLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    let profileSwitcherScrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsHorizontalScrollIndicator = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    let profileSwitcherStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    let nameKeyLabel = HealthViewController.makeInfoKeyLabel()
    let genderKeyLabel = HealthViewController.makeInfoKeyLabel()
    let birthdayKeyLabel = HealthViewController.makeInfoKeyLabel()
    let heightKeyLabel = HealthViewController.makeInfoKeyLabel()
    let weightKeyLabel = HealthViewController.makeInfoKeyLabel()
    let bloodTypeKeyLabel = HealthViewController.makeInfoKeyLabel()

    // MARK: - History

    let checkHistoryTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    let checkHistoryTrendTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    lazy var checkHistoryMetricControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["", "", "", ""])
        control.selectedSegmentIndex = selectedHistoryMetric.rawValue
        control.selectedSegmentTintColor = themeColor.withAlphaComponent(0.18)
        control.backgroundColor = UIColor.systemGray6
        control.translatesAutoresizingMaskIntoConstraints = false
        control.addTarget(self, action: #selector(checkHistoryMetricChanged), for: .valueChanged)
        return control
    }()

    lazy var checkHistoryRangeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["", ""])
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = themeColor.withAlphaComponent(0.18)
        control.backgroundColor = UIColor.systemGray6
        control.translatesAutoresizingMaskIntoConstraints = false
        control.addTarget(self, action: #selector(checkHistoryRangeChanged), for: .valueChanged)
        return control
    }()

    let checkHistoryTrendView: TrendLineView = {
        let view = TrendLineView()
        view.lineColor = .systemRed
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let checkHistoryTrendStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    let checkHistoryStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - OCR Card

    let ocrTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    lazy var uploadReportButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        btn.setImage(UIImage(systemName: "plus.circle", withConfiguration: config), for: .normal)
        btn.tintColor = themeColor
        btn.setTitleColor(themeColor, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    lazy var ocrViewAllButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        btn.setTitleColor(.secondaryLabel, for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    let ocrHistoryStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    let ocrLoadingLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Sync

    lazy var syncNowButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        btn.setImage(UIImage(systemName: "arrow.triangle.2.circlepath", withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = themeColor
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        btn.layer.cornerRadius = 12
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(syncNowTapped), for: .touchUpInside)
        return btn
    }()

    let syncStatusLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Formatters

    let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    let birthdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    init(remoteService: HealthRemoteServing = LiveHealthRemoteService()) {
        self.remoteService = remoteService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.remoteService = LiveHealthRemoteService()
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = AppDesign.Surface.canvasBackground
        setupScrollView()
        setupHeaderSection()
        setupVitalsCard()
        setupBasicInfoCard()
        setupCheckHistoryCard()
        setupWomenHealthCard()
        setupOcrCard()
        setupSyncCard()
        addBottomSpacer()
        updateTexts()
        refreshAll()
        bindSyncEvents()
        bindProfileEvents()
        NotificationCenter.default.addObserver(self, selector: #selector(profileDidUpdate), name: .userProfileDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(recordsDidUpdate), name: .healthRecordsDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ocrReportsDidUpdate), name: .ocrReportsDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(authTokenChanged), name: .authTokenDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(activeProfileDidChange), name: .activeHealthProfileDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshAll()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    deinit {
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    private func bindSyncEvents() {
        SyncEngine.shared.syncCompleted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.syncNowButton.isEnabled = true
                self.refreshSyncStatus()
            }
            .store(in: &cancellables)

        SyncEngine.shared.syncError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncNowButton.isEnabled = true
                self?.refreshSyncStatus()
            }
            .store(in: &cancellables)

        SyncEngine.shared.syncStatusChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.refreshSyncStatus()
            }
            .store(in: &cancellables)

        HealthMetricStore.shared.syncStatusChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshSyncStatus()
            }
            .store(in: &cancellables)

        HealthMetricStore.shared.readingSaved
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshSyncStatus()
            }
            .store(in: &cancellables)
    }

    private func bindProfileEvents() {
        ProfileManager.shared.profilesChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.refreshAll()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc func newCheckTapped() {
        let vc = HealthCheckViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func authTokenChanged() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.authTokenChanged()
            }
            return
        }
        refreshOcrHistory()
        refreshSyncStatus()
    }

    @objc func editProfileTapped() {
        let vc = HealthProfileEditViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func profileSwitchTapped(_ sender: UIButton) {
        guard let profileID = sender.accessibilityIdentifier else { return }
        _ = try? ProfileManager.shared.setActiveProfile(id: profileID)
        refreshAll()
    }

    @objc func familyProfilesTapped() {
        let vc = FamilyProfilesViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func uploadReportTapped() {
        guard ensureRelayFeatureAuthorization(onReady: { [weak self] in
            self?.uploadReportTapped()
        }) else {
            return
        }

        let alert = UIAlertController(title: t(.healthProfileUploadReport), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: t(.symptomChatAttachImage), style: .default) { [weak self] _ in
            self?.presentImagePicker(sourceType: .photoLibrary)
        })
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: t(.symptomChatAttachCamera), style: .default) { [weak self] _ in
                self?.presentImagePicker(sourceType: .camera)
            })
        }
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        present(alert, animated: true)
    }

    @objc func viewAllOcrTapped() {
        let vc = OcrHistoryListViewController(dateFormatter: dateFormatter, remoteService: remoteService)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func syncNowTapped() {
        guard !isSyncActionInFlight else { return }
        guard ensureRelayFeatureAuthorization(onReady: { [weak self] in
            self?.syncNowTapped()
        }) else {
            return
        }

        let summary = SyncEngine.shared.statusSummary()
        if summary.isSyncing || summary.uploadingCount > 0 {
            return
        }
        if let blockedReason = summary.blockedReason, summary.unsyncedCount > 0 {
            let message: String
            switch blockedReason {
            case .requiresLogin:
                let base = AuthManager.shared.isLoggedIn ? t(.syncStatusRequiresEmailLogin) : t(.syncStatusRequiresLogin)
                message = String(format: t(.syncStatusCountFormat), base, summary.unsyncedCount)
            case .networkUnavailable:
                message = String(format: t(.syncStatusCountFormat), t(.syncStatusWaitingForNetwork), summary.unsyncedCount)
            case .waitingForWiFi:
                message = String(format: t(.syncStatusCountFormat), t(.syncStatusWaitingForWiFi), summary.unsyncedCount)
            }
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
            present(alert, animated: true)
            return
        }
        guard summary.unsyncedCount > 0 else {
            guard Config.useRelay, AuthTokenManager.shared.isLoggedIn else {
                let alert = UIAlertController(title: nil, message: t(.syncStatusIdle), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                present(alert, animated: true)
                return
            }

            isSyncActionInFlight = true
            syncNowButton.isEnabled = false
            syncStatusLabel.text = t(.syncStatusSyncing)
            Task { [weak self] in
                guard let self else { return }
                defer {
                    Task { @MainActor [weak self] in
                        self?.isSyncActionInFlight = false
                        self?.syncNowButton.isEnabled = true
                    }
                }
                do {
                    async let mergeProfiles: Void = ProfileManager.shared.mergeProfilesFromCloud()
                    async let cloudResponse: CloudReadingsResponse = remoteService.fetchCloudReadings(limit: 200)
                    let (_, response) = try await (mergeProfiles, cloudResponse)
                    let imported = response.readings.compactMap { $0.toRawReading() }
                    if !imported.isEmpty {
                        try? HealthMetricStore.shared.save(readings: imported)
                    }
                    await MainActor.run {
                        SyncEngine.shared.recordManualRefresh()
                        self.refreshBasicInfo()
                        self.refreshOcrHistory()
                        self.refreshSyncStatus()
                    }
                } catch {
                    await MainActor.run {
                        self.syncNowButton.isEnabled = true
                        self.refreshSyncStatus()
                        let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
            return
        }

        isSyncActionInFlight = true
        syncNowButton.isEnabled = false
        syncStatusLabel.text = t(.syncStatusSyncing)
        SyncEngine.shared.syncNow { [weak self] result in
            guard let self else { return }
            self.isSyncActionInFlight = false

            guard let result else {
                self.refreshSyncStatus()
                return
            }

            if result.blockedReason == nil, (result.uploaded > 0 || result.failed > 0) {
                UIAccessibility.post(notification: .announcement, argument: result.failed > 0 && result.uploaded > 0 ? t(.syncStatusPartial) : (result.failed > 0 ? t(.syncStatusFailed) : t(.syncStatusDone)))
            }
            self.refreshSyncStatus()
        }
    }

    @objc func ocrRowTapped(_ sender: OcrRowView) {
        let vc = OcrReportDetailViewController(report: sender.report, dateFormatter: dateFormatter) { [weak self] report in
            self?.deleteOcrReport(report)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func checkHistoryRangeChanged() {
        updateCheckHistoryTrend(records: HealthRecordRepository.shared.fetchAll(profileId: currentHealthProfileID()))
    }

    @objc func checkHistoryMetricChanged() {
        selectedHistoryMetric = HealthMetricType(rawValue: checkHistoryMetricControl.selectedSegmentIndex) ?? .heartRate
        checkHistoryTrendTitleLabel.text = historyMetricTitle(selectedHistoryMetric)
        refreshCheckHistory()
    }

    private func deleteOcrReport(_ report: OcrReport) {
        if report.source == .cloud, Config.useRelay, AuthTokenManager.shared.isLoggedIn {
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.remoteService.deleteOcrReport(id: report.id)
                    OcrReportRepository.shared.remove(id: report.id)
                    await MainActor.run {
                        self.navigationController?.popViewController(animated: true)
                        self.refreshOcrHistory()
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
            navigationController?.popViewController(animated: true)
            refreshOcrHistory()
        }
    }
}

// MARK: - UIImagePickerControllerDelegate

extension HealthViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        runMockOCR(image: image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

final class HealthPagePaddingLabel: UILabel {
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

/// Android parity, adult-only and local-first. This is intentionally not a clinical measurement.
final class WomenHealthViewController: UIViewController {
    private let lastPeriodKey = "vvewell.womenHealth.lastPeriod"
    private let modeKey = "vvewell.womenHealth.mode"
    private let stack = UIStackView()
    private let scroll = UIScrollView()
    private var mode = 0
    private var lastPeriod = Date().addingTimeInterval(-12 * 24 * 60 * 60)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "女性健康"
        view.backgroundColor = AppDesign.Surface.canvasBackground
        mode = UserDefaults.standard.integer(forKey: modeKey)
        if let date = UserDefaults.standard.object(forKey: lastPeriodKey) as? Date { lastPeriod = date }
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll); scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16), stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16), stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16), stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -28), stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32)
        ])
        rebuild()
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(card(text: "仅面向成年用户 · 本地保存 · 阶段仅由记录估算，不用于激素检测或诊断", color: .systemOrange))
        let title = UILabel(); title.text = "女性健康"; title.font = .systemFont(ofSize: 27, weight: .bold)
        stack.addArrangedSubview(title)
        let selector = UISegmentedControl(items: ["周期", "备孕", "孕期"].map(zhEn)); selector.selectedSegmentIndex = mode; selector.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        stack.addArrangedSubview(selector)
        let day = Calendar.current.dateComponents([.day], from: lastPeriod, to: Date()).day! + 1
        let phase = day <= 5 ? "月经期" : day <= 13 ? "卵泡期" : day <= 15 ? "排卵期" : "黄体期"
        stack.addArrangedSubview(card(text: "当前：\(phase) · 第 \(day) 天\n教育性趋势示意，不代表任何化验数值或设备测量。", color: AppDesign.Color.primaryGreen))
        switch mode {
        case 1: stack.addArrangedSubview(card(text: "备孕支持\n可能受孕窗口：第 11-16 天（当前第 \(day) 天）。仅根据周期记录估计，不能用于避孕、保证受孕或判断排卵。", color: .systemTeal))
        case 2: stack.addArrangedSubview(card(text: "孕期管理\n按末次月经估计：\(day / 7 + 1) 周。请记录产检与感受；如有异常或担忧，请及时联系医疗专业人员。", color: .systemPink))
        default:
            let formatter = DateFormatter(); formatter.dateStyle = .medium
            stack.addArrangedSubview(card(text: "经期记录\n上次开始：\(formatter.string(from: lastPeriod))\n预测下次：\(formatter.string(from: Calendar.current.date(byAdding: .day, value: 28, to: lastPeriod)!))", color: .systemIndigo))
            let button = UIButton(type: .system); button.setTitle("记录经期开始", for: .normal); button.setImage(UIImage(systemName: "plus.circle"), for: .normal); button.tintColor = .white; button.backgroundColor = AppDesign.Color.primaryGreen; button.layer.cornerRadius = 8; button.heightAnchor.constraint(equalToConstant: 44).isActive = true; button.addTarget(self, action: #selector(recordPeriod), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
    }

    @objc private func modeChanged(_ sender: UISegmentedControl) { mode = sender.selectedSegmentIndex; UserDefaults.standard.set(mode, forKey: modeKey); rebuild() }
    @objc private func recordPeriod() {
        let picker = UIDatePicker(); picker.datePickerMode = .date; picker.date = lastPeriod
        let alert = UIAlertController(title: "记录经期开始", message: "\n\n\n\n\n\n", preferredStyle: .alert)
        picker.translatesAutoresizingMaskIntoConstraints = false; alert.view.addSubview(picker)
        NSLayoutConstraint.activate([picker.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor), picker.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor, constant: 20)])
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in self?.lastPeriod = picker.date; UserDefaults.standard.set(picker.date, forKey: self?.lastPeriodKey ?? ""); self?.rebuild() })
        present(alert, animated: true)
    }
    private func card(text: String, color: UIColor) -> UIView { let label = UILabel(); label.text = text; label.numberOfLines = 0; label.font = .systemFont(ofSize: 14); label.textColor = color == AppDesign.Color.primaryGreen ? .white : .label; let view = UIView(); view.backgroundColor = color == AppDesign.Color.primaryGreen ? color : color.withAlphaComponent(0.13); view.layer.cornerRadius = 8; label.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(label); NSLayoutConstraint.activate([label.topAnchor.constraint(equalTo: view.topAnchor, constant: 14), label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14), label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14), label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14)]); return view }
}
