import UIKit
import Combine

// MARK: - 扫描状态机
enum ScanState {
    case idle
    case recording
    case uploading
    case queued(Int)
    case analyzing
    case completed
    case failed(String)
}

class HealthCheckViewController: UIViewController {

    private let themeColor = AppDesign.Color.primaryGreen
    private let cardGreenColor = AppDesign.Color.darkTeal
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 状态
    private var scanState: ScanState = .idle {
        didSet { updateUIForState() }
    }
    private var scanTask: Task<Void, Never>?
    private var latestLiveSnapshot: RPPGLiveSnapshot?

    // MARK: - 相机
    private let cameraManager = CameraManager()
    private let rppgService = RPPGInferenceService()
    private var cameraContainerView: UIView?
    private var faceGuideOverlay: FaceGuideOverlayView?

    // MARK: - ScrollView

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Hero Section

    private let heroContainerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let heroGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            AppDesign.Color.gradientTop.cgColor,
            AppDesign.Color.gradientBottom.cgColor
        ]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        return layer
    }()

    private let cameraIconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        view.layer.cornerRadius = 35
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let heroTitleLabel: UILabel = {
        let label = UILabel()
        label.text = nil
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let heroSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = nil
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Capability Tags

    private let tagsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Tips

    private let tipsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Start Button

    private lazy var startScanButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = themeColor
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let playIcon = UIImage(systemName: "play.fill", withConfiguration: config)
        button.setImage(playIcon, for: .normal)
        button.setTitle(nil, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.tintColor = .white
        return button
    }()

    // MARK: - My Devices Section

    private let devicesHeaderIcon = UIImageView()
    private let devicesSectionLabel: UILabel = {
        let label = UILabel()
        label.text = t(.profileMyDevices)
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let devicesStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - 状态指示器

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Recent Checks

    private let recentChecksLabel: UILabel = {
        let label = UILabel()
        label.text = nil
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var viewAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let checksStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Health Tips Card

    private let healthTipsCard: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - 日期格式化

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        navigationController?.navigationBar.prefersLargeTitles = false
        setupScrollView()
        setupHeroSection()
        setupCapabilityTags()
        setupTips()
        setupStartButton()
        setupConnectedDevices()
        setupStatusViews()
        setupRecentChecks()
        setupHealthTips()
        observeDeviceState()
        updateTexts()
        startScanButton.addTarget(self, action: #selector(startScanTapped), for: .touchUpInside)
        NotificationCenter.default.addObserver(self, selector: #selector(recordsDidUpdate), name: .healthRecordsDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)

        // 低亮度警告回调
        cameraManager.onLowLightWarning = { [weak self] isLow in
            self?.faceGuideOverlay?.showLowLightWarning(isLow)
        }
        rppgService.onSnapshot = { [weak self] snapshot in
            self?.handleLiveSnapshot(snapshot)
        }

        #if DEBUG
        // 长按 Start 按钮进入相册选片模式
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(debugLongPress(_:)))
        longPress.minimumPressDuration = 1.0
        startScanButton.addGestureRecognizer(longPress)
        #endif
    }

    // MARK: - 多语言刷新

    private func updateTexts() {
        title = t(.healthCheckTitle)
        heroTitleLabel.text = t(.healthCheckTitle)
        heroSubtitleLabel.text = t(.healthCheckSubtitle)
        startScanButton.setTitle("  \(t(.healthCheckStart))", for: .normal)
        devicesSectionLabel.text = t(.profileMyDevices)
        recentChecksLabel.text = t(.healthCheckRecentChecks)
        configureTrailingChevronButton(
            viewAllButton,
            title: t(.healthCheckViewAll),
            color: themeColor,
            font: .systemFont(ofSize: 14, weight: .medium)
        )
        updateDateFormatterLocale()
        updateTips()
        updateHealthTipsCard()
        updateUIForState()
    }

    @objc private func languageChanged() {
        updateTexts()
        refreshRecentChecks()
        refreshDeviceList()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        scanTask?.cancel()
        cameraManager.onVideoFrame = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        heroGradientLayer.frame = heroContainerView.bounds
        if let container = cameraContainerView {
            cameraManager.previewLayer.frame = container.bounds
        }
    }

    // MARK: - Setup ScrollView

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Hero Section

    private func setupHeroSection() {
        contentView.addSubview(heroContainerView)
        heroContainerView.layer.insertSublayer(heroGradientLayer, at: 0)

        // Camera icon
        let cameraConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        let cameraIV = UIImageView(image: UIImage(systemName: "camera.fill", withConfiguration: cameraConfig))
        cameraIV.tintColor = .white
        cameraIV.translatesAutoresizingMaskIntoConstraints = false
        cameraIconContainer.addSubview(cameraIV)

        heroContainerView.addSubview(cameraIconContainer)
        heroContainerView.addSubview(heroTitleLabel)
        heroContainerView.addSubview(heroSubtitleLabel)

        NSLayoutConstraint.activate([
            heroContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            heroContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            heroContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            cameraIconContainer.topAnchor.constraint(equalTo: heroContainerView.topAnchor, constant: 24),
            cameraIconContainer.centerXAnchor.constraint(equalTo: heroContainerView.centerXAnchor),
            cameraIconContainer.widthAnchor.constraint(equalToConstant: 70),
            cameraIconContainer.heightAnchor.constraint(equalToConstant: 70),

            cameraIV.centerXAnchor.constraint(equalTo: cameraIconContainer.centerXAnchor),
            cameraIV.centerYAnchor.constraint(equalTo: cameraIconContainer.centerYAnchor),

            heroTitleLabel.topAnchor.constraint(equalTo: cameraIconContainer.bottomAnchor, constant: 16),
            heroTitleLabel.centerXAnchor.constraint(equalTo: heroContainerView.centerXAnchor),

            heroSubtitleLabel.topAnchor.constraint(equalTo: heroTitleLabel.bottomAnchor, constant: 8),
            heroSubtitleLabel.centerXAnchor.constraint(equalTo: heroContainerView.centerXAnchor),
            heroSubtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: heroContainerView.leadingAnchor, constant: 20),
            heroSubtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: heroContainerView.trailingAnchor, constant: -20),
            heroSubtitleLabel.bottomAnchor.constraint(equalTo: heroContainerView.bottomAnchor, constant: -24),
        ])
    }

    // MARK: - Capability Tags

    private func setupCapabilityTags() {
        contentView.addSubview(tagsContainer)

        let tags: [(icon: String, title: String)] = [
            ("heart", t(.healthCheckCapHR)),
            ("wind", t(.healthCheckCapRR)),
            ("waveform.path.ecg", t(.healthCheckCapSpO2)),
            ("bolt.heart", t(.healthCheckCapBP)),
        ]

        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.spacing = 12
        topRow.distribution = .fillEqually
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let bottomRow = UIStackView()
        bottomRow.axis = .horizontal
        bottomRow.spacing = 12
        bottomRow.distribution = .fillEqually
        bottomRow.translatesAutoresizingMaskIntoConstraints = false

        for (index, tag) in tags.enumerated() {
            let tagView = makeCapabilityTag(icon: tag.icon, title: tag.title)
            if index < 2 {
                topRow.addArrangedSubview(tagView)
            } else {
                bottomRow.addArrangedSubview(tagView)
            }
        }

        tagsContainer.addSubview(topRow)
        tagsContainer.addSubview(bottomRow)

        NSLayoutConstraint.activate([
            tagsContainer.topAnchor.constraint(equalTo: heroContainerView.bottomAnchor, constant: 16),
            tagsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tagsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            topRow.topAnchor.constraint(equalTo: tagsContainer.topAnchor),
            topRow.leadingAnchor.constraint(equalTo: tagsContainer.leadingAnchor),
            topRow.trailingAnchor.constraint(equalTo: tagsContainer.trailingAnchor),
            topRow.heightAnchor.constraint(equalToConstant: 40),

            bottomRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 10),
            bottomRow.leadingAnchor.constraint(equalTo: tagsContainer.leadingAnchor),
            bottomRow.trailingAnchor.constraint(equalTo: tagsContainer.trailingAnchor),
            bottomRow.heightAnchor.constraint(equalToConstant: 40),
            bottomRow.bottomAnchor.constraint(equalTo: tagsContainer.bottomAnchor),
        ])
    }

    // MARK: - Tips

    private func setupTips() {
        contentView.addSubview(tipsStackView)

        for tip in currentTips() {
            let tipView = makeTipRow(text: tip)
            tipsStackView.addArrangedSubview(tipView)
        }

        NSLayoutConstraint.activate([
            tipsStackView.topAnchor.constraint(equalTo: tagsContainer.bottomAnchor, constant: 20),
            tipsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            tipsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
        ])
    }

    // MARK: - Start Button

    private func setupStartButton() {
        contentView.addSubview(startScanButton)

        NSLayoutConstraint.activate([
            startScanButton.topAnchor.constraint(equalTo: tipsStackView.bottomAnchor, constant: 24),
            startScanButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            startScanButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            startScanButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    // MARK: - Status Views

    private func setupStatusViews() {
        contentView.addSubview(statusLabel)
        contentView.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: devicesStackView.bottomAnchor, constant: 12),
            statusLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            activityIndicator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
    }

    // MARK: - Recent Checks

    private func setupRecentChecks() {
        let clockIcon = makeSmallIcon(systemName: "clock", color: .secondaryLabel)
        contentView.addSubview(clockIcon)
        contentView.addSubview(recentChecksLabel)
        contentView.addSubview(viewAllButton)
        contentView.addSubview(checksStackView)

        refreshRecentChecks()

        NSLayoutConstraint.activate([
            clockIcon.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 32),
            clockIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            recentChecksLabel.centerYAnchor.constraint(equalTo: clockIcon.centerYAnchor),
            recentChecksLabel.leadingAnchor.constraint(equalTo: clockIcon.trailingAnchor, constant: 8),

            viewAllButton.centerYAnchor.constraint(equalTo: clockIcon.centerYAnchor),
            viewAllButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            checksStackView.topAnchor.constraint(equalTo: recentChecksLabel.bottomAnchor, constant: 16),
            checksStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            checksStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }

    private func refreshRecentChecks() {
        checksStackView.arrangedSubviews.forEach {
            checksStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let activeProfileID = (try? ProfileManager.shared.resolveActiveProfileID()) ?? nil
        let records = HealthRecordRepository.shared.fetchAll(profileId: activeProfileID).prefix(3)
        if records.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = t(.healthCheckNoRecords)
            emptyLabel.font = .systemFont(ofSize: 14)
            emptyLabel.textColor = .secondaryLabel
            emptyLabel.textAlignment = .center
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            checksStackView.addArrangedSubview(emptyLabel)
        } else {
            for record in records {
                checksStackView.addArrangedSubview(makeHealthRecordCard(record: record))
            }
        }
    }


    // MARK: - Health Tips

    private func setupHealthTips() {
        contentView.addSubview(healthTipsCard)

        let iconContainer = UIView()
        iconContainer.backgroundColor = UIColor(red: 1.0, green: 0.85, blue: 0.35, alpha: 1.0)
        iconContainer.layer.cornerRadius = 20
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let bulbConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let bulbIV = UIImageView(image: UIImage(systemName: "lightbulb.fill", withConfiguration: bulbConfig))
        bulbIV.tintColor = .white
        bulbIV.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(bulbIV)

        let titleLabel = UILabel()
        titleLabel.text = t(.healthCheckTipsTitle)
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .natural
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = UILabel()
        descLabel.text = t(.healthCheckTipsDescription)
        descLabel.font = .systemFont(ofSize: 14)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 0
        descLabel.textAlignment = .natural
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.tag = 1001
        descLabel.tag = 1002

        healthTipsCard.addSubview(iconContainer)
        healthTipsCard.addSubview(titleLabel)
        healthTipsCard.addSubview(descLabel)

        NSLayoutConstraint.activate([
            healthTipsCard.topAnchor.constraint(equalTo: checksStackView.bottomAnchor, constant: 24),
            healthTipsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            healthTipsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            healthTipsCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),

            iconContainer.topAnchor.constraint(equalTo: healthTipsCard.topAnchor, constant: 20),
            iconContainer.leadingAnchor.constraint(equalTo: healthTipsCard.leadingAnchor, constant: 20),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),

            bulbIV.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            bulbIV.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: healthTipsCard.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: healthTipsCard.trailingAnchor, constant: -20),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            descLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            descLabel.trailingAnchor.constraint(equalTo: healthTipsCard.trailingAnchor, constant: -20),
            descLabel.bottomAnchor.constraint(equalTo: healthTipsCard.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - My Devices

    private func setupConnectedDevices() {
        let headerIcon = makeSmallIcon(systemName: "antenna.radiowaves.left.and.right", color: .secondaryLabel)
        contentView.addSubview(headerIcon)
        contentView.addSubview(devicesSectionLabel)
        contentView.addSubview(devicesStackView)

        NSLayoutConstraint.activate([
            headerIcon.topAnchor.constraint(equalTo: startScanButton.bottomAnchor, constant: 32),
            headerIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            devicesSectionLabel.centerYAnchor.constraint(equalTo: headerIcon.centerYAnchor),
            devicesSectionLabel.leadingAnchor.constraint(equalTo: headerIcon.trailingAnchor, constant: 8),

            devicesStackView.topAnchor.constraint(equalTo: devicesSectionLabel.bottomAnchor, constant: 16),
            devicesStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            devicesStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])

        refreshDeviceList()
    }

    private func observeDeviceState() {
        DeviceManager.shared.connectionStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshDeviceList()
            }
            .store(in: &cancellables)

        // Also refresh when device info arrives (e.g. device name)
        for type in DeviceManager.shared.registeredTypes {
            DeviceManager.shared.device(for: type)?.deviceInfo
                .compactMap { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.refreshDeviceList()
                }
                .store(in: &cancellables)
        }
    }

    private var deviceInfoCancellables = Set<AnyCancellable>()

    private func refreshDeviceList() {
        devicesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let pairedTypes = DeviceManager.shared.registeredTypes.filter { type in
            DeviceManager.shared.device(for: type)?.isPaired() ?? false
        }

        if pairedTypes.isEmpty {
            let card = makeNoDeviceCard()
            devicesStackView.addArrangedSubview(card)
            return
        }

        for type in pairedTypes {
            guard let device = DeviceManager.shared.device(for: type) else { continue }
            let connected = device.isConnected()

            // Read device name from latest device info
            var deviceName: String?
            device.deviceInfo
                .compactMap { $0 }
                .first()
                .sink { info in
                    if !info.name.isEmpty { deviceName = info.name }
                }
                .store(in: &deviceInfoCancellables)

            let displayName = deviceTypeName(for: type, deviceName: deviceName)

            switch type {
            case .ring:
                let card = makeRingDeviceCard(displayName: displayName, isConnected: connected)
                devicesStackView.addArrangedSubview(card)
            case .watch, .band, .robot, .radar, .thermalCamera:
                let card = makeGenericDeviceCard(type: type, displayName: displayName, isConnected: connected)
                devicesStackView.addArrangedSubview(card)
            }
        }
    }

    private func deviceTypeName(for type: DeviceType, deviceName: String?) -> String {
        let typeName: String
        switch type {
        case .ring: typeName = t(.myDevicesRing)
        case .watch: typeName = t(.myDevicesWatch)
        case .band: typeName = t(.myDevicesBand)
        case .robot: typeName = "vvewell Robot"
        case .radar: typeName = "JDY-23 雷达"
        case .thermalCamera: typeName = t(.myDevicesThermalCamera)
        }
        if let name = deviceName, !name.isEmpty {
            return "\(typeName) / \(name)"
        }
        return typeName
    }

    private func makeGenericDeviceCard(type: DeviceType, displayName: String, isConnected: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        card.layer.shadowOffset = AppDesign.Shadow.cardOffset
        card.layer.shadowRadius = AppDesign.Shadow.cardRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconContainer = UIView()
        iconContainer.backgroundColor = AppDesign.Color.gradientTop
        iconContainer.layer.cornerRadius = 22
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let iconName = type == .watch ? "applewatch" : "figure.walk"
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: iconName, withConfiguration: iconConfig))
        iconIV.tintColor = .white
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconIV)

        let nameLabel = UILabel()
        nameLabel.text = displayName
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Status pill
        let statusPill = UIView()
        statusPill.layer.cornerRadius = 10
        statusPill.translatesAutoresizingMaskIntoConstraints = false

        let statusDot = UIView()
        statusDot.layer.cornerRadius = 3
        statusDot.translatesAutoresizingMaskIntoConstraints = false

        let statusText = UILabel()
        statusText.font = .systemFont(ofSize: 12, weight: .medium)
        statusText.translatesAutoresizingMaskIntoConstraints = false

        if isConnected {
            statusPill.backgroundColor = themeColor.withAlphaComponent(0.1)
            statusDot.backgroundColor = themeColor
            statusText.text = t(.myDevicesConnected)
            statusText.textColor = themeColor
        } else {
            statusPill.backgroundColor = UIColor.tertiarySystemFill
            statusDot.backgroundColor = .tertiaryLabel
            statusText.text = t(.myDevicesDisconnected)
            statusText.textColor = .tertiaryLabel
        }

        statusPill.addSubview(statusDot)
        statusPill.addSubview(statusText)

        let comingSoon = UILabel()
        comingSoon.text = t(.healthCheckDevicesComingSoon)
        comingSoon.font = .systemFont(ofSize: 13)
        comingSoon.textColor = .tertiaryLabel
        comingSoon.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconContainer)
        card.addSubview(nameLabel)
        card.addSubview(statusPill)
        card.addSubview(comingSoon)

        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),

            iconIV.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: 2),
            nameLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),

            statusPill.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            statusPill.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            statusPill.heightAnchor.constraint(equalToConstant: 20),

            statusDot.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            statusDot.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 8),
            statusDot.widthAnchor.constraint(equalToConstant: 6),
            statusDot.heightAnchor.constraint(equalToConstant: 6),

            statusText.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            statusText.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 6),
            statusText.trailingAnchor.constraint(equalTo: statusPill.trailingAnchor, constant: -8),

            comingSoon.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 12),
            comingSoon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            comingSoon.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func makeRingDeviceCard(displayName: String, isConnected: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        card.layer.shadowOffset = AppDesign.Shadow.cardOffset
        card.layer.shadowRadius = AppDesign.Shadow.cardRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        // Device icon in colored container
        let iconContainer = UIView()
        iconContainer.backgroundColor = AppDesign.Color.gradientTop
        iconContainer.layer.cornerRadius = 22
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let ringIconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let ringIconIV = UIImageView(image: UIImage(systemName: "circle.circle", withConfiguration: ringIconConfig))
        ringIconIV.tintColor = .white
        ringIconIV.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(ringIconIV)

        let nameLabel = UILabel()
        nameLabel.text = displayName
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Status pill badge
        let statusPill = UIView()
        statusPill.layer.cornerRadius = 10
        statusPill.translatesAutoresizingMaskIntoConstraints = false

        let statusDot = UIView()
        statusDot.layer.cornerRadius = 3
        statusDot.translatesAutoresizingMaskIntoConstraints = false

        let statusText = UILabel()
        statusText.font = .systemFont(ofSize: 12, weight: .medium)
        statusText.translatesAutoresizingMaskIntoConstraints = false

        if isConnected {
            statusPill.backgroundColor = themeColor.withAlphaComponent(0.1)
            statusDot.backgroundColor = themeColor
            statusText.text = t(.myDevicesConnected)
            statusText.textColor = themeColor
        } else {
            statusPill.backgroundColor = UIColor.tertiarySystemFill
            statusDot.backgroundColor = .tertiaryLabel
            statusText.text = t(.myDevicesDisconnected)
            statusText.textColor = .tertiaryLabel
        }

        statusPill.addSubview(statusDot)
        statusPill.addSubview(statusText)

        // Chevron for navigation
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let chevronIV = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: chevronConfig))
        chevronIV.tintColor = .tertiaryLabel
        chevronIV.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconContainer)
        card.addSubview(nameLabel)
        card.addSubview(statusPill)
        card.addSubview(chevronIV)

        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),
            iconContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            ringIconIV.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            ringIconIV.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: 2),
            nameLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),

            statusPill.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            statusPill.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            statusPill.heightAnchor.constraint(equalToConstant: 20),

            statusDot.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            statusDot.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 8),
            statusDot.widthAnchor.constraint(equalToConstant: 6),
            statusDot.heightAnchor.constraint(equalToConstant: 6),

            statusText.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            statusText.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 6),
            statusText.trailingAnchor.constraint(equalTo: statusPill.trailingAnchor, constant: -8),

            chevronIV.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevronIV.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])

        // Tap to navigate to Ring Check page
        let tap = UITapGestureRecognizer(target: self, action: #selector(openRingCheck))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true

        return card
    }

    @objc private func openRingCheck() {
        let vc = RingCheckViewController()
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    private func makeNoDeviceCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        card.layer.shadowOffset = AppDesign.Shadow.cardOffset
        card.layer.shadowRadius = AppDesign.Shadow.cardRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconContainer = UIView()
        iconContainer.backgroundColor = UIColor.tertiarySystemFill
        iconContainer.layer.cornerRadius = 28
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: "antenna.radiowaves.left.and.right", withConfiguration: iconConfig))
        iconIV.tintColor = .tertiaryLabel
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconIV)

        let titleLabel = UILabel()
        titleLabel.text = t(.healthCheckNoDeviceConnected)
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = UILabel()
        descLabel.text = "Connect a health device to unlock\nmore measurement capabilities"
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .tertiaryLabel
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconContainer)
        card.addSubview(titleLabel)
        card.addSubview(descLabel)

        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            iconContainer.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 56),
            iconContainer.heightAnchor.constraint(equalToConstant: 56),

            iconIV.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            descLabel.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 20),
            descLabel.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -20),
            descLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])

        return card
    }

    // MARK: - Helpers

    private func makeCapabilityTag(icon: String, title: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.secondarySystemBackground
        container.layer.cornerRadius = 20
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconIV.tintColor = themeColor
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        label.textAlignment = .natural
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconIV)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            iconIV.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            iconIV.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            label.leadingAnchor.constraint(equalTo: iconIV.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -14),
        ])

        return container
    }

    private func makeTipRow(text: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let checkConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let checkIV = UIImageView(image: UIImage(systemName: "checkmark.circle", withConfiguration: checkConfig))
        checkIV.tintColor = .secondaryLabel
        checkIV.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .natural
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(checkIV)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            checkIV.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            checkIV.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            checkIV.widthAnchor.constraint(equalToConstant: 20),
            checkIV.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: checkIV.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            container.heightAnchor.constraint(equalToConstant: 24),
        ])

        return container
    }

    private func currentTips() -> [String] {
        [t(.healthCheckTipLighting), t(.healthCheckTipCentered), t(.healthCheckTipStill)]
    }

    private func updateTips() {
        let tips = currentTips()
        for (index, view) in tipsStackView.arrangedSubviews.enumerated() {
            guard index < tips.count,
                  let label = view.subviews.compactMap({ $0 as? UILabel }).first else { continue }
            label.text = tips[index]
        }
    }

    private func updateHealthTipsCard() {
        if let titleLabel = healthTipsCard.viewWithTag(1001) as? UILabel {
            titleLabel.text = t(.healthCheckTipsTitle)
        }
        if let descLabel = healthTipsCard.viewWithTag(1002) as? UILabel {
            descLabel.text = t(.healthCheckTipsDescription)
        }
    }

    private func updateDateFormatterLocale() {
        dateFormatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
    }

    private func makeSmallIcon(systemName: String, color: UIColor) -> UIImageView {
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iv = UIImageView(image: UIImage(systemName: systemName, withConfiguration: config))
        iv.tintColor = color
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: 22),
            iv.heightAnchor.constraint(equalToConstant: 22),
        ])
        return iv
    }

    private func makeHealthRecordCard(record: HealthRecord) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
        card.translatesAutoresizingMaskIntoConstraints = false

        // Date row
        let clockConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let clockIV = UIImageView(image: UIImage(systemName: "clock", withConfiguration: clockConfig))
        clockIV.tintColor = .tertiaryLabel
        clockIV.translatesAutoresizingMaskIntoConstraints = false

        let dateLabel = UILabel()
        dateLabel.text = dateFormatter.string(from: record.date)
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .secondaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        // Status badge
        let statusBadge = UILabel()
        statusBadge.text = record.hrStatus ?? "--"
        statusBadge.font = .systemFont(ofSize: 12, weight: .semibold)
        statusBadge.textColor = .white
        statusBadge.backgroundColor = themeColor
        statusBadge.textAlignment = .center
        statusBadge.layer.cornerRadius = 11
        statusBadge.clipsToBounds = true
        statusBadge.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(clockIV)
        card.addSubview(dateLabel)
        card.addSubview(statusBadge)

        // Metrics row
        let metricsStack = UIStackView()
        metricsStack.axis = .horizontal
        metricsStack.distribution = .fillEqually
        metricsStack.spacing = 8
        metricsStack.translatesAutoresizingMaskIntoConstraints = false

        let heartMetric = makeMetricItem(icon: "heart", value: record.hr.map { String(format: "%.0f", $0) } ?? "--", unit: "bpm")
        let spo2Metric = makeMetricItem(icon: "waveform.path.ecg", value: record.spo2.map { String(format: "%.0f", $0) } ?? "--", unit: "%")
        let respMetric = makeMetricItem(icon: "wind", value: record.rr.map { String(format: "%.0f", $0) } ?? "--", unit: "/min")
        let scoreMetric = makeMetricItem(icon: "bolt.heart", value: record.stressScore.map { String(format: "%.0f", $0) } ?? "--", unit: "score")

        metricsStack.addArrangedSubview(heartMetric)
        metricsStack.addArrangedSubview(spo2Metric)
        metricsStack.addArrangedSubview(respMetric)
        metricsStack.addArrangedSubview(scoreMetric)

        card.addSubview(metricsStack)

        // Separator
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(separator)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 110),

            clockIV.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            clockIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            dateLabel.centerYAnchor.constraint(equalTo: clockIV.centerYAnchor),
            dateLabel.leadingAnchor.constraint(equalTo: clockIV.trailingAnchor, constant: 6),

            statusBadge.centerYAnchor.constraint(equalTo: clockIV.centerYAnchor),
            statusBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            statusBadge.heightAnchor.constraint(equalToConstant: 22),

            separator.topAnchor.constraint(equalTo: clockIV.bottomAnchor, constant: 12),
            separator.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            metricsStack.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            metricsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            metricsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            metricsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        return card
    }

    private func makeMetricItem(icon: String, value: String, unit: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconIV.tintColor = themeColor
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let unitLabel = UILabel()
        unitLabel.text = unit
        unitLabel.font = .systemFont(ofSize: 11)
        unitLabel.textColor = .tertiaryLabel
        unitLabel.textAlignment = .center
        unitLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconIV)
        container.addSubview(valueLabel)
        container.addSubview(unitLabel)

        NSLayoutConstraint.activate([
            iconIV.topAnchor.constraint(equalTo: container.topAnchor),
            iconIV.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            valueLabel.topAnchor.constraint(equalTo: iconIV.bottomAnchor, constant: 4),
            valueLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            unitLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            unitLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            unitLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - 状态机 UI 更新

    private func updateUIForState() {
        switch scanState {
        case .idle:
            statusLabel.isHidden = true
            activityIndicator.stopAnimating()
            startScanButton.isEnabled = true
            startScanButton.alpha = 1.0
        case .recording:
            statusLabel.text = recordingStatusText()
            statusLabel.isHidden = false
            activityIndicator.stopAnimating()
            startScanButton.isEnabled = false
            startScanButton.alpha = 0.5
        case .uploading:
            statusLabel.text = t(.healthCheckAnalyzing)
            statusLabel.isHidden = false
            activityIndicator.startAnimating()
            startScanButton.isEnabled = false
            startScanButton.alpha = 0.5
        case .queued(let pos):
            statusLabel.text = String(format: t(.healthCheckQueuedPeopleAhead), pos)
            statusLabel.isHidden = false
            activityIndicator.startAnimating()
            startScanButton.isEnabled = false
            startScanButton.alpha = 0.5
        case .analyzing:
            statusLabel.text = t(.healthCheckSummarizing)
            statusLabel.isHidden = false
            activityIndicator.startAnimating()
            startScanButton.isEnabled = false
            startScanButton.alpha = 0.5
        case .completed:
            statusLabel.isHidden = true
            activityIndicator.stopAnimating()
            startScanButton.isEnabled = true
            startScanButton.alpha = 1.0
        case .failed(let msg):
            statusLabel.text = msg
            statusLabel.isHidden = false
            activityIndicator.stopAnimating()
            startScanButton.isEnabled = true
            startScanButton.alpha = 1.0
        }
    }

    // MARK: - 开始扫描

    @objc private func startScanTapped() {
        cameraManager.requestPermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.scanState = .failed(t(.healthCheckCameraPermissionDenied))
                return
            }
            self.presentCameraPreview()
        }
    }

    private func presentCameraPreview() {
        tabBarController?.tabBar.isHidden = true
        let container = UIView(frame: view.bounds)
        container.backgroundColor = .black
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(container)
        cameraContainerView = container

        cameraManager.previewLayer.frame = container.bounds
        container.layer.addSublayer(cameraManager.previewLayer)
        cameraManager.setupAndStart()

        let overlay = FaceGuideOverlayView(frame: container.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.onComplete = { [weak self] in self?.beginRecording() }
        container.addSubview(overlay)
        faceGuideOverlay = overlay
        overlay.startCountdown()

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle(t(.healthCheckCancel), for: .normal)
        cancelBtn.setTitleColor(.white, for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cancelBtn.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        cancelBtn.layer.cornerRadius = 14
        cancelBtn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.addTarget(self, action: #selector(cancelCameraPreview), for: .touchUpInside)
        container.addSubview(cancelBtn)
        NSLayoutConstraint.activate([
            cancelBtn.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 12),
            cancelBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        ])
    }

    private func beginRecording() {
        // 取消之前的任务，防止竞态
        scanTask?.cancel()

        guard rppgService.failureReason != .unsupportedOS else {
            scanState = .failed(t(.healthCheckUnsupportedOS))
            dismissCameraPreview()
            return
        }
        guard rppgService.isModelReady else {
            scanState = .failed(t(.healthCheckModelUnavailable))
            dismissCameraPreview()
            return
        }

        latestLiveSnapshot = nil
        rppgService.reset()
        cameraManager.onVideoFrame = { [weak self] buffer in
            self?.rppgService.processFrame(buffer, dt: 1.0 / 30.0)
        }
        scanState = .recording
        faceGuideOverlay?.startScanProgress(duration: 60)
        cameraManager.startRecording(duration: 60) { [weak self] url in
            guard let self else { return }
            self.cameraManager.onVideoFrame = nil
            self.cameraManager.stopSession()
            self.dismissCameraPreview()
            guard let videoURL = url else {
                self.scanState = .failed(t(.healthCheckRecordingFailed))
                return
            }
            self.finalizeAnalysis(recordedVideoURL: videoURL)
        }
    }

    @objc private func cancelCameraPreview() {
        cameraManager.onVideoFrame = nil
        faceGuideOverlay?.scanTimer?.invalidate()
        cameraManager.stopSession()
        dismissCameraPreview()
        scanState = .idle
    }

    private func dismissCameraPreview() {
        tabBarController?.tabBar.isHidden = false
        cameraContainerView?.removeFromSuperview()
        cameraContainerView = nil
        faceGuideOverlay = nil
    }

    // MARK: - 分析主流程

    private func finalizeAnalysis(recordedVideoURL _: URL) {
        scanTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.scanState = .analyzing
                self.updateUIForState()
            }
            guard !Task.isCancelled else { return }
            guard let result = self.rppgService.finalizeResult() else {
                await MainActor.run {
                    self.scanState = .failed(self.message(for: self.rppgService.failureReason))
                    self.updateUIForState()
                }
                return
            }

            let activeProfileID = (try? ProfileManager.shared.resolveActiveProfileID()) ?? nil
            let record = HealthRecord(from: result, profileId: activeProfileID)
            try? HealthRecordRepository.shared.save(record)

            await MainActor.run {
                self.scanState = .completed
                self.updateUIForState()
                let resultVC = HealthResultViewController(record: record)
                self.navigationController?.pushViewController(resultVC, animated: true)
            }
        }
    }

    private func handleLiveSnapshot(_ snapshot: RPPGLiveSnapshot) {
        latestLiveSnapshot = snapshot
        guard case .recording = scanState else { return }
        statusLabel.text = recordingStatusText()
    }

    private func recordingStatusText() -> String {
        guard let snapshot = latestLiveSnapshot else { return t(.healthCheckScanning) }

        let progressPercent = Int(snapshot.progress * 100)
        var segments: [String] = ["\(t(.healthCheckScanning)) \(progressPercent)%"]
        if let hr = snapshot.hr {
            segments.append("HR \(Int(hr.rounded()))")
        }
        if let sqi = snapshot.sqi {
            segments.append(String(format: "SQI %.2f", sqi))
        }
        return segments.joined(separator: " · ")
    }

    private func message(for failure: RPPGFailureReason?) -> String {
        switch failure {
        case .unsupportedOS:
            return t(.healthCheckUnsupportedOS)
        case .modelLoadFailed:
            return t(.healthCheckModelUnavailable)
        case .faceNotFound:
            return t(.healthCheckFaceNotFound)
        case .lowSignalQuality:
            return t(.healthCheckLowSignalQuality)
        case .predictionFailed:
            return t(.healthCheckPredictionFailed)
        case .insufficientFrames, .none:
            return t(.healthCheckSignalInsufficient)
        }
    }

    // MARK: - 收到历史更新通知

    @objc private func recordsDidUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshRecentChecks()
        }
    }

    #if DEBUG
    @objc private func debugLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        cameraManager.pickVideoFromLibrary(presenting: self) { [weak self] url in
            guard let self else { return }
            guard url != nil else { return }
            self.scanState = .failed("调试相册视频暂不支持端侧逐帧分析")
        }
    }
    #endif
}
