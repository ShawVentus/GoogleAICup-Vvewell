import UIKit
import Combine
import RingSDK

class RingDetailViewController: UIViewController {

    private let deviceManager = DeviceManager.shared
    private var cancellables = Set<AnyCancellable>()

    private let themeColor = AppDesign.Color.primaryGreen
    private let ringColor = UIColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1.0)

    // State
    private var connectionState: ConnectionState = .disconnected
    private var info: DeviceInfo?
    private var battery: Int?
    private var cachedFeatures: BTFeatureModel?

    // MARK: - UI

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        return sv
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        setupScrollView()
        syncDeviceState()
        observeDevice()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
        updateTitle()
        rebuildContent()
        queryFeatures()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncDeviceState()
        updateTitle()
        rebuildContent()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func updateTitle() {
        if let name = info?.name, !name.isEmpty {
            title = String(format: t(.ringTitleWithNameFormat), t(.ringDetailTitle), name)
        } else {
            title = t(.ringDetailTitle)
        }
    }

    @objc private func languageChanged() {
        updateTitle()
        rebuildContent()
    }

    // MARK: - Sync State

    /// Pre-populate state synchronously so the first render is correct.
    private func syncDeviceState() {
        guard let device = deviceManager.device(for: .ring) else { return }

        if device.isConnected() {
            connectionState = .connected
        }

        // Read initial values from CurrentValueSubject synchronously (no scheduler)
        device.deviceInfo
            .compactMap { $0 }
            .first()
            .sink { [weak self] val in self?.info = val }
            .store(in: &cancellables)

        device.batteryLevel
            .compactMap { $0 }
            .first()
            .sink { [weak self] val in self?.battery = val }
            .store(in: &cancellables)
    }

    // MARK: - Setup

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Observe

    private var needsRebuild = false

    private func scheduleRebuild() {
        guard !needsRebuild else { return }
        needsRebuild = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.needsRebuild = false
            self.rebuildContent()
        }
    }

    private func observeDevice() {
        guard let device = deviceManager.device(for: .ring) else { return }

        device.connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
                self?.scheduleRebuild()
            }
            .store(in: &cancellables)

        device.deviceInfo
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                self?.info = info
                self?.updateTitle()
                self?.scheduleRebuild()
            }
            .store(in: &cancellables)

        device.batteryLevel
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.battery = level
                self?.scheduleRebuild()
            }
            .store(in: &cancellables)
    }

    // MARK: - Rebuild

    private func rebuildContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let isConnected = connectionState == .connected || connectionState == .authSuccess

        contentStack.addArrangedSubview(makeDeviceHeaderCard())
        contentStack.addArrangedSubview(makeBatteryCard())

        if isConnected {
            contentStack.addArrangedSubview(makeSectionHeader(t(.ringDetailHealthMonitoring)))
            contentStack.addArrangedSubview(makeHealthFeaturesCard())

            contentStack.addArrangedSubview(makeSectionHeader(t(.ringDetailDeviceSettings)))
            contentStack.addArrangedSubview(makeSettingsCard())

            contentStack.addArrangedSubview(makeSectionHeader(t(.ringDetailFirmware)))
            contentStack.addArrangedSubview(makeFirmwareCard())

            if let features = cachedFeatures {
                contentStack.addArrangedSubview(makeSectionHeader(t(.ringDetailDeviceFeatures)))
                contentStack.addArrangedSubview(makeDeviceFeaturesCard(features: features))
            }
        }

        contentStack.addArrangedSubview(makeSectionHeader(""))
        contentStack.addArrangedSubview(makeActionButtonsCard())
    }

    // MARK: - Device Header Card

    private func makeDeviceHeaderCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        // Inner stack for robust vertical layout
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        // Top spacing
        let topSpacer = UIView()
        topSpacer.translatesAutoresizingMaskIntoConstraints = false
        topSpacer.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stack.addArrangedSubview(topSpacer)

        // Ring illustration
        let ringSize: CGFloat = 80
        let ringBg = UIView()
        ringBg.backgroundColor = ringColor.withAlphaComponent(0.1)
        ringBg.layer.cornerRadius = ringSize / 2
        ringBg.translatesAutoresizingMaskIntoConstraints = false

        let ringIcon = UIImageView(image: UIImage(systemName: "circle.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)))
        ringIcon.tintColor = ringColor
        ringIcon.contentMode = .scaleAspectFit
        ringIcon.translatesAutoresizingMaskIntoConstraints = false
        ringBg.addSubview(ringIcon)

        NSLayoutConstraint.activate([
            ringBg.widthAnchor.constraint(equalToConstant: ringSize),
            ringBg.heightAnchor.constraint(equalToConstant: ringSize),
            ringIcon.centerXAnchor.constraint(equalTo: ringBg.centerXAnchor),
            ringIcon.centerYAnchor.constraint(equalTo: ringBg.centerYAnchor),
        ])

        stack.addArrangedSubview(ringBg)
        stack.setCustomSpacing(16, after: ringBg)

        // Device name
        let nameLabel = UILabel()
        nameLabel.text = info?.name.isEmpty == false ? info!.name : t(.myDevicesSmartRing)
        nameLabel.font = .systemFont(ofSize: 20, weight: .bold)
        nameLabel.textColor = .label
        stack.addArrangedSubview(nameLabel)
        stack.setCustomSpacing(8, after: nameLabel)

        // Connection status pill
        let statusPill = makeStatusPill()
        stack.addArrangedSubview(statusPill)
        stack.setCustomSpacing(8, after: statusPill)

        // MAC address
        let macLabel = UILabel()
        macLabel.text = info?.macAddress ?? "—"
        macLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        macLabel.textColor = .tertiaryLabel
        stack.addArrangedSubview(macLabel)

        // Bottom spacing
        let bottomSpacer = UIView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stack.addArrangedSubview(bottomSpacer)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return container
    }

    private func makeStatusPill() -> UIView {
        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.layer.cornerRadius = 12

        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.layer.cornerRadius = 4
        pill.addSubview(dot)

        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        let isConnected = connectionState == .connected || connectionState == .authSuccess

        if isConnected {
            pill.backgroundColor = AppDesign.Color.connectedGreen.withAlphaComponent(0.12)
            dot.backgroundColor = AppDesign.Color.connectedGreen
            label.text = t(.myDevicesConnected)
            label.textColor = AppDesign.Color.connectedGreen
        } else if connectionState == .connecting {
            pill.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
            dot.backgroundColor = .systemOrange
            label.text = t(.myDevicesConnecting)
            label.textColor = .systemOrange
        } else {
            pill.backgroundColor = UIColor.systemGray5
            dot.backgroundColor = .systemGray
            label.text = t(.myDevicesDisconnected)
            label.textColor = .secondaryLabel
        }

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            dot.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -4),
        ])

        return pill
    }

    // MARK: - Battery Card

    private func makeBatteryCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        let batteryLevel = battery ?? 0
        let hasBattery = battery != nil
        let color = hasBattery ? batteryColor(level: batteryLevel) : UIColor.systemGray3

        // Top row: icon + label + value
        let batteryIcon = UIImageView(image: UIImage(systemName: batteryIconName(level: batteryLevel)))
        batteryIcon.tintColor = color
        batteryIcon.contentMode = .scaleAspectFit
        batteryIcon.translatesAutoresizingMaskIntoConstraints = false
        batteryIcon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        batteryIcon.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let batteryLabel = UILabel()
        batteryLabel.text = t(.myDevicesBattery)
        batteryLabel.font = .systemFont(ofSize: 15, weight: .medium)
        batteryLabel.textColor = .label

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = hasBattery ? "\(batteryLevel)%" : "—"
        valueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        valueLabel.textColor = color

        let topRow = UIStackView(arrangedSubviews: [batteryIcon, batteryLabel, spacer, valueLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 8

        // Progress bar
        let trackView = UIView()
        trackView.backgroundColor = .systemGray5
        trackView.layer.cornerRadius = 4
        trackView.translatesAutoresizingMaskIntoConstraints = false
        trackView.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let fillView = UIView()
        fillView.backgroundColor = hasBattery ? color : .systemGray4
        fillView.layer.cornerRadius = 4
        fillView.translatesAutoresizingMaskIntoConstraints = false
        trackView.addSubview(fillView)

        let fillFraction = hasBattery ? CGFloat(batteryLevel) / 100.0 : 0

        NSLayoutConstraint.activate([
            fillView.topAnchor.constraint(equalTo: trackView.topAnchor),
            fillView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            fillView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            fillView.widthAnchor.constraint(equalTo: trackView.widthAnchor, multiplier: max(fillFraction, 0.001)),
        ])

        // Vertical stack
        let stack = UIStackView(arrangedSubviews: [topRow, trackView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return container
    }

    // MARK: - Health Features Card

    private func makeHealthFeaturesCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let features: [(icon: String, title: String, subtitle: String, color: UIColor, tag: Int)] = [
            ("heart.fill", t(.ringDetailFeatureHeartRateTitle), t(.ringDetailFeatureHeartRateSubtitle), .systemRed, 200),
            ("drop.fill", t(.ringDetailFeatureBloodOxygenTitle), t(.ringDetailFeatureBloodOxygenSubtitle), .systemBlue, 201),
            ("waveform.path.ecg", t(.ringDetailFeatureECGTitle), t(.ringDetailFeatureECGSubtitle), .systemPink, 202),
            ("moon.fill", t(.ringDetailFeatureSleepTitle), t(.ringDetailFeatureSleepSubtitle), .systemIndigo, 203),
            ("figure.run", t(.ringDetailFeatureSportsTitle), t(.ringDetailFeatureSportsSubtitle), .systemOrange, 204),
            ("brain.head.profile", t(.ringDetailFeatureStressTitle), t(.ringDetailFeatureStressSubtitle), .systemTeal, 205),
            ("thermometer.medium", t(.ringDetailFeatureTemperatureTitle), t(.ringDetailFeatureTemperatureSubtitle), .systemYellow, 206),
        ]

        for (index, feature) in features.enumerated() {
            let row = makeFeatureRow(
                icon: feature.icon,
                title: feature.title,
                subtitle: feature.subtitle,
                color: feature.color,
                tag: feature.tag
            )
            stack.addArrangedSubview(row)

            if index < features.count - 1 {
                // Wrap separator in a container to avoid StackView constraint conflict
                let sepContainer = UIView()
                sepContainer.translatesAutoresizingMaskIntoConstraints = false
                let separator = UIView()
                separator.backgroundColor = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                sepContainer.addSubview(separator)
                NSLayoutConstraint.activate([
                    sepContainer.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),
                    separator.topAnchor.constraint(equalTo: sepContainer.topAnchor),
                    separator.bottomAnchor.constraint(equalTo: sepContainer.bottomAnchor),
                    separator.leadingAnchor.constraint(equalTo: sepContainer.leadingAnchor, constant: 56),
                    separator.trailingAnchor.constraint(equalTo: sepContainer.trailingAnchor),
                ])
                stack.addArrangedSubview(sepContainer)
            }
        }

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return container
    }

    private func makeFeatureRow(icon: String, title: String, subtitle: String, color: UIColor, tag: Int) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconSize: CGFloat = 32
        let iconBg = UIView()
        iconBg.backgroundColor = color.withAlphaComponent(0.1)
        iconBg.layer.cornerRadius = 8
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconBg)

        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(subtitleLabel)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(chevron)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 56),

            iconBg.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconBg.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: iconSize),
            iconBg.heightAnchor.constraint(equalToConstant: iconSize),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        // Tap gesture
        row.tag = tag
        row.isUserInteractionEnabled = true
        row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(featureRowTapped(_:))))

        return row
    }

    // MARK: - Settings Card

    private func makeSettingsCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let settings: [(icon: String, title: String, color: UIColor, tag: Int)] = [
            ("clock.arrow.2.circlepath", t(.ringDetailSettingMeasurementInterval), .systemBlue, 300),
            ("alarm.fill", t(.ringDetailSettingAlarms), .systemOrange, 301),
            ("iphone.radiowaves.left.and.right", t(.ringDetailSettingVibrationAlerts), .systemPurple, 302),
            ("hand.tap.fill", t(.ringDetailSettingTouchActions), .systemTeal, 303),
            ("sos", t(.ringDetailSettingSOS), .systemRed, 304),
        ]

        for (index, setting) in settings.enumerated() {
            let row = makeSettingRow(
                icon: setting.icon,
                title: setting.title,
                color: setting.color,
                tag: setting.tag
            )
            stack.addArrangedSubview(row)

            if index < settings.count - 1 {
                let sepContainer = UIView()
                sepContainer.translatesAutoresizingMaskIntoConstraints = false
                let separator = UIView()
                separator.backgroundColor = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                sepContainer.addSubview(separator)
                NSLayoutConstraint.activate([
                    sepContainer.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),
                    separator.topAnchor.constraint(equalTo: sepContainer.topAnchor),
                    separator.bottomAnchor.constraint(equalTo: sepContainer.bottomAnchor),
                    separator.leadingAnchor.constraint(equalTo: sepContainer.leadingAnchor, constant: 52),
                    separator.trailingAnchor.constraint(equalTo: sepContainer.trailingAnchor),
                ])
                stack.addArrangedSubview(sepContainer)
            }
        }

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return container
    }

    private func makeSettingRow(icon: String, title: String, color: UIColor, tag: Int) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(titleLabel)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(chevron)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 44),

            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        row.tag = tag
        row.isUserInteractionEnabled = true
        row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(settingRowTapped(_:))))

        return row
    }

    // MARK: - Firmware Card

    private func makeFirmwareCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        // Firmware icon
        let iconSize: CGFloat = 32
        let iconBg = UIView()
        iconBg.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        iconBg.layer.cornerRadius = 8
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconBg)

        let iconView = UIImageView(image: UIImage(systemName: "cpu", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)))
        iconView.tintColor = .systemGreen
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        // Version info
        let versionTitle = UILabel()
        versionTitle.text = t(.ringDetailFirmwareVersion)
        versionTitle.font = .systemFont(ofSize: 15, weight: .medium)
        versionTitle.textColor = .label
        versionTitle.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(versionTitle)

        let versionValue = UILabel()
        versionValue.text = info?.firmwareVersion ?? "—"
        versionValue.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        versionValue.textColor = .secondaryLabel
        versionValue.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(versionValue)

        // Check update button
        let updateBtn = UIButton(type: .system)
        updateBtn.setTitle(t(.ringDetailCheckForUpdates), for: .normal)
        updateBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        updateBtn.setTitleColor(themeColor, for: .normal)
        updateBtn.translatesAutoresizingMaskIntoConstraints = false
        updateBtn.addTarget(self, action: #selector(checkUpdateTapped), for: .touchUpInside)
        card.addSubview(updateBtn)

        // Hardware version row
        let hwLabel = UILabel()
        hwLabel.text = t(.ringDetailHardware)
        hwLabel.font = .systemFont(ofSize: 13)
        hwLabel.textColor = .tertiaryLabel
        hwLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(hwLabel)

        let hwValue = UILabel()
        hwValue.text = info?.hardwareVersion ?? "—"
        hwValue.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        hwValue.textColor = .tertiaryLabel
        hwValue.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(hwValue)

        // Serial number row
        let snLabel = UILabel()
        snLabel.text = t(.ringDetailSerial)
        snLabel.font = .systemFont(ofSize: 13)
        snLabel.textColor = .tertiaryLabel
        snLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(snLabel)

        let snValue = UILabel()
        snValue.text = info?.serialNumber ?? "—"
        snValue.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        snValue.textColor = .tertiaryLabel
        snValue.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(snValue)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            iconBg.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconBg.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconBg.widthAnchor.constraint(equalToConstant: iconSize),
            iconBg.heightAnchor.constraint(equalToConstant: iconSize),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            versionTitle.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            versionTitle.topAnchor.constraint(equalTo: iconBg.topAnchor),

            versionValue.leadingAnchor.constraint(equalTo: versionTitle.leadingAnchor),
            versionValue.topAnchor.constraint(equalTo: versionTitle.bottomAnchor, constant: 2),

            updateBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            updateBtn.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            hwLabel.topAnchor.constraint(equalTo: iconBg.bottomAnchor, constant: 16),
            hwLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            hwValue.centerYAnchor.constraint(equalTo: hwLabel.centerYAnchor),
            hwValue.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            snLabel.topAnchor.constraint(equalTo: hwLabel.bottomAnchor, constant: 8),
            snLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            snLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            snValue.centerYAnchor.constraint(equalTo: snLabel.centerYAnchor),
            snValue.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])

        return container
    }

    // MARK: - Action Buttons Card

    private func makeActionButtonsCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let isConnected = connectionState == .connected || connectionState == .authSuccess

        if isConnected {
            stack.addArrangedSubview(makeActionRow(icon: "waveform.path.ecg", title: "SpO2 验证与趋势", color: AppDesign.Color.primaryGreen, tag: 404))
            stack.addArrangedSubview(makeSeparator())
            stack.addArrangedSubview(makeActionRow(icon: "arrow.triangle.2.circlepath", title: "历史数据同步调试", color: .systemBlue, tag: 405))
            stack.addArrangedSubview(makeSeparator())

            // Find My Ring
            let findRow = makeActionRow(
                icon: "location.circle.fill",
                title: t(.ringDetailFindMyRing),
                color: .systemBlue,
                tag: 400
            )
            stack.addArrangedSubview(findRow)

            let sep1 = makeSeparator()
            stack.addArrangedSubview(sep1)

            // Restart
            let restartRow = makeActionRow(
                icon: "arrow.clockwise.circle.fill",
                title: t(.ringDetailRestartDevice),
                color: .systemOrange,
                tag: 401
            )
            stack.addArrangedSubview(restartRow)

            let sep2 = makeSeparator()
            stack.addArrangedSubview(sep2)

            // Disconnect
            let disconnectRow = makeActionRow(
                icon: "wifi.slash",
                title: t(.myDevicesDisconnect),
                color: .systemRed,
                tag: 402
            )
            stack.addArrangedSubview(disconnectRow)

            let sep3 = makeSeparator()
            stack.addArrangedSubview(sep3)
        }

        // Factory Reset / Forget
        let resetRow = makeActionRow(
            icon: "trash.circle.fill",
            title: isConnected ? t(.ringDetailFactoryReset) : t(.ringDetailForgetDevice),
            color: .systemRed,
            tag: 403
        )
        stack.addArrangedSubview(resetRow)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return container
    }

    private func makeActionRow(icon: String, title: String, color: UIColor, tag: Int) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = color == .systemRed ? .systemRed : .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 48),

            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        row.tag = tag
        row.isUserInteractionEnabled = true
        row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(actionRowTapped(_:))))

        return row
    }

    // MARK: - Section Header

    private func makeSectionHeader(_ title: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func makeSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
        return separator
    }

    // MARK: - Helpers

    private func batteryIconName(level: Int) -> String {
        switch level {
        case 0..<20: return "battery.0percent"
        case 20..<50: return "battery.25percent"
        case 50..<75: return "battery.50percent"
        case 75..<100: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private func batteryColor(level: Int) -> UIColor {
        if level < 20 { return .systemRed }
        if level < 50 { return .systemOrange }
        return AppDesign.Color.connectedGreen
    }

    // MARK: - Actions

    @objc private func featureRowTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag else { return }
        switch tag {
        case 200, 201, 203, 206:
            navigationController?.pushViewController(RingCheckViewController(), animated: true)
        case 202:
            navigationController?.pushViewController(ECGCheckViewController(), animated: true)
        case 204:
            navigationController?.pushViewController(SportViewController(), animated: true)
        case 205:
            navigationController?.pushViewController(EmotionCheckViewController(), animated: true)
        default: break
        }
    }

    @objc private func settingRowTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag else { return }
        switch tag {
        case 300:
            presentMeasurementIntervalPicker()
        case 302:
            testRingVibration()
        case 301, 303, 304:
            presentSDKSettingNotice(tag: tag)
        default: break
        }
    }

    private func presentMeasurementIntervalPicker() {
        guard let ring = deviceManager.device(for: .ring) as? RingDevice else { return }
        let sheet = UIAlertController(title: t(.ringDetailSettingMeasurementInterval), message: nil, preferredStyle: .actionSheet)
        [5, 10, 15, 30].forEach { minutes in
            sheet.addAction(UIAlertAction(title: "\(minutes) min", style: .default) { [weak self] _ in
                guard let self else { return }
                ring.settingsService.setMeasurementInterval(minutes)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] success in
                        let result = UIAlertController(title: success ? "已更新" : "更新失败", message: success ? "\(minutes) min" : "RingSDK rejected the interval.", preferredStyle: .alert)
                        result.addAction(UIAlertAction(title: t(.confirm), style: .default))
                        self?.present(result, animated: true)
                    }
                    .store(in: &self.cancellables)
            })
        }
        sheet.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(sheet, animated: true)
    }

    private func testRingVibration() {
        guard let ring = deviceManager.device(for: .ring) as? RingDevice else { return }
        ring.settingsService.sendVibration(type: .systemEvent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] success in
                let alert = UIAlertController(title: success ? "振动已发送" : "发送失败", message: success ? "RingSDK 已接受振动命令。" : "请检查戒指连接。", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                self?.present(alert, animated: true)
            }
            .store(in: &cancellables)
    }

    private func presentSDKSettingNotice(tag: Int) {
        let names = [301: t(.ringDetailSettingAlarms), 303: t(.ringDetailSettingTouchActions), 304: t(.ringDetailSettingSOS)]
        let alert = UIAlertController(
            title: names[tag],
            message: "RingSDK supports this capability, but its manufacturer model editor is not shipped as an iOS view. The entry remains explicit and does not write guessed settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
        present(alert, animated: true)
    }

    @objc private func checkUpdateTapped() {
        if let ringDevice = deviceManager.device(for: .ring) as? RingDevice {
            let subject = ringDevice.otaService.checkUpdate()
            subject
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] event in
                    switch event {
                    case .available(let info):
                        let alert = UIAlertController(
                            title: t(.ringDetailUpdateAvailableTitle),
                            message: String(format: t(.ringDetailUpdateAvailableMessage), info.currentVersion),
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: t(.ringDetailLater), style: .cancel))
                        alert.addAction(UIAlertAction(title: t(.ringDetailUpdateAction), style: .default) { _ in
                            self?.startPendingRingUpgrade()
                        })
                        self?.present(alert, animated: true)
                    case .notAvailable:
                        let alert = UIAlertController(
                            title: t(.ringDetailUpToDateTitle),
                            message: t(.ringDetailUpToDateMessage),
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                        self?.present(alert, animated: true)
                    case .failed:
                        let alert = UIAlertController(
                            title: t(.ringDetailCheckFailedTitle),
                            message: t(.ringDetailCheckFailedMessage),
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                        self?.present(alert, animated: true)
                    default:
                        break
                    }
                })
                .store(in: &cancellables)
        } else {
            // Mock: simulate "up to date"
            let alert = UIAlertController(
                title: t(.ringDetailUpToDateTitle),
                message: t(.ringDetailUpToDateMessage),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
            present(alert, animated: true)
        }
    }

    private func startPendingRingUpgrade() {
        guard let ringDevice = deviceManager.device(for: .ring) as? RingDevice else { return }
        let progress = UIProgressView(progressViewStyle: .default)
        progress.translatesAutoresizingMaskIntoConstraints = false
        let alert = UIAlertController(title: "正在更新戒指", message: "请保持戒指连接并将应用停留在前台。", preferredStyle: .alert)
        alert.view.addSubview(progress)
        NSLayoutConstraint.activate([
            progress.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
            progress.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20),
            progress.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -52),
        ])
        present(alert, animated: true)

        ringDevice.otaService.startPendingUpgrade()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                guard let self else { return }
                if self.presentedViewController === alert { self.dismiss(animated: true) }
            }, receiveValue: { event in
                switch event {
                case .downloading(let value), .installing(let value):
                    progress.progress = value
                case .completed:
                    alert.title = "更新完成"
                    alert.message = "戒指固件已更新。"
                    alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                case .failed(let error):
                    alert.title = "更新失败"
                    alert.message = error.localizedDescription
                    alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                default:
                    break
                }
            })
            .store(in: &cancellables)
    }

    @objc private func actionRowTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag else { return }
        guard let device = deviceManager.device(for: .ring) else { return }
        let ringDevice = device as? RingDevice

        switch tag {
        case 404:
            let alert = UIAlertController(
                title: "SpO2 验证与趋势",
                message: "RingSDK 可提供实时血氧测量与本地趋势，请从健康检测进入。Android 所用的原始 PPG/ACC 验证流未在随附 iOS RingSDK 中公开，因此不会生成伪造波形。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "打开健康检测", style: .default) { [weak self] _ in self?.navigationController?.pushViewController(RingCheckViewController(), animated: true) })
            alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
            present(alert, animated: true)

        case 405:
            let alert = UIAlertController(
                title: "历史数据同步调试",
                message: "本地健康与睡眠趋势可在健康检测中查看。随附 iOS RingSDK 未公开 Android 历史批量同步/导出 API，因此此入口不会伪造同步进度或记录。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "查看健康趋势", style: .default) { [weak self] _ in self?.navigationController?.pushViewController(RingCheckViewController(), animated: true) })
            alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
            present(alert, animated: true)

        case 400: // Find My Ring
            if let ringDevice = ringDevice {
                ringDevice.settingsService.sendVibration(type: .systemEvent)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] success in
                        if success {
                            let alert = UIAlertController(title: nil, message: t(.ringDetailVibratingMessage), preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                            self?.present(alert, animated: true)
                        }
                    }
                    .store(in: &cancellables)
            } else {
                let alert = UIAlertController(title: nil, message: t(.ringDetailVibratingMessage), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                present(alert, animated: true)
            }

        case 401: // Restart
            let alert = UIAlertController(
                title: t(.ringDetailRestartDevice),
                message: t(.ringDetailRestartMessage),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
            alert.addAction(UIAlertAction(title: t(.ringDetailRestartAction), style: .default) { [weak self] _ in
                guard let self = self else { return }
                if let ringDevice = ringDevice {
                    ringDevice.settingsService.restartDevice()
                        .receive(on: DispatchQueue.main)
                        .sink { _ in }
                        .store(in: &self.cancellables)
                }
            })
            present(alert, animated: true)

        case 402: // Disconnect
            let alert = UIAlertController(
                title: t(.myDevicesDisconnect),
                message: t(.ringDetailDisconnectMessage),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
            alert.addAction(UIAlertAction(title: t(.myDevicesDisconnect), style: .destructive) { _ in
                device.disconnect()
            })
            present(alert, animated: true)

        case 403: // Factory Reset / Forget
            let isConnected = connectionState == .connected || connectionState == .authSuccess
            let title = isConnected ? t(.ringDetailFactoryReset) : t(.ringDetailForgetDevice)
            let message = isConnected
                ? t(.ringDetailFactoryResetMessage)
                : t(.ringDetailForgetMessage)

            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
            alert.addAction(UIAlertAction(title: title, style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                if isConnected, let ringDevice = ringDevice {
                    ringDevice.settingsService.resetDevice()
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] _ in
                            device.disconnect()
                            self?.navigationController?.popViewController(animated: true)
                        }
                        .store(in: &self.cancellables)
                } else {
                    device.disconnect()
                    self.navigationController?.popViewController(animated: true)
                }
            })
            present(alert, animated: true)

        default:
            break
        }
    }

    // MARK: - Device Features

    private func queryFeatures() {
        let isConnected = connectionState == .connected || connectionState == .authSuccess
        guard isConnected else { return }
        BTService.shared().baseReq.fetch(.features) { [weak self] obj, _ in
            guard let self = self, let features = obj as? BTFeatureModel else { return }
            DispatchQueue.main.async {
                self.cachedFeatures = features
                self.logFeatures(features)
                self.rebuildContent()
            }
        }
    }

    private func logFeatures(_ f: BTFeatureModel) {
#if DEBUG
        print("""
        [DeviceFeatures] ═══════════════════════════════════════
        [DeviceFeatures] DEVICE CAPABILITY REPORT
        [DeviceFeatures] ═══════════════════════════════════════
        [DeviceFeatures]
        [DeviceFeatures] --- Measurement ---
        [DeviceFeatures] heartRate=\(f.hrMeasurement) (\(featureLabel(f.hrMeasurement)))
        [DeviceFeatures] bloodOxygen=\(f.bloodOxygenMeasurement) (\(featureLabel(f.bloodOxygenMeasurement)))
        [DeviceFeatures] bodyTemperature=\(f.bodyTempMeasurement) (\(featureLabel(f.bodyTempMeasurement)))
        [DeviceFeatures] ecg=\(f.ecgMeasurement) (\(featureLabel(f.ecgMeasurement)))
        [DeviceFeatures] stress=\(f.isSupportStress) (\(featureLabel(f.isSupportStress)))
        [DeviceFeatures] bodyComposition=\(f.isSupportBC) (\(featureLabel(f.isSupportBC)))
        [DeviceFeatures] bloodGlucose=\(f.isSupportGlu) (\(featureLabel(f.isSupportGlu)))
        [DeviceFeatures] emotion=\(f.isSupportEmotion) (\(featureLabel(f.isSupportEmotion)))
        [DeviceFeatures] uv=\(f.isUVSupported) (\(featureLabel(f.isUVSupported)))
        [DeviceFeatures] sleep=\(f.sleepMeasurement) (\(featureLabel(f.sleepMeasurement)))
        [DeviceFeatures] menstrualCycle=\(f.mcMeasurement) (\(featureLabel(f.mcMeasurement)))
        [DeviceFeatures]
        [DeviceFeatures] --- Interaction ---
        [DeviceFeatures] touchSwitch=\(f.isSupportTouchSwitch) (\(featureLabel(f.isSupportTouchSwitch)))
        [DeviceFeatures] gestureWakeup=\(f.isSupportGestureWakeup) (\(featureLabel(f.isSupportGestureWakeup)))
        [DeviceFeatures] touchVideoMode=\(f.touchVideMode) (\(featureLabel(f.touchVideMode)))
        [DeviceFeatures] touchWebMode=\(f.touchWebMode) (\(featureLabel(f.touchWebMode)))
        [DeviceFeatures] touchSleepMode=\(f.isSupportTouchSleepMode) (\(featureLabel(f.isSupportTouchSleepMode)))
        [DeviceFeatures] touchSleepDelay=\(f.touchSleepDelay) (\(featureLabel(f.touchSleepDelay)))
        [DeviceFeatures] oneKeyMagic=\(f.isSupportonKeyMagic) (\(featureLabel(f.isSupportonKeyMagic)))
        [DeviceFeatures] vibration=\(f.isSupportVibration) (\(featureLabel(f.isSupportVibration)))
        [DeviceFeatures]
        [DeviceFeatures] --- Safety ---
        [DeviceFeatures] sos=\(f.isSupportSOS) (\(featureLabel(f.isSupportSOS)))
        [DeviceFeatures] sosTriggerMode=\(f.sosTriggerMode) (1=TP,2=gesture,3=both)
        [DeviceFeatures] careReminder=\(f.isSupportCareUser) (\(featureLabel(f.isSupportCareUser)))
        [DeviceFeatures] messageNotice=\(f.isSupportMessageNotice) (\(featureLabel(f.isSupportMessageNotice)))
        [DeviceFeatures]
        [DeviceFeatures] --- Advanced ---
        [DeviceFeatures] philipsSleep=\(f.isSupportPhilpsSleep) (\(featureLabel(f.isSupportPhilpsSleep)))
        [DeviceFeatures] multiSport=\(f.isSportMores) (\(featureLabel(f.isSportMores)))
        [DeviceFeatures] recording=\(f.isSupportRecord) (\(featureLabel(f.isSupportRecord)))
        [DeviceFeatures] colorLight=\(f.isSupportLamp) (\(featureLabel(f.isSupportLamp)))
        [DeviceFeatures] doNotDisturb=\(f.isSupportSleepNotDisturb) (\(featureLabel(f.isSupportSleepNotDisturb)))
        [DeviceFeatures] newHandMode=\(f.isSupportHandNew) (\(featureLabel(f.isSupportHandNew)))
        [DeviceFeatures] menstrualV2=\(f.isSupportMenstrualCycle) (\(featureLabel(f.isSupportMenstrualCycle)))
        [DeviceFeatures]
        [DeviceFeatures] ═══════════════════════════════════════
        [DeviceFeatures] SUMMARY: \(countSupported(f)) of 28 features supported
        [DeviceFeatures] ═══════════════════════════════════════
        """)
#endif
    }

    private func featureLabel(_ value: UInt8) -> String {
        switch value {
        case 0: return "NOT_SUPPORTED"
        case 1: return "SUPPORTED"
        case 2: return "ALWAYS_ON"
        case 3: return "REMOTE_TRIGGER"
        default: return "UNKNOWN(\(value))"
        }
    }

    private func countSupported(_ f: BTFeatureModel) -> Int {
        let values: [UInt8] = [
            f.hrMeasurement, f.bloodOxygenMeasurement, f.bodyTempMeasurement,
            f.ecgMeasurement, f.isSupportStress, f.isSupportBC, f.isSupportGlu,
            f.isSupportEmotion, f.isUVSupported, f.sleepMeasurement, f.mcMeasurement,
            f.isSupportTouchSwitch, f.isSupportGestureWakeup, f.touchVideMode,
            f.touchWebMode, f.isSupportTouchSleepMode, f.touchSleepDelay,
            f.isSupportonKeyMagic, f.isSupportVibration,
            f.isSupportSOS, f.isSupportCareUser, f.isSupportMessageNotice,
            f.isSupportPhilpsSleep, f.isSportMores, f.isSupportRecord,
            f.isSupportLamp, f.isSupportSleepNotDisturb, f.isSupportHandNew,
            f.isSupportMenstrualCycle,
        ]
        return values.filter { $0 > 0 }.count
    }

    private func makeDeviceFeaturesCard(features: BTFeatureModel) -> UIView {
        // Use same container→card→stack pattern as other cards
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let allFeatures: [DeviceFeatureItem] = [
            // Measurement
            DeviceFeatureItem(name: t(.ringDetailFeatureHeartRateTitle), desc: t(.ringDetailFeatureHeartRateSubtitle), value: features.hrMeasurement, icon: "heart.fill", color: .systemRed, category: "Measurement"),
            DeviceFeatureItem(name: t(.ringDetailFeatureBloodOxygenTitle), desc: t(.ringDetailFeatureBloodOxygenSubtitle), value: features.bloodOxygenMeasurement, icon: "lungs.fill", color: .systemBlue, category: "Measurement"),
            DeviceFeatureItem(name: t(.ringDetailFeatureTemperatureTitle), desc: t(.ringDetailFeatureTemperatureSubtitle), value: features.bodyTempMeasurement, icon: "thermometer.medium", color: .systemYellow, category: "Measurement"),
            DeviceFeatureItem(name: t(.ringDetailFeatureECGTitle), desc: t(.ringDetailFeatureECGSubtitle), value: features.ecgMeasurement, icon: "waveform.path.ecg", color: .systemPink, category: "Measurement"),
            DeviceFeatureItem(name: t(.ringDetailFeatureStressTitle), desc: t(.ringDetailFeatureStressSubtitle), value: features.isSupportStress, icon: "brain.head.profile", color: .systemTeal, category: "Measurement"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityBodyCompositionTitle), desc: t(.ringDetailCapabilityBodyCompositionSubtitle), value: features.isSupportBC, icon: "chart.bar.fill", color: .systemOrange, category: "Measurement"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityBloodGlucoseTitle), desc: t(.ringDetailCapabilityBloodGlucoseSubtitle), value: features.isSupportGlu, icon: "drop.fill", color: .systemYellow, category: "Measurement"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityEmotionPPITitle), desc: t(.ringDetailCapabilityEmotionPPISubtitle), value: features.isSupportEmotion, icon: "face.smiling", color: .systemTeal, category: "Measurement"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityUVRadiationTitle), desc: t(.ringDetailCapabilityUVRadiationSubtitle), value: features.isUVSupported, icon: "sun.max.fill", color: .systemOrange, category: "Measurement"),
            DeviceFeatureItem(name: t(.ringDetailFeatureSleepTitle), desc: t(.ringDetailFeatureSleepSubtitle), value: features.sleepMeasurement, icon: "moon.fill", color: .systemIndigo, category: "Measurement"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityMenstrualCycleTitle), desc: t(.ringDetailCapabilityMenstrualCycleSubtitle), value: features.mcMeasurement, icon: "calendar.circle", color: .systemPink, category: "Measurement"),

            // Interaction
            DeviceFeatureItem(name: t(.ringDetailCapabilityTouchSwitchTitle), desc: t(.ringDetailCapabilityTouchSwitchSubtitle), value: features.isSupportTouchSwitch, icon: "hand.tap", color: .systemGray, category: "Interaction"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityGestureWakeupTitle), desc: t(.ringDetailCapabilityGestureWakeupSubtitle), value: features.isSupportGestureWakeup, icon: "hand.raised", color: .systemGray, category: "Interaction"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityTouchVideoModeTitle), desc: t(.ringDetailCapabilityTouchVideoModeSubtitle), value: features.touchVideMode, icon: "video.fill", color: .systemGray, category: "Interaction"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityTouchWebModeTitle), desc: t(.ringDetailCapabilityTouchWebModeSubtitle), value: features.touchWebMode, icon: "safari", color: .systemGray, category: "Interaction"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityTouchSleepModeTitle), desc: t(.ringDetailCapabilityTouchSleepModeSubtitle), value: features.isSupportTouchSleepMode, icon: "bed.double", color: .systemGray, category: "Interaction"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityTouchSleepDelayTitle), desc: t(.ringDetailCapabilityTouchSleepDelaySubtitle), value: features.touchSleepDelay, icon: "timer", color: .systemGray, category: "Interaction"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityOneKeyMagicTitle), desc: t(.ringDetailCapabilityOneKeyMagicSubtitle), value: features.isSupportonKeyMagic, icon: "wand.and.stars", color: .systemGray, category: "Interaction"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityVibrationTitle), desc: t(.ringDetailCapabilityVibrationSubtitle), value: features.isSupportVibration, icon: "iphone.radiowaves.left.and.right", color: .systemGray, category: "Interaction"),

            // Safety
            DeviceFeatureItem(name: t(.ringDetailCapabilitySOSTitle), desc: t(.ringDetailCapabilitySOSSubtitle), value: features.isSupportSOS, icon: "sos.circle.fill", color: .systemRed, category: "Safety"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityCareReminderTitle), desc: t(.ringDetailCapabilityCareReminderSubtitle), value: features.isSupportCareUser, icon: "heart.text.square", color: .systemPink, category: "Safety"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityMessageNoticeTitle), desc: t(.ringDetailCapabilityMessageNoticeSubtitle), value: features.isSupportMessageNotice, icon: "bell.fill", color: .systemBlue, category: "Safety"),

            // Advanced
            DeviceFeatureItem(name: t(.ringDetailCapabilityPhilipsSleepTitle), desc: t(.ringDetailCapabilityPhilipsSleepSubtitle), value: features.isSupportPhilpsSleep, icon: "powersleep", color: .systemPurple, category: "Advanced"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityMultiSportTitle), desc: t(.ringDetailCapabilityMultiSportSubtitle), value: features.isSportMores, icon: "figure.run.circle", color: .systemOrange, category: "Advanced"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityRecordingTitle), desc: t(.ringDetailCapabilityRecordingSubtitle), value: features.isSupportRecord, icon: "mic.fill", color: .systemRed, category: "Advanced"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityColorLightTitle), desc: t(.ringDetailCapabilityColorLightSubtitle), value: features.isSupportLamp, icon: "lightbulb.fill", color: .systemYellow, category: "Advanced"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityDoNotDisturbTitle), desc: t(.ringDetailCapabilityDoNotDisturbSubtitle), value: features.isSupportSleepNotDisturb, icon: "moon.zzz.fill", color: .systemIndigo, category: "Advanced"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityNewHandModeTitle), desc: t(.ringDetailCapabilityNewHandModeSubtitle), value: features.isSupportHandNew, icon: "hand.point.up", color: .systemGray, category: "Advanced"),
            DeviceFeatureItem(name: t(.ringDetailCapabilityMenstrualV2Title), desc: t(.ringDetailCapabilityMenstrualV2Subtitle), value: features.isSupportMenstrualCycle, icon: "calendar.badge.clock", color: .systemPink, category: "Advanced"),
        ]

        var currentCategory = ""
        for (index, feature) in allFeatures.enumerated() {
            if feature.category != currentCategory {
                currentCategory = feature.category
                let catLabel = UILabel()
                catLabel.text = "  \(localizedFeatureCategory(feature.category))"
                catLabel.font = .systemFont(ofSize: 11, weight: .semibold)
                catLabel.textColor = themeColor
                catLabel.backgroundColor = themeColor.withAlphaComponent(0.04)
                catLabel.translatesAutoresizingMaskIntoConstraints = false
                catLabel.heightAnchor.constraint(equalToConstant: 28).isActive = true
                stack.addArrangedSubview(catLabel)
            }

            let row = makeDeviceFeatureRow(feature: feature)
            stack.addArrangedSubview(row)

            // Separator between rows (not after last in category or last overall)
            let isLastOverall = index == allFeatures.count - 1
            let isLastInCategory = index + 1 < allFeatures.count && allFeatures[index + 1].category != feature.category
            if !isLastOverall && !isLastInCategory {
                let sepContainer = UIView()
                sepContainer.translatesAutoresizingMaskIntoConstraints = false
                let sep = UIView()
                sep.backgroundColor = UIColor.separator.withAlphaComponent(0.15)
                sep.translatesAutoresizingMaskIntoConstraints = false
                sepContainer.addSubview(sep)
                NSLayoutConstraint.activate([
                    sepContainer.heightAnchor.constraint(equalToConstant: 0.5),
                    sep.topAnchor.constraint(equalTo: sepContainer.topAnchor),
                    sep.bottomAnchor.constraint(equalTo: sepContainer.bottomAnchor),
                    sep.leadingAnchor.constraint(equalTo: sepContainer.leadingAnchor, constant: 52),
                    sep.trailingAnchor.constraint(equalTo: sepContainer.trailingAnchor),
                ])
                stack.addArrangedSubview(sepContainer)
            }
        }

        // Summary
        let supported = allFeatures.filter { $0.value > 0 }.count
        let summaryLabel = UILabel()
        summaryLabel.text = String(format: t(.ringDetailFeatureSummaryFormat), supported, allFeatures.count)
        summaryLabel.font = .systemFont(ofSize: 12, weight: .medium)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.textAlignment = .center
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(summaryLabel)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            summaryLabel.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 12),
            summaryLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            summaryLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return container
    }

    private struct DeviceFeatureItem {
        let name: String
        let desc: String
        let value: UInt8
        let icon: String
        let color: UIColor
        let category: String
    }

    private func localizedFeatureCategory(_ category: String) -> String {
        switch category {
        case "Measurement": return t(.ringDetailCategoryMeasurement)
        case "Interaction": return t(.ringDetailCategoryInteraction)
        case "Safety": return t(.ringDetailCategorySafety)
        case "Advanced": return t(.ringDetailCategoryAdvanced)
        default: return category
        }
    }

    private func paddedFeatureStatusText(for text: String) -> String {
        " \(text) "
    }

    private func makeDeviceFeatureRow(feature: DeviceFeatureItem) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let isSupported = feature.value > 0

        // Icon
        let iconBg = UIView()
        iconBg.backgroundColor = (isSupported ? feature.color : .tertiarySystemFill)
        iconBg.layer.cornerRadius = 14
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: feature.icon, withConfiguration: iconConfig))
        iconIV.tintColor = isSupported ? .white : .tertiaryLabel
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconIV)

        // Name + description
        let nameLabel = UILabel()
        nameLabel.text = feature.name
        nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        nameLabel.textColor = isSupported ? .label : .tertiaryLabel
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = UILabel()
        descLabel.text = feature.desc
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .tertiaryLabel
        descLabel.numberOfLines = 2
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        // Status badge
        let statusLabel = UILabel()
        statusLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 4
        statusLabel.clipsToBounds = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        switch feature.value {
        case 0:
            statusLabel.text = paddedFeatureStatusText(for: t(.ringDetailFeatureStatusOff))
            statusLabel.textColor = .tertiaryLabel
            statusLabel.backgroundColor = UIColor.tertiarySystemFill
        case 1:
            statusLabel.text = paddedFeatureStatusText(for: t(.ringDetailFeatureStatusOn))
            statusLabel.textColor = themeColor
            statusLabel.backgroundColor = themeColor.withAlphaComponent(0.1)
        case 2:
            statusLabel.text = paddedFeatureStatusText(for: t(.ringDetailFeatureStatusAlways))
            statusLabel.textColor = themeColor
            statusLabel.backgroundColor = themeColor.withAlphaComponent(0.1)
        case 3:
            statusLabel.text = paddedFeatureStatusText(for: t(.ringDetailFeatureStatusRemote))
            statusLabel.textColor = AppDesign.Color.cyan
            statusLabel.backgroundColor = AppDesign.Color.cyan.withAlphaComponent(0.1)
        default:
            statusLabel.text = paddedFeatureStatusText(for: t(.ringDetailFeatureStatusUnknown))
            statusLabel.textColor = .secondaryLabel
            statusLabel.backgroundColor = UIColor.tertiarySystemFill
        }

        row.addSubview(iconBg)
        row.addSubview(nameLabel)
        row.addSubview(descLabel)
        row.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 52),

            iconBg.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            iconBg.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 28),
            iconBg.heightAnchor.constraint(equalToConstant: 28),

            iconIV.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -8),

            descLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            descLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            descLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -8),

            statusLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            statusLabel.heightAnchor.constraint(equalToConstant: 20),
        ])

        return row
    }
}
