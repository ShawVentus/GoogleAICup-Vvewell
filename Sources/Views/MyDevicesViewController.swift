import UIKit
import Combine

class MyDevicesViewController: UIViewController {

    private let deviceManager = DeviceManager.shared
    private var cancellables = Set<AnyCancellable>()

    private let themeColor = AppDesign.Color.primaryGreen

    // State
    private var deviceStates: [DeviceType: ConnectionState] = [:]
    private var deviceInfos: [DeviceType: DeviceInfo] = [:]
    private var deviceBatteries: [DeviceType: Int] = [:]

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
        title = t(.profileMyDevices)
        view.backgroundColor = .secondarySystemBackground
        setupScrollView()
        observeDevices()
        syncDeviceStates()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
        rebuildContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncDeviceStates()
        rebuildContent()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Synchronously reads current device state so the UI is correct on first render
    /// (Combine subscriptions with .receive(on: .main) deliver asynchronously).
    private func syncDeviceStates() {
        for type in deviceManager.registeredTypes {
            guard let device = deviceManager.device(for: type) else { continue }
            if device.isConnected() {
                deviceStates[type] = .connected
            }
        }
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
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Observe Devices

    private func observeDevices() {
        deviceManager.connectionStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (type, state) in
                self?.deviceStates[type] = state
                self?.rebuildContent()
            }
            .store(in: &cancellables)

        for type in deviceManager.registeredTypes {
            guard let device = deviceManager.device(for: type) else { continue }

            device.connectionState
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.deviceStates[type] = state
                    self?.rebuildContent()
                }
                .store(in: &cancellables)

            device.deviceInfo
                .compactMap { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] info in
                    self?.deviceInfos[type] = info
                    self?.rebuildContent()
                }
                .store(in: &cancellables)

            device.batteryLevel
                .compactMap { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] level in
                    self?.deviceBatteries[type] = level
                    self?.rebuildContent()
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Rebuild Content

    /// Returns device types that are paired (bound) — whether currently connected or not.
    private var pairedDeviceTypes: [DeviceType] {
        deviceManager.registeredTypes.filter { type in
            guard let device = deviceManager.device(for: type) else { return false }
            return device.isPaired()
        }
    }

    private func rebuildContent() {
        title = t(.profileMyDevices)
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let paired = pairedDeviceTypes
        if !paired.isEmpty {
            // Show all paired device cards (connected or not)
            contentStack.addArrangedSubview(makeSectionHeader(t(.profileMyDevices)))
            for type in paired {
                contentStack.addArrangedSubview(makeDeviceCard(for: type))
            }

            // Add Device section
            contentStack.addArrangedSubview(makeSectionHeader(t(.myDevicesAddDevice)))
            contentStack.addArrangedSubview(makeScanButton())
        } else {
            // Onboarding: guide user to add a device
            contentStack.addArrangedSubview(makeOnboardingView())
        }
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

    // MARK: - Onboarding View

    private func makeOnboardingView() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        // Illustration icon
        let iconSize: CGFloat = 80
        let iconCircle = UIView()
        iconCircle.backgroundColor = themeColor.withAlphaComponent(0.1)
        iconCircle.layer.cornerRadius = iconSize / 2
        iconCircle.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: "sensor.tag.radiowaves.forward", withConfiguration: iconConfig))
        iconView.tintColor = themeColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconView)

        NSLayoutConstraint.activate([
            iconCircle.widthAnchor.constraint(equalToConstant: iconSize),
            iconCircle.heightAnchor.constraint(equalToConstant: iconSize),
            iconView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
        ])

        stack.addArrangedSubview(iconCircle)
        stack.setCustomSpacing(20, after: iconCircle)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = t(.myDevicesConnectTitle)
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(8, after: titleLabel)

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = t(.myDevicesConnectSubtitle)
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        stack.addArrangedSubview(subtitleLabel)
        stack.setCustomSpacing(24, after: subtitleLabel)

        // Supported devices
        let devicesRow = makeSupportedDevicesRow()
        stack.addArrangedSubview(devicesRow)
        stack.setCustomSpacing(24, after: devicesRow)

        // Scan button
        let scanBtn = UIButton(type: .system)
        scanBtn.translatesAutoresizingMaskIntoConstraints = false
        scanBtn.backgroundColor = themeColor
        scanBtn.layer.cornerRadius = 24
        scanBtn.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)

        let btnIcon = UIImageView(image: UIImage(systemName: "antenna.radiowaves.left.and.right"))
        btnIcon.tintColor = .white
        btnIcon.contentMode = .scaleAspectFit
        btnIcon.translatesAutoresizingMaskIntoConstraints = false
        btnIcon.isUserInteractionEnabled = false

        let btnLabel = UILabel()
        btnLabel.text = t(.myDevicesScan)
        btnLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        btnLabel.textColor = .white
        btnLabel.translatesAutoresizingMaskIntoConstraints = false
        btnLabel.isUserInteractionEnabled = false

        let btnStack = UIStackView(arrangedSubviews: [btnIcon, btnLabel])
        btnStack.axis = .horizontal
        btnStack.spacing = 8
        btnStack.alignment = .center
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        btnStack.isUserInteractionEnabled = false
        scanBtn.addSubview(btnStack)

        NSLayoutConstraint.activate([
            btnIcon.widthAnchor.constraint(equalToConstant: 20),
            btnIcon.heightAnchor.constraint(equalToConstant: 20),
            btnStack.centerXAnchor.constraint(equalTo: scanBtn.centerXAnchor),
            btnStack.centerYAnchor.constraint(equalTo: scanBtn.centerYAnchor),
            scanBtn.heightAnchor.constraint(equalToConstant: 48),
        ])

        stack.addArrangedSubview(scanBtn)
        stack.setCustomSpacing(16, after: scanBtn)

        // Hint text
        let hintLabel = UILabel()
        hintLabel.text = t(.myDevicesHint)
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = .tertiaryLabel
        hintLabel.textAlignment = .center
        stack.addArrangedSubview(hintLabel)

        // Layout
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -28),

            scanBtn.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            scanBtn.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        return container
    }

    private func makeSupportedDevicesRow() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 20
        stack.alignment = .center
        stack.distribution = .equalCentering
        stack.translatesAutoresizingMaskIntoConstraints = false

        let devices: [(icon: String, name: String, color: UIColor)] = [
            ("circle.circle", t(.myDevicesRing), UIColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1.0)),
            ("applewatch", t(.myDevicesWatch), UIColor(red: 0.3, green: 0.5, blue: 0.85, alpha: 1.0)),
            ("figure.walk", t(.myDevicesBand), UIColor(red: 0.2, green: 0.7, blue: 0.65, alpha: 1.0)),
        ]

        for device in devices {
            let item = UIStackView()
            item.axis = .vertical
            item.alignment = .center
            item.spacing = 6

            let circleSize: CGFloat = 48
            let circle = UIView()
            circle.backgroundColor = device.color.withAlphaComponent(0.1)
            circle.layer.cornerRadius = circleSize / 2
            circle.translatesAutoresizingMaskIntoConstraints = false

            let iconConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            let icon = UIImageView(image: UIImage(systemName: device.icon, withConfiguration: iconConfig))
            icon.tintColor = device.color
            icon.contentMode = .scaleAspectFit
            icon.translatesAutoresizingMaskIntoConstraints = false
            circle.addSubview(icon)

            NSLayoutConstraint.activate([
                circle.widthAnchor.constraint(equalToConstant: circleSize),
                circle.heightAnchor.constraint(equalToConstant: circleSize),
                icon.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            ])

            let label = UILabel()
            label.text = device.name
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = .secondaryLabel

            item.addArrangedSubview(circle)
            item.addArrangedSubview(label)
            stack.addArrangedSubview(item)
        }

        return stack
    }

    // MARK: - Device Card

    private func makeDeviceCard(for type: DeviceType) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        let state = deviceStates[type] ?? .disconnected
        let info = deviceInfos[type]
        let battery = deviceBatteries[type]
        let isConnected = state == .connected || state == .authSuccess

        // Make card tappable to navigate to device detail
        card.tag = deviceDetailTag(for: type)
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(deviceCardTapped(_:))))

        // Device icon
        let iconSize: CGFloat = 48
        let iconBg = UIView()
        iconBg.backgroundColor = deviceIconColor(for: type).withAlphaComponent(0.12)
        iconBg.layer.cornerRadius = iconSize / 2
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconBg)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: deviceIconName(for: type), withConfiguration: iconConfig))
        iconView.tintColor = deviceIconColor(for: type)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        // Device name
        let nameLabel = UILabel()
        nameLabel.text = info?.name.isEmpty == false ? info!.name : deviceDisplayName(for: type)
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(nameLabel)

        // Connection status
        let statusView = makeConnectionStatus(state)
        statusView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statusView)

        // Info rows
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.spacing = 8
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(infoStack)

        if let battery = battery {
            infoStack.addArrangedSubview(makeInfoRow(
                icon: batteryIconName(level: battery),
                iconColor: batteryColor(level: battery),
                label: t(.myDevicesBattery),
                value: "\(battery)%"
            ))
        }

        if let fw = info?.firmwareVersion, !fw.isEmpty {
            infoStack.addArrangedSubview(makeInfoRow(
                icon: "cpu",
                iconColor: .systemBlue,
                label: t(.myDevicesFirmware),
                value: fw
            ))
        }

        if let mac = info?.macAddress, !mac.isEmpty {
            infoStack.addArrangedSubview(makeInfoRow(
                icon: "network",
                iconColor: .systemGray,
                label: t(.myDevicesMac),
                value: mac
            ))
        }

        // Chevron for navigation hint
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(chevron)

        // Action button
        let actionButton = UIButton(type: .system)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.layer.cornerRadius = 20
        actionButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)

        if isConnected {
            actionButton.setTitle(t(.myDevicesDisconnect), for: .normal)
            actionButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            actionButton.setTitleColor(.systemRed, for: .normal)
        } else if state == .connecting {
            actionButton.setTitle(t(.myDevicesConnecting), for: .normal)
            actionButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
            actionButton.setTitleColor(.systemOrange, for: .normal)
            actionButton.isEnabled = false
        } else {
            actionButton.setTitle(t(.myDevicesReconnect), for: .normal)
            actionButton.backgroundColor = themeColor.withAlphaComponent(0.1)
            actionButton.setTitleColor(themeColor, for: .normal)
        }

        actionButton.tag = deviceActionTag(for: type)
        actionButton.addTarget(self, action: #selector(deviceActionTapped(_:)), for: .touchUpInside)
        card.addSubview(actionButton)

        // Layout
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

            nameLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: iconBg.topAnchor, constant: 4),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            statusView.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            statusView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),

            infoStack.topAnchor.constraint(equalTo: iconBg.bottomAnchor, constant: 16),
            infoStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            infoStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            actionButton.topAnchor.constraint(equalTo: infoStack.bottomAnchor, constant: 16),
            actionButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            actionButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            actionButton.heightAnchor.constraint(equalToConstant: 40),
            actionButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return container
    }

    private func makeConnectionStatus(_ state: ConnectionState) -> UIView {
        let container = UIView()

        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.layer.cornerRadius = 4
        container.addSubview(dot)

        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        switch state {
        case .connected, .authSuccess:
            dot.backgroundColor = AppDesign.Color.connectedGreen
            label.text = t(.myDevicesConnected)
            label.textColor = AppDesign.Color.connectedGreen
        case .connecting:
            dot.backgroundColor = .systemOrange
            label.text = t(.myDevicesConnecting)
            label.textColor = .systemOrange
        case .disconnecting:
            dot.backgroundColor = .systemOrange
            label.text = t(.myDevicesDisconnecting)
            label.textColor = .systemOrange
        case .disconnected:
            dot.backgroundColor = .systemGray
            label.text = t(.myDevicesDisconnected)
            label.textColor = .secondaryLabel
        case .authFailed(let reason):
            dot.backgroundColor = .systemRed
            label.text = reason
            label.textColor = .systemRed
        }

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        return container
    }

    private func makeInfoRow(icon: String, iconColor: UIColor, label: String, value: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconView)

        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 13)
        labelView.textColor = .secondaryLabel
        labelView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(labelView)

        let valueView = UILabel()
        valueView.text = value
        valueView.font = .systemFont(ofSize: 13, weight: .medium)
        valueView.textColor = .label
        valueView.textAlignment = .right
        valueView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(valueView)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 24),

            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            labelView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            labelView.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            valueView.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            valueView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueView.leadingAnchor.constraint(greaterThanOrEqualTo: labelView.trailingAnchor, constant: 8),
        ])

        return row
    }

    // MARK: - Scan Button

    private func makeScanButton() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        card.addSubview(button)

        let iconSize: CGFloat = 36
        let iconBgView = UIView()
        iconBgView.backgroundColor = themeColor.withAlphaComponent(0.12)
        iconBgView.layer.cornerRadius = iconSize / 2
        iconBgView.translatesAutoresizingMaskIntoConstraints = false
        iconBgView.isUserInteractionEnabled = false
        button.addSubview(iconBgView)

        let iconView = UIImageView(image: UIImage(systemName: "antenna.radiowaves.left.and.right"))
        iconView.tintColor = themeColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBgView.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = t(.myDevicesScan)
        titleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isUserInteractionEnabled = false
        button.addSubview(titleLabel)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.isUserInteractionEnabled = false
        button.addSubview(chevron)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            button.topAnchor.constraint(equalTo: card.topAnchor),
            button.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 56),

            iconBgView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
            iconBgView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            iconBgView.widthAnchor.constraint(equalToConstant: iconSize),
            iconBgView.heightAnchor.constraint(equalToConstant: iconSize),

            iconView.centerXAnchor.constraint(equalTo: iconBgView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBgView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconBgView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 12),
        ])

        return container
    }

    // MARK: - Helpers

    private func deviceIconName(for type: DeviceType) -> String {
        switch type {
        case .ring: return "circle.circle"
        case .watch: return "applewatch"
        case .band: return "figure.walk"
        case .robot: return "face.smiling"
        case .radar: return "dot.radiowaves.left.and.right"
        case .thermalCamera: return "camera.thermometer"
        }
    }

    private func deviceIconColor(for type: DeviceType) -> UIColor {
        switch type {
        case .ring: return UIColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1.0)
        case .watch: return UIColor(red: 0.3, green: 0.5, blue: 0.85, alpha: 1.0)
        case .band: return UIColor(red: 0.2, green: 0.7, blue: 0.65, alpha: 1.0)
        case .robot: return .systemPurple
        case .radar: return .systemOrange
        case .thermalCamera: return UIColor(red: 0.9, green: 0.45, blue: 0.2, alpha: 1.0)
        }
    }

    private func deviceDisplayName(for type: DeviceType) -> String {
        switch type {
        case .ring: return t(.myDevicesSmartRing)
        case .watch: return t(.myDevicesSmartWatch)
        case .band: return t(.myDevicesSmartBand)
        case .robot: return "vvewell Robot"
        case .radar: return "JDY-23 雷达"
        case .thermalCamera: return t(.myDevicesThermalCamera)
        }
    }

    private func deviceActionTag(for type: DeviceType) -> Int {
        switch type {
        case .ring: return 100
        case .watch: return 101
        case .band: return 102
        case .robot: return 104
        case .radar: return 105
        case .thermalCamera: return 103
        }
    }

    private func deviceDetailTag(for type: DeviceType) -> Int {
        switch type {
        case .ring: return 500
        case .watch: return 501
        case .band: return 502
        case .robot: return 504
        case .radar: return 505
        case .thermalCamera: return 503
        }
    }

    private func deviceType(forDetailTag tag: Int) -> DeviceType? {
        switch tag {
        case 500: return .ring
        case 501: return .watch
        case 502: return .band
        case 504: return .robot
        case 505: return .radar
        case 503: return .thermalCamera
        default: return nil
        }
    }

    private func deviceType(forActionTag tag: Int) -> DeviceType? {
        switch tag {
        case 100: return .ring
        case 101: return .watch
        case 102: return .band
        case 104: return .robot
        case 105: return .radar
        case 103: return .thermalCamera
        default: return nil
        }
    }

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

    @objc private func languageChanged() {
        rebuildContent()
    }

    @objc private func scanTapped() {
        navigationController?.pushViewController(DeviceDiscoveryViewController(), animated: true)
    }

    @objc private func deviceCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag,
              let type = deviceType(forDetailTag: tag) else { return }

        switch type {
        case .ring:
            let ringDetailVC = RingDetailViewController()
            navigationController?.pushViewController(ringDetailVC, animated: true)
        case .thermalCamera:
            // DIRTY_MANUFACTURER_INFRARED_PACKAGE_DISABLED_KEEP_OTHER_FEATURES
            let alert = UIAlertController(
                title: "红外功能不可用",
                message: "UNAVAILABLE: infrared_linkfailed0728 缺少制造商 iOS 包，已按要求跳过。其他设备功能不受影响。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
            present(alert, animated: true)
        case .watch, .band:
            let name = type == .watch ? "智能手表" : "智能手环"
            let alert = UIAlertController(
                title: "\(name)暂不可用",
                message: "当前工程没有随附的制造商 iOS SDK 或公开 BLE 协议，因此不会伪造连接、测量或设备详情。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
            present(alert, animated: true)
        case .robot:
            navigationController?.pushViewController(DeviceFamilyDetailViewController(family: .robot), animated: true)
        case .radar:
            navigationController?.pushViewController(DeviceFamilyDetailViewController(family: .radar), animated: true)
        }
    }

    @objc private func deviceActionTapped(_ sender: UIButton) {
        guard let type = deviceType(forActionTag: sender.tag),
              let device = deviceManager.device(for: type) else { return }

        let state = deviceStates[type] ?? .disconnected
        let isConnected = state == .connected || state == .authSuccess

        if isConnected {
            let alert = UIAlertController(
                title: t(.myDevicesDisconnectTitle),
                message: t(.myDevicesDisconnectMessage),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: t(.myDevicesDisconnect), style: .destructive) { _ in
                device.disconnect()
            })
            present(alert, animated: true)
        } else {
            if let ring = device as? RingDevice {
                ring.setAutoReconnect(true)
            }
        }
    }
}

// MARK: - Android DeviceCenter parity

/// Native counterpart of Android's `DeviceCenterPage`. This catalog owns the
/// entry point for every Android device family; individual BLE transports are
/// registered in DeviceManager only when an iOS SDK or documented protocol is
/// available.
final class DeviceCenterViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let themeColor = AppDesign.Color.primaryGreen
    private var showingHardware = false

    enum Family: String, CaseIterable {
        case alloop, aizoring, xiaozhi, radar, robot, glasses, thermal

        var title: String {
            switch self {
            case .alloop: return "Alloop 智能戒指"
            case .aizoring: return "AIZORING"
            case .xiaozhi: return "健康小助手"
            case .radar: return "JDY-23 毫米波雷达"
            case .robot: return "vvewell Robot"
            case .glasses: return "Rokid AI 智能眼镜"
            case .thermal: return "红外健康检测仪"
            }
        }

        var subtitle: String {
            switch self {
            case .alloop: return "血氧验证、心率、体温趋势与历史同步"
            case .aizoring: return "即时测量、连续 PPI、睡眠、健康历史与 ECG"
            case .xiaozhi: return "BLE 控制、Wi-Fi 配网、语音提醒与 MCP 工具"
            case .radar: return "点云、I/Q 生命体征、距离 bin 与 CSV 导出"
            case .robot: return "表情面板、SG90 舵机角度与断电控制"
            case .glasses: return "配套应用授权、CXRLink 状态与设备信息"
            case .thermal: return "UNAVAILABLE · 0728 manufacturer package incomplete"
            }
        }

        var icon: String {
            switch self {
            case .alloop: return "circle.circle"
            case .aizoring: return "diamond"
            case .xiaozhi, .robot: return "face.smiling"
            case .radar: return "dot.radiowaves.left.and.right"
            case .glasses: return "eyeglasses"
            case .thermal: return "camera.thermometer"
            }
        }

        var color: UIColor {
            switch self {
            case .alloop: return .systemBlue
            case .aizoring: return .systemTeal
            case .xiaozhi, .robot: return .systemPurple
            case .radar: return .systemOrange
            case .glasses: return .systemIndigo
            case .thermal: return .systemGray
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设备中心"
        view.backgroundColor = AppDesign.Surface.canvasBackground
        setupLayout()
        rebuild()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -28),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let intro = UILabel()
        intro.text = "统一管理硬件、数据来源与同步状态。"
        intro.font = .systemFont(ofSize: 14)
        intro.textColor = .secondaryLabel
        intro.numberOfLines = 0
        stack.addArrangedSubview(intro)

        let segment = UISegmentedControl(items: ["我的设备", "支持的硬件"].map(zhEn))
        segment.selectedSegmentIndex = showingHardware ? 1 : 0
        segment.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        stack.addArrangedSubview(segment)

        if showingHardware {
            stack.addArrangedSubview(sectionTitle("硬件入口"))
            Family.allCases.forEach { family in
                stack.addArrangedSubview(makeFamilyCard(family))
            }
        } else {
            let connected = DeviceManager.shared.registeredTypes.filter {
                DeviceManager.shared.device(for: $0)?.isConnected() ?? false
            }
            stack.addArrangedSubview(sectionTitle(connected.isEmpty ? "连接你的健康设备" : "已连接设备 · \(connected.count) 台在线"))
            if connected.isEmpty {
                stack.addArrangedSubview(makeScanCard())
            } else {
                connected.forEach { type in
                    stack.addArrangedSubview(makeRegisteredCard(type: type))
                }
                stack.addArrangedSubview(makeScanCard(title: "继续扫描并添加设备"))
            }
            stack.addArrangedSubview(sectionTitle("支持的设备"))
            Family.allCases.forEach { family in
                stack.addArrangedSubview(makeFamilyCard(family))
            }
        }
    }

    private func sectionTitle(_ title: String) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView()
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
        ])
        return container
    }

    private func makeScanCard(title: String = "开始扫描与连接") -> UIView {
        let button = UIButton(type: .system)
        button.backgroundColor = themeColor
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setImage(UIImage(systemName: "bluetooth.search"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.layer.cornerRadius = 14
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        return button
    }

    private func makeRegisteredCard(type: DeviceType) -> UIView {
        let card = makeFamilyCard(.alloop)
        let label = UILabel()
        label.text = "已连接 · \(type.rawValue)"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = AppDesign.Color.connectedGreen
        card.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
        ])
        return card
    }

    private func makeFamilyCard(_ family: Family) -> UIView {
        let card = UIButton(type: .system)
        card.backgroundColor = family == .thermal ? AppDesign.Surface.secondaryCard : AppDesign.Surface.elevatedCard
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = AppDesign.Surface.border.cgColor
        card.contentHorizontalAlignment = .left
        card.contentEdgeInsets = UIEdgeInsets(top: 13, left: 14, bottom: 13, right: 14)
        card.heightAnchor.constraint(greaterThanOrEqualToConstant: 82).isActive = true
        card.tag = Family.allCases.firstIndex(of: family) ?? 0
        card.addTarget(self, action: #selector(familyTapped(_:)), for: .touchUpInside)

        let icon = UIImageView(image: UIImage(systemName: family.icon))
        icon.tintColor = family.color
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel()
        title.text = family.title
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.textColor = .label
        title.translatesAutoresizingMaskIntoConstraints = false
        let subtitle = UILabel()
        subtitle.text = family.subtitle
        subtitle.font = .systemFont(ofSize: 12, weight: .medium)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 2
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        let chevron = UIImageView(image: UIImage(systemName: family == .thermal ? "nosign" : "chevron.right"))
        chevron.tintColor = family == .thermal ? .systemOrange : .tertiaryLabel
        chevron.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(icon)
        card.addSubview(title)
        card.addSubview(subtitle)
        card.addSubview(chevron)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 34),
            icon.heightAnchor.constraint(equalToConstant: 34),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            title.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            subtitle.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -13),
            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 18),
            chevron.heightAnchor.constraint(equalToConstant: 18),
        ])
        card.accessibilityLabel = family.title
        card.accessibilityValue = family == .thermal ? "不可用：0728 厂商包不完整" : family.subtitle
        return card
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        showingHardware = sender.selectedSegmentIndex == 1
        rebuild()
    }

    @objc private func scanTapped() {
        navigationController?.pushViewController(DeviceDiscoveryViewController(), animated: true)
    }

    @objc private func familyTapped(_ sender: UIButton) {
        guard sender.tag < Family.allCases.count else { return }
        let family = Family.allCases[sender.tag]
        switch family {
        case .alloop:
            navigationController?.pushViewController(RingDetailViewController(), animated: true)
        case .aizoring:
            presentAIZORINGActions(source: sender)
        case .thermal:
            let alert = UIAlertController(title: "红外功能不可用", message: "UNAVAILABLE: infrared_linkfailed0728 缺少制造商 iOS 包，已按要求跳过。其他设备功能不受影响。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
        default:
            navigationController?.pushViewController(DeviceFamilyDetailViewController(family: family), animated: true)
        }
    }

    @objc private func languageChanged() { rebuild() }

    private func presentAIZORINGActions(source: UIView) {
        let sheet = UIAlertController(title: "AIZORING", message: "RingSDK · EiotGluSdk · AB_FOTA", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "设备详情与睡眠", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(RingDetailViewController(), animated: true)
        })
        sheet.addAction(UIAlertAction(title: "即时健康检测与历史", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(RingCheckViewController(), animated: true)
        })
#if !targetEnvironment(simulator)
        sheet.addAction(UIAlertAction(title: "ECG 实时波形", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(ECGCheckViewController(), animated: true)
        })
#endif
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        sheet.popoverPresentationController?.sourceView = source
        sheet.popoverPresentationController?.sourceRect = source.bounds
        present(sheet, animated: true)
    }
}

final class DeviceFamilyDetailViewController: UIViewController {
    private let family: DeviceCenterViewController.Family
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var cancellables = Set<AnyCancellable>()
    private var connectionState: ConnectionState = .disconnected
    private var latestResponse = "尚未收到设备响应。"
    private var servoAngle = 90
    private var selectedExpression = "off"
    private var radarRunning = false
    private var radarPointFrames = 0
    private var radarVitalSamples = 0
    private var radarVitalSummary = "I/Q bin -- · 帧号 --"
    private var radarPhaseEnabled = true
    private var radarPointCloudEnabled = true
    private var radarManualBin = false
    private var radarSelectedBin = 25

    private var deviceType: DeviceType? {
        switch family {
        case .robot: return .robot
        case .radar: return .radar
        default: return nil
        }
    }

    private var genericDevice: GenericBluetoothDevice? {
        guard let deviceType else { return nil }
        return DeviceManager.shared.device(for: deviceType) as? GenericBluetoothDevice
    }

    init(family: DeviceCenterViewController.Family) {
        self.family = family
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = family.title
        view.backgroundColor = AppDesign.Surface.canvasBackground
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 20), stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20), stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -28), stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40),
        ])
        observeTransport()
        NotificationCenter.default.addObserver(self, selector: #selector(payloadReceived(_:)), name: .genericBluetoothPayloadReceived, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(radarFrameReceived(_:)), name: .radarHIFFrameReceived, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(transportError(_:)), name: .genericBluetoothTransportError, object: nil)
        rebuild()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func observeTransport() {
        guard let device = genericDevice else { return }
        connectionState = device.isConnected() ? .connected : .disconnected
        device.connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
                self?.rebuild()
            }
            .store(in: &cancellables)
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(makeConnectionCard())
        switch family {
        case .robot where isConnected:
            stack.addArrangedSubview(makeRobotExpressionCard())
            stack.addArrangedSubview(makeRobotServoCard())
            stack.addArrangedSubview(makeResponseCard(title: "设备响应"))
        case .radar where isConnected:
            stack.addArrangedSubview(makeRadarRunCard())
            stack.addArrangedSubview(makeRadarDataCard())
            stack.addArrangedSubview(makeRadarConfigCard())
            stack.addArrangedSubview(makeResponseCard(title: "HIF 响应"))
        case .xiaozhi:
            stack.addArrangedSubview(makeUnavailableCard(
                title: "iOS 制造商 SDK 未提供",
                message: "Android 使用 AndroidXiaoZhiBleClient。仓库中没有对应 iOS framework / xcframework，因此 BLE、Wi-Fi 配网、提醒和 MCP 控制保持禁用。"
            ))
        case .glasses:
            stack.addArrangedSubview(makeUnavailableCard(
                title: "iOS CXRLink SDK 未提供",
                message: "Android 的 Rokid 配套授权与 CXRLink API 没有随仓库提供 iOS 包。入口保留用于平台对照，不显示伪造连接状态。"
            ))
        default:
            break
        }
    }

    private var isConnected: Bool {
        connectionState == .connected || connectionState == .authSuccess
    }

    private func makeConnectionCard() -> UIView {
        let body = UIStackView()
        body.axis = .vertical
        body.spacing = 10
        let heading = UIStackView()
        heading.axis = .horizontal
        heading.alignment = .center
        heading.spacing = 12
        let symbol = UIImageView(image: UIImage(systemName: family.icon))
        symbol.tintColor = family.color
        symbol.contentMode = .scaleAspectFit
        symbol.widthAnchor.constraint(equalToConstant: 48).isActive = true
        symbol.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let labels = UIStackView()
        labels.axis = .vertical
        labels.spacing = 3
        labels.addArrangedSubview(label(family.title, size: 18, weight: .bold))
        let statusText: String
        switch connectionState {
        case .connected, .authSuccess: statusText = "已连接"
        case .connecting: statusText = "连接中"
        case .disconnecting: statusText = "断开中"
        case .authFailed(let reason): statusText = reason
        case .disconnected: statusText = deviceType == nil ? "平台 SDK 不可用" : "未连接"
        }
        labels.addArrangedSubview(label(statusText, size: 13, color: isConnected ? AppDesign.Color.connectedGreen : .secondaryLabel, weight: .semibold))
        heading.addArrangedSubview(symbol)
        heading.addArrangedSubview(labels)
        body.addArrangedSubview(heading)
        body.addArrangedSubview(label(family.subtitle, size: 13, color: .secondaryLabel))
        if let deviceType {
            let action = commandButton(title: isConnected ? "断开连接" : "扫描并连接", icon: isConnected ? "bluetooth.slash" : "bluetooth.search", filled: !isConnected)
            action.tag = deviceType == .robot ? 700 : 701
            action.addTarget(self, action: #selector(connectionTapped(_:)), for: .touchUpInside)
            body.addArrangedSubview(action)
        }
        return card(body, tint: family.color.withAlphaComponent(0.09))
    }

    private func makeRobotExpressionCard() -> UIView {
        let body = UIStackView()
        body.axis = .vertical
        body.spacing = 10
        body.addArrangedSubview(label("表情控制", size: 17, weight: .bold))
        body.addArrangedSubview(label("选择显示表情；关闭表情会让面板熄灭。", size: 13, color: .secondaryLabel))
        let expressions = [
            ("blue_upper", "蓝色 · 上弦"), ("blue_middle", "蓝色 · 平视"),
            ("blue_lower", "蓝色 · 低头"), ("yellow_upper", "黄色 · 上弦"),
            ("yellow_middle", "黄色 · 平视"), ("yellow_lower", "黄色 · 低头"),
        ]
        for rowStart in stride(from: 0, to: expressions.count, by: 2) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 8
            for index in rowStart..<min(rowStart + 2, expressions.count) {
                let item = expressions[index]
                let button = commandButton(title: item.1, icon: "face.smiling", filled: selectedExpression == item.0)
                button.tag = 710 + index
                button.addTarget(self, action: #selector(expressionTapped(_:)), for: .touchUpInside)
                row.addArrangedSubview(button)
            }
            body.addArrangedSubview(row)
        }
        let off = commandButton(title: "关闭表情", icon: "eye.slash", filled: selectedExpression == "off")
        off.tag = 716
        off.addTarget(self, action: #selector(expressionTapped(_:)), for: .touchUpInside)
        body.addArrangedSubview(off)
        return card(body, tint: UIColor.systemBlue.withAlphaComponent(0.08))
    }

    private func makeRobotServoCard() -> UIView {
        let body = UIStackView()
        body.axis = .vertical
        body.spacing = 9
        body.addArrangedSubview(label("SG90 舵机角度", size: 17, weight: .bold))
        body.addArrangedSubview(label("\(servoAngle)°", size: 30, color: AppDesign.Color.primaryGreen, weight: .bold))
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 180
        slider.value = Float(servoAngle)
        slider.addTarget(self, action: #selector(servoChanged(_:)), for: .valueChanged)
        body.addArrangedSubview(slider)
        let actions = UIStackView()
        actions.axis = .horizontal
        actions.distribution = .fillEqually
        actions.spacing = 8
        let set = commandButton(title: "设置角度", icon: "rotate.right", filled: true)
        set.addTarget(self, action: #selector(setServoTapped), for: .touchUpInside)
        let off = commandButton(title: "舵机断电", icon: "power", filled: false)
        off.addTarget(self, action: #selector(servoOffTapped), for: .touchUpInside)
        actions.addArrangedSubview(set)
        actions.addArrangedSubview(off)
        body.addArrangedSubview(actions)
        return card(body, tint: UIColor.systemOrange.withAlphaComponent(0.09))
    }

    private func makeRadarRunCard() -> UIView {
        let body = UIStackView()
        body.axis = .vertical
        body.spacing = 10
        body.addArrangedSubview(label("采集控制", size: 17, weight: .bold))
        body.addArrangedSubview(label(radarRunning ? "正在接收点云与生命体征工程数据。" : "连接后请显式启动雷达采集。", size: 13, color: .secondaryLabel))
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 7
        [("唤醒", "sunrise", 720), ("启动雷达", "play.fill", 721), ("停止雷达", "stop.fill", 722)].forEach { title, icon, tag in
            let button = commandButton(title: title, icon: icon, filled: tag == 721)
            button.tag = tag
            button.isEnabled = tag == 720 || (tag == 721 ? !radarRunning : radarRunning)
            button.addTarget(self, action: #selector(radarActionTapped(_:)), for: .touchUpInside)
            row.addArrangedSubview(button)
        }
        body.addArrangedSubview(row)
        return card(body)
    }

    private func makeRadarDataCard() -> UIView {
        let body = UIStackView()
        body.axis = .vertical
        body.spacing = 8
        body.addArrangedSubview(label("实时工程数据", size: 17, weight: .bold))
        body.addArrangedSubview(label("点云帧 \(radarPointFrames) · VitalSample \(radarVitalSamples)", size: 15, weight: .semibold))
        body.addArrangedSubview(label(radarVitalSummary, size: 13, color: .secondaryLabel))
        body.addArrangedSubview(label("仅用于交互、研究与工程验证，不可用于诊断或监护。", size: 12, color: .systemRed, weight: .semibold))
        return card(body, tint: UIColor.systemBlue.withAlphaComponent(0.08))
    }

    private func makeRadarConfigCard() -> UIView {
        let body = UIStackView()
        body.axis = .vertical
        body.spacing = 8
        body.addArrangedSubview(label("VitalBridge 输出配置", size: 17, weight: .bold))
        body.addArrangedSubview(toggleRow(title: "I/Q 生命体征数据", isOn: radarPhaseEnabled, tag: 730))
        body.addArrangedSubview(toggleRow(title: "点云数据", isOn: radarPointCloudEnabled, tag: 731))
        body.addArrangedSubview(toggleRow(title: "手动选择距离 bin", isOn: radarManualBin, tag: 732))
        if radarManualBin {
            body.addArrangedSubview(label("距离 bin · \(radarSelectedBin)", size: 13, color: .secondaryLabel))
            let slider = UISlider()
            slider.minimumValue = 0
            slider.maximumValue = 200
            slider.value = Float(radarSelectedBin)
            slider.addTarget(self, action: #selector(radarBinChanged(_:)), for: .valueChanged)
            body.addArrangedSubview(slider)
        }
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 8
        let apply = commandButton(title: "应用配置", icon: "checkmark", filled: true)
        apply.tag = 733
        apply.addTarget(self, action: #selector(radarActionTapped(_:)), for: .touchUpInside)
        let auto = commandButton(title: "自动 bin", icon: "scope", filled: false)
        auto.tag = 734
        auto.addTarget(self, action: #selector(radarActionTapped(_:)), for: .touchUpInside)
        row.addArrangedSubview(apply)
        row.addArrangedSubview(auto)
        body.addArrangedSubview(row)
        return card(body)
    }

    private func makeResponseCard(title: String) -> UIView {
        let body = UIStackView()
        body.axis = .vertical
        body.spacing = 8
        body.addArrangedSubview(label(title, size: 17, weight: .bold))
        let response = label(latestResponse, size: 12, color: .secondaryLabel)
        response.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        body.addArrangedSubview(response)
        if family == .robot {
            let refresh = commandButton(title: "读取状态", icon: "arrow.clockwise", filled: false)
            refresh.addTarget(self, action: #selector(robotStatusTapped), for: .touchUpInside)
            body.addArrangedSubview(refresh)
        }
        return card(body)
    }

    private func makeUnavailableCard(title: String, message: String) -> UIView {
        let body = UIStackView()
        body.axis = .vertical
        body.spacing = 8
        body.addArrangedSubview(label(title, size: 17, color: .systemOrange, weight: .bold))
        body.addArrangedSubview(label(message, size: 14, color: .secondaryLabel))
        return card(body, tint: UIColor.systemOrange.withAlphaComponent(0.08))
    }

    private func card(_ body: UIStackView, tint: UIColor = AppDesign.Surface.elevatedCard) -> UIView {
        let surface = UIView()
        surface.backgroundColor = tint
        surface.layer.cornerRadius = 14
        surface.layer.borderWidth = 1
        surface.layer.borderColor = AppDesign.Surface.border.cgColor
        body.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(body)
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: surface.topAnchor, constant: 16),
            body.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 16),
            body.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -16),
            body.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -16),
        ])
        return surface
    }

    private func label(_ text: String, size: CGFloat, color: UIColor = .label, weight: UIFont.Weight = .regular) -> UILabel {
        let result = UILabel()
        result.text = text
        result.font = .systemFont(ofSize: size, weight: weight)
        result.textColor = color
        result.numberOfLines = 0
        return result
    }

    private func commandButton(title: String, icon: String, filled: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("  \(title)", for: .normal)
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.layer.cornerRadius = 10
        button.heightAnchor.constraint(equalToConstant: 42).isActive = true
        button.backgroundColor = filled ? AppDesign.Color.primaryGreen : .secondarySystemBackground
        button.tintColor = filled ? .white : AppDesign.Color.primaryGreen
        button.setTitleColor(filled ? .white : AppDesign.Color.primaryGreen, for: .normal)
        return button
    }

    private func toggleRow(title: String, isOn: Bool, tag: Int) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.addArrangedSubview(label(title, size: 14))
        let control = UISwitch()
        control.isOn = isOn
        control.tag = tag
        control.addTarget(self, action: #selector(radarToggleChanged(_:)), for: .valueChanged)
        row.addArrangedSubview(control)
        return row
    }

    @objc private func connectionTapped(_ sender: UIButton) {
        if isConnected {
            genericDevice?.disconnect()
        } else {
            navigationController?.pushViewController(DeviceDiscoveryViewController(), animated: true)
        }
    }

    @objc private func expressionTapped(_ sender: UIButton) {
        let ids = ["blue_upper", "blue_middle", "blue_lower", "yellow_upper", "yellow_middle", "yellow_lower", "off"]
        guard ids.indices.contains(sender.tag - 710) else { return }
        selectedExpression = ids[sender.tag - 710]
        genericDevice?.sendCommand("expression", values: ["name": selectedExpression])
        rebuild()
    }

    @objc private func servoChanged(_ sender: UISlider) {
        servoAngle = Int(sender.value.rounded())
        rebuild()
    }

    @objc private func setServoTapped() { genericDevice?.sendCommand("servo", values: ["angle": servoAngle]) }
    @objc private func servoOffTapped() { genericDevice?.sendCommand("servo_off") }
    @objc private func robotStatusTapped() { genericDevice?.sendCommand("status") }

    @objc private func radarActionTapped(_ sender: UIButton) {
        switch sender.tag {
        case 720: genericDevice?.radarWakeup()
        case 721:
            radarPointFrames = 0
            radarVitalSamples = 0
            radarRunning = true
            genericDevice?.radarStart()
        case 722:
            radarRunning = false
            genericDevice?.radarStop()
        case 733:
            let flags: UInt8 = (radarPhaseEnabled ? 1 : 0) | (radarPointCloudEnabled ? 2 : 0)
            genericDevice?.radarConfigureVital(outputFlags: flags, manualBin: radarManualBin, selectedBin: UInt16(radarSelectedBin), minBin: 10, maxBin: 100)
        case 734:
            radarManualBin = false
            genericDevice?.radarSelectAutomaticBin()
        default: break
        }
        rebuild()
    }

    @objc private func radarToggleChanged(_ sender: UISwitch) {
        switch sender.tag {
        case 730: radarPhaseEnabled = sender.isOn
        case 731: radarPointCloudEnabled = sender.isOn
        case 732: radarManualBin = sender.isOn
        default: break
        }
        rebuild()
    }

    @objc private func radarBinChanged(_ sender: UISlider) {
        radarSelectedBin = Int(sender.value.rounded())
        rebuild()
    }

    @objc private func payloadReceived(_ note: Notification) {
        guard family == .robot, note.object as AnyObject? === genericDevice, let data = note.userInfo?["data"] as? Data else { return }
        latestResponse = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? data.map { String(format: "%02X", $0) }.joined(separator: " ")
        rebuild()
    }

    @objc private func radarFrameReceived(_ note: Notification) {
        guard family == .radar, note.object as AnyObject? === genericDevice,
              let messageID = note.userInfo?["messageID"] as? Int,
              let payload = note.userInfo?["payload"] as? Data else { return }
        switch messageID {
        case 0xc3:
            radarPointFrames += 1
        case 0xe0 where payload.count == 20:
            radarVitalSamples += 1
            let rangeBin = uint16LE(payload, 2)
            let frame = uint32LE(payload, 4)
            let iValue = Int16(bitPattern: uint16LE(payload, 8))
            let qValue = Int16(bitPattern: uint16LE(payload, 10))
            let resolution = uint16LE(payload, 16)
            radarVitalSummary = "I/Q bin \(rangeBin) · I \(iValue) · Q \(qValue) · 分辨率 \(resolution) mm · 帧号 \(frame)"
        default:
            let status = payload.first.map(String.init) ?? "--"
            latestResponse = "HIF 0x\(String(messageID, radix: 16, uppercase: true)) · status \(status)"
        }
        rebuild()
    }

    @objc private func transportError(_ note: Notification) {
        guard note.object as AnyObject? === genericDevice else { return }
        latestResponse = note.userInfo?["message"] as? String ?? "BLE transport error"
        rebuild()
    }

    private func uint16LE(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func uint32LE(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8) | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
    }
}
