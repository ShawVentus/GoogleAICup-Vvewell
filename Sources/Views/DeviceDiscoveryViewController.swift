import UIKit
import Combine

class DeviceDiscoveryViewController: UIViewController {

    private let deviceManager = DeviceManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var scanCancellable: AnyCancellable?

    private let themeColor = AppDesign.Color.primaryGreen

    private var discoveredDevices: [DiscoveredDevice] = []

    // Radar
    private let radarContainer = UIView()
    private let radarSize: CGFloat = 280
    private var sweepLayer: CAGradientLayer?
    private var pulseTimer: Timer?
    private var deviceDotViews: [UIView] = []

    // Bottom UI
    private let statusLabel = UILabel()
    private let deviceListStack = UIStackView()
    private let stopButtonLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = t(.deviceDiscoveryTitle)
        view.backgroundColor = .secondarySystemBackground
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startRadarAnimation()
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
        stopRadarAnimation()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup UI

    private func setupUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // Radar
        setupRadar()
        contentStack.addArrangedSubview(radarContainer)

        // Status label
        statusLabel.text = t(.deviceDiscoverySearching)
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        contentStack.addArrangedSubview(statusLabel)

        // Device list
        deviceListStack.axis = .vertical
        deviceListStack.spacing = 0
        deviceListStack.translatesAutoresizingMaskIntoConstraints = false

        let listContainer = UIView()
        listContainer.translatesAutoresizingMaskIntoConstraints = false
        listContainer.addSubview(deviceListStack)

        NSLayoutConstraint.activate([
            deviceListStack.topAnchor.constraint(equalTo: listContainer.topAnchor),
            deviceListStack.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor, constant: 20),
            deviceListStack.trailingAnchor.constraint(equalTo: listContainer.trailingAnchor, constant: -20),
            deviceListStack.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor),
        ])

        contentStack.addArrangedSubview(listContainer)

        listContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        // Stop button
        let stopButton = UIButton(type: .system)
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.backgroundColor = UIColor.tertiarySystemFill
        stopButton.layer.cornerRadius = 24
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)

        let stopIcon = UIImageView(image: UIImage(systemName: "xmark"))
        stopIcon.tintColor = .secondaryLabel
        stopIcon.contentMode = .scaleAspectFit
        stopIcon.translatesAutoresizingMaskIntoConstraints = false
        stopIcon.isUserInteractionEnabled = false

        stopButtonLabel.text = t(.deviceDiscoveryStop)
        stopButtonLabel.font = .systemFont(ofSize: 16, weight: .medium)
        stopButtonLabel.textColor = .secondaryLabel
        stopButtonLabel.translatesAutoresizingMaskIntoConstraints = false
        stopButtonLabel.isUserInteractionEnabled = false

        let stopStack = UIStackView(arrangedSubviews: [stopIcon, stopButtonLabel])
        stopStack.axis = .horizontal
        stopStack.spacing = 8
        stopStack.alignment = .center
        stopStack.translatesAutoresizingMaskIntoConstraints = false
        stopStack.isUserInteractionEnabled = false
        stopButton.addSubview(stopStack)

        NSLayoutConstraint.activate([
            stopIcon.widthAnchor.constraint(equalToConstant: 16),
            stopIcon.heightAnchor.constraint(equalToConstant: 16),
            stopStack.centerXAnchor.constraint(equalTo: stopButton.centerXAnchor),
            stopStack.centerYAnchor.constraint(equalTo: stopButton.centerYAnchor),
            stopButton.heightAnchor.constraint(equalToConstant: 48),
        ])

        contentStack.addArrangedSubview(stopButton)

        stopButton.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -80).isActive = true
    }

    // MARK: - Radar Setup

    private func setupRadar() {
        radarContainer.translatesAutoresizingMaskIntoConstraints = false
        radarContainer.clipsToBounds = false

        NSLayoutConstraint.activate([
            radarContainer.widthAnchor.constraint(equalToConstant: radarSize),
            radarContainer.heightAnchor.constraint(equalToConstant: radarSize),
        ])

        let center = CGPoint(x: radarSize / 2, y: radarSize / 2)

        // Concentric rings
        let ringRadii: [CGFloat] = [radarSize * 0.18, radarSize * 0.33, radarSize * 0.48]
        for radius in ringRadii {
            let ring = CAShapeLayer()
            ring.path = UIBezierPath(arcCenter: center, radius: radius,
                                     startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath
            ring.fillColor = UIColor.clear.cgColor
            ring.strokeColor = themeColor.withAlphaComponent(0.12).cgColor
            ring.lineWidth = 1
            ring.lineDashPattern = [4, 4]
            radarContainer.layer.addSublayer(ring)
        }

        // Cross lines
        let cross = CAShapeLayer()
        let crossPath = UIBezierPath()
        let half = radarSize / 2
        crossPath.move(to: CGPoint(x: half, y: half - radarSize * 0.48))
        crossPath.addLine(to: CGPoint(x: half, y: half + radarSize * 0.48))
        crossPath.move(to: CGPoint(x: half - radarSize * 0.48, y: half))
        crossPath.addLine(to: CGPoint(x: half + radarSize * 0.48, y: half))
        cross.path = crossPath.cgPath
        cross.strokeColor = themeColor.withAlphaComponent(0.07).cgColor
        cross.lineWidth = 0.5
        radarContainer.layer.addSublayer(cross)

        // Center icon
        let centerSize: CGFloat = 56
        let centerCircle = UIView()
        centerCircle.backgroundColor = themeColor.withAlphaComponent(0.15)
        centerCircle.layer.cornerRadius = centerSize / 2
        centerCircle.translatesAutoresizingMaskIntoConstraints = false
        radarContainer.addSubview(centerCircle)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let centerIcon = UIImageView(image: UIImage(systemName: "antenna.radiowaves.left.and.right", withConfiguration: iconConfig))
        centerIcon.tintColor = themeColor
        centerIcon.contentMode = .scaleAspectFit
        centerIcon.translatesAutoresizingMaskIntoConstraints = false
        centerCircle.addSubview(centerIcon)

        NSLayoutConstraint.activate([
            centerCircle.centerXAnchor.constraint(equalTo: radarContainer.centerXAnchor),
            centerCircle.centerYAnchor.constraint(equalTo: radarContainer.centerYAnchor),
            centerCircle.widthAnchor.constraint(equalToConstant: centerSize),
            centerCircle.heightAnchor.constraint(equalToConstant: centerSize),
            centerIcon.centerXAnchor.constraint(equalTo: centerCircle.centerXAnchor),
            centerIcon.centerYAnchor.constraint(equalTo: centerCircle.centerYAnchor),
        ])
    }

    // MARK: - Radar Animation

    private func startRadarAnimation() {
        // Sweep gradient
        let sweep = CAGradientLayer()
        sweep.type = .conic
        sweep.colors = [
            themeColor.withAlphaComponent(0.3).cgColor,
            themeColor.withAlphaComponent(0.0).cgColor,
            UIColor.clear.cgColor,
        ]
        sweep.locations = [0.0, 0.18, 1.0]
        sweep.startPoint = CGPoint(x: 0.5, y: 0.5)
        sweep.endPoint = CGPoint(x: 0.5, y: 0.0)
        sweep.frame = CGRect(x: 0, y: 0, width: radarSize, height: radarSize)

        let center = CGPoint(x: radarSize / 2, y: radarSize / 2)
        let circleMask = CAShapeLayer()
        circleMask.path = UIBezierPath(arcCenter: center, radius: radarSize * 0.48,
                                        startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath
        sweep.mask = circleMask

        radarContainer.layer.insertSublayer(sweep, at: 0)
        sweepLayer = sweep

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * Double.pi
        rotation.duration = 3.0
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        sweep.add(rotation, forKey: "sweep")

        // Pulse ripples
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.addPulse()
        }
        addPulse()
    }

    private func stopRadarAnimation() {
        sweepLayer?.removeAllAnimations()
        sweepLayer?.removeFromSuperlayer()
        sweepLayer = nil
        pulseTimer?.invalidate()
        pulseTimer = nil
    }

    private func addPulse() {
        let center = CGPoint(x: radarSize / 2, y: radarSize / 2)
        let pulse = CAShapeLayer()
        pulse.path = UIBezierPath(arcCenter: center, radius: 28,
                                   startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath
        pulse.fillColor = UIColor.clear.cgColor
        pulse.strokeColor = themeColor.withAlphaComponent(0.35).cgColor
        pulse.lineWidth = 1.5
        radarContainer.layer.insertSublayer(pulse, at: 0)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = radarSize * 0.48 / 28.0

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.35
        fade.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 2.5
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards

        CATransaction.begin()
        CATransaction.setCompletionBlock { pulse.removeFromSuperlayer() }
        pulse.add(group, forKey: "pulse")
        CATransaction.commit()
    }

    // MARK: - Device Dots on Radar

    private func updateDeviceDots() {
        deviceDotViews.forEach { $0.removeFromSuperview() }
        deviceDotViews.removeAll()

        let center = CGPoint(x: radarSize / 2, y: radarSize / 2)

        for (index, device) in discoveredDevices.enumerated() {
            let angle = -.pi / 2 + (2 * .pi * CGFloat(index)) / CGFloat(max(discoveredDevices.count, 1))
            let dist = rssiToDistance(device.rssi)

            let x = center.x + cos(angle) * dist
            let y = center.y + sin(angle) * dist

            let dotSize: CGFloat = 40
            let dot = UIView()
            dot.backgroundColor = deviceColor(for: device.deviceType).withAlphaComponent(0.15)
            dot.layer.cornerRadius = dotSize / 2
            dot.layer.borderWidth = 2
            dot.layer.borderColor = deviceColor(for: device.deviceType).cgColor
            dot.translatesAutoresizingMaskIntoConstraints = false
            radarContainer.addSubview(dot)

            let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            let icon = UIImageView(image: UIImage(systemName: deviceIcon(for: device.deviceType), withConfiguration: iconConfig))
            icon.tintColor = deviceColor(for: device.deviceType)
            icon.contentMode = .scaleAspectFit
            icon.translatesAutoresizingMaskIntoConstraints = false
            dot.addSubview(icon)

            // Glow
            dot.layer.shadowColor = deviceColor(for: device.deviceType).cgColor
            dot.layer.shadowRadius = 8
            dot.layer.shadowOpacity = 0.5
            dot.layer.shadowOffset = .zero

            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: dotSize),
                dot.heightAnchor.constraint(equalToConstant: dotSize),
                dot.centerXAnchor.constraint(equalTo: radarContainer.leadingAnchor, constant: x),
                dot.centerYAnchor.constraint(equalTo: radarContainer.topAnchor, constant: y),
                icon.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: dot.centerYAnchor),
            ])

            deviceDotViews.append(dot)

            // Appear animation
            dot.transform = CGAffineTransform(scaleX: 0, y: 0)
            dot.alpha = 0
            UIView.animate(
                withDuration: 0.5,
                delay: Double(index) * 0.08,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0,
                options: [],
                animations: {
                    dot.transform = .identity
                    dot.alpha = 1
                }
            )
        }
    }

    private func rssiToDistance(_ rssi: Int) -> CGFloat {
        let clamped = max(min(rssi, -30), -100)
        let normalized = CGFloat(clamped + 30) / -70.0
        let minR = radarSize * 0.25
        let maxR = radarSize * 0.42
        return minR + normalized * (maxR - minR)
    }

    // MARK: - Scanning

    private func startScanning() {
        discoveredDevices = []

        scanCancellable = deviceManager.scanAll()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.discoveredDevices = devices
                self?.onDevicesUpdated()
            }
    }

    private func stopScanning() {
        scanCancellable?.cancel()
        scanCancellable = nil
        deviceManager.stopAllScans()
    }

    private func onDevicesUpdated() {
        updateDeviceDots()
        updateDeviceList()
        statusLabel.text = localizedDiscoveryStatusText(for: discoveredDevices.count)
    }

    private func localizedDiscoveryStatusText(for count: Int) -> String {
        guard count > 0 else {
            return t(.deviceDiscoverySearching)
        }
        let key: L10nKey = count == 1 ? .deviceDiscoveryFoundSingular : .deviceDiscoveryFoundPlural
        return String(format: t(key), count)
    }

    // MARK: - Device List

    private func updateDeviceList() {
        deviceListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !discoveredDevices.isEmpty else { return }

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        for (index, device) in discoveredDevices.enumerated() {
            stack.addArrangedSubview(makeDeviceRow(device, index: index))
            if index < discoveredDevices.count - 1 {
                stack.addArrangedSubview(makeSeparator())
            }
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        deviceListStack.addArrangedSubview(card)
    }

    private func makeDeviceRow(_ device: DiscoveredDevice, index: Int) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconSize: CGFloat = 36
        let color = deviceColor(for: device.deviceType)

        let iconBg = UIView()
        iconBg.backgroundColor = color.withAlphaComponent(0.12)
        iconBg.layer.cornerRadius = iconSize / 2
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconBg)

        let iconView = UIImageView(image: UIImage(systemName: deviceIcon(for: device.deviceType)))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        let nameLabel = UILabel()
        nameLabel.text = device.name.isEmpty ? t(.deviceDiscoveryUnknown) : device.name
        nameLabel.font = .systemFont(ofSize: 15, weight: .medium)
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(nameLabel)

        // Signal strength
        let signalStack = UIStackView()
        signalStack.axis = .horizontal
        signalStack.spacing = 4
        signalStack.alignment = .center
        signalStack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(signalStack)

        let signalBars = makeSignalBars(for: device.rssi)
        signalBars.translatesAutoresizingMaskIntoConstraints = false

        let rssiLabel = UILabel()
        rssiLabel.text = "\(device.rssi) dBm"
        rssiLabel.font = .systemFont(ofSize: 12)
        rssiLabel.textColor = .tertiaryLabel

        signalStack.addArrangedSubview(signalBars)
        signalStack.addArrangedSubview(rssiLabel)

        // Connect button
        let connectButton = UIButton(type: .system)
        connectButton.setTitle(t(.deviceDiscoveryConnect), for: .normal)
        connectButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.backgroundColor = themeColor
        connectButton.layer.cornerRadius = 14
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        connectButton.tag = index
        connectButton.addTarget(self, action: #selector(connectTapped(_:)), for: .touchUpInside)
        row.addSubview(connectButton)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 64),

            iconBg.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconBg.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: iconSize),
            iconBg.heightAnchor.constraint(equalToConstant: iconSize),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            nameLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 14),

            signalStack.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            signalStack.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),

            connectButton.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            connectButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            connectButton.widthAnchor.constraint(equalToConstant: 80),
            connectButton.heightAnchor.constraint(equalToConstant: 28),
        ])

        return row
    }

    private func makeSignalBars(for rssi: Int) -> UIView {
        let container = UIView()
        let barCount = 4
        let barWidth: CGFloat = 3
        let barSpacing: CGFloat = 2
        let maxBarHeight: CGFloat = 14

        // -30 = excellent, -60 = good, -80 = fair, -100 = weak
        let strength: Int
        if rssi > -50 { strength = 4 }
        else if rssi > -65 { strength = 3 }
        else if rssi > -80 { strength = 2 }
        else { strength = 1 }

        var lastTrailing: NSLayoutXAxisAnchor = container.leadingAnchor

        for i in 0..<barCount {
            let bar = UIView()
            let height = maxBarHeight * CGFloat(i + 1) / CGFloat(barCount)
            bar.backgroundColor = i < strength ? themeColor : UIColor.tertiarySystemFill
            bar.layer.cornerRadius = barWidth / 2
            bar.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(bar)

            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: lastTrailing, constant: i == 0 ? 0 : barSpacing),
                bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                bar.widthAnchor.constraint(equalToConstant: barWidth),
                bar.heightAnchor.constraint(equalToConstant: height),
            ])
            lastTrailing = bar.trailingAnchor
        }

        NSLayoutConstraint.activate([
            container.trailingAnchor.constraint(equalTo: lastTrailing),
            container.heightAnchor.constraint(equalToConstant: maxBarHeight),
            container.widthAnchor.constraint(equalToConstant: CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing),
        ])

        return container
    }

    private func makeSeparator() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let line = UIView()
        line.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 0.5),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 64),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - Helpers

    private func deviceIcon(for type: DeviceType) -> String {
        switch type {
        case .ring: return "circle.circle"
        case .watch: return "applewatch"
        case .band: return "figure.walk"
        case .robot: return "face.smiling"
        case .radar: return "dot.radiowaves.left.and.right"
        case .thermalCamera: return "camera.thermometer"
        }
    }

    private func deviceColor(for type: DeviceType) -> UIColor {
        switch type {
        case .ring: return UIColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1.0)
        case .watch: return UIColor(red: 0.3, green: 0.5, blue: 0.85, alpha: 1.0)
        case .band: return UIColor(red: 0.2, green: 0.7, blue: 0.65, alpha: 1.0)
        case .robot: return .systemPurple
        case .radar: return .systemOrange
        case .thermalCamera: return UIColor(red: 0.9, green: 0.45, blue: 0.2, alpha: 1.0)
        }
    }

    // MARK: - Actions

    @objc private func languageChanged() {
        title = t(.deviceDiscoveryTitle)
        stopButtonLabel.text = t(.deviceDiscoveryStop)
        onDevicesUpdated()
    }

    @objc private func stopTapped() {
        stopScanning()
        navigationController?.popViewController(animated: true)
    }

    @objc private func connectTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < discoveredDevices.count else { return }
        let device = discoveredDevices[index]

        stopScanning()
        stopRadarAnimation()

        if let ringDevice = deviceManager.device(for: device.deviceType) {
            ringDevice.connect(device: device)
        }

        if device.deviceType == .robot {
            navigationController?.pushViewController(DeviceFamilyDetailViewController(family: .robot), animated: true)
            return
        }
        if device.deviceType == .radar {
            navigationController?.pushViewController(DeviceFamilyDetailViewController(family: .radar), animated: true)
            return
        }

        navigationController?.popViewController(animated: true)
    }
}
