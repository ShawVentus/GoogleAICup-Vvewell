import UIKit
import RingSDK

class ECGCheckViewController: UIViewController {

    // MARK: - State

    private enum ECGState {
        case idle
        case starting
        case measuring(packetCount: Int)
        case completed(ECGReport)
        case failed(String)
    }

    private var state: ECGState = .idle
    private let ecgService = RingECGService()

    // MARK: - UI

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceVertical = true
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private lazy var contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 16
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private lazy var bottomBar: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var startButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.layer.cornerRadius = 25
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var handSegment: UISegmentedControl = {
        let sc = UISegmentedControl(items: [t(.ecgLeftHand), t(.ecgRightHand)])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private var resultCard: UIView?
    private var statusCard: UIView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = t(.ecgHeroTitle)
        view.backgroundColor = .secondarySystemBackground
        hidesBottomBarWhenPushed = true
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
        setupScrollView()
        setupBottomBar()
        rebuildContent()
        updateStartButton()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func languageChanged() {
        title = t(.ecgHeroTitle)
        handSegment.setTitle(t(.ecgLeftHand), forSegmentAt: 0)
        handSegment.setTitle(t(.ecgRightHand), forSegmentAt: 1)
        rebuildContent()
        updateStartButton()
    }

    // MARK: - Layout

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
    }

    private func setupBottomBar() {
        view.addSubview(bottomBar)
        bottomBar.addSubview(startButton)
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            startButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 12),
            startButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 20),
            startButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -20),
            startButton.heightAnchor.constraint(equalToConstant: 50),
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    // MARK: - Content

    private func rebuildContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStack.addArrangedSubview(makeHeroCard())
        contentStack.addArrangedSubview(makePrerequisitesCard())
        contentStack.addArrangedSubview(makeHandPickerCard())

        switch state {
        case .idle:
            break
        case .starting:
            contentStack.addArrangedSubview(makeStatusCard(message: t(.ecgInitializingLatency), showSpinner: true))
        case .measuring(let count):
            contentStack.addArrangedSubview(makeStatusCard(message: String(format: t(.ecgRecordingPacketsFormat), count), showSpinner: true))
        case .completed(let report):
            contentStack.addArrangedSubview(makeResultCard(report: report))
        case .failed(let message):
            contentStack.addArrangedSubview(makeErrorCard(message: message))
        }
    }

    private func updateStartButton() {
        let isConnected = BTService.shared().isConnected
        switch state {
        case .idle, .completed, .failed:
            startButton.backgroundColor = isConnected ? UIColor(red: 0.4, green: 0.3, blue: 0.9, alpha: 1.0) : .tertiarySystemFill
            startButton.setTitleColor(isConnected ? .white : .tertiaryLabel, for: .normal)
            startButton.tintColor = isConnected ? .white : .tertiaryLabel
            startButton.isEnabled = isConnected
            startButton.setTitle(t(.ecgStartRecording), for: .normal)
        case .starting, .measuring:
            startButton.backgroundColor = .systemRed
            startButton.setTitleColor(.white, for: .normal)
            startButton.tintColor = .white
            startButton.isEnabled = true
            startButton.setTitle(t(.ecgStopRecording), for: .normal)
        }
    }

    // MARK: - Actions

    @objc private func startTapped() {
        switch state {
        case .starting, .measuring:
            BTService.shared().measureReq.sendECGLatencyMode(withStatus: false) { _ in }
            state = .idle
            rebuildContent()
            updateStartButton()
            return
        default:
            break
        }

        guard BTService.shared().isConnected else {
            showAlert(title: t(.deviceCheckNotConnectedTitle), message: t(.ecgNotConnectedMessage))
            return
        }

        let hand: UInt8 = handSegment.selectedSegmentIndex == 0 ? 0 : 1
        state = .starting
        rebuildContent()
        updateStartButton()

        BTService.shared().measureReq.sendECGLatencyMode(withStatus: true) { [weak self] success in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if !success {
                    self.state = .failed(t(.ecgEnableLatencyFailed))
                    self.rebuildContent()
                    self.updateStartButton()
                    return
                }

                self.state = .measuring(packetCount: 0)
                self.rebuildContent()
                self.updateStartButton()

                BTService.shared().measureReq.startECG(withHandPreference: hand, completion: { [weak self] started in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if !started {
                            self.state = .failed(t(.ecgStartFailed))
                            self.rebuildContent()
                            self.updateStartButton()
                        }
                    }
                }, data: { [weak self] pkts in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if case .measuring(let count) = self.state {
                            self.state = .measuring(packetCount: count + pkts.count)
                            self.rebuildContent()
                        }
                    }
                }, dataEnd: { [weak self] _, diagnosisResult in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        let dict = diagnosisResult as? [String: Any] ?? [:]
                        let report = ECGReport(
                            waveform: [],
                            sampleRate: 512,
                            minHeartRate: (dict["minHeartRate"] as? Int) ?? 0,
                            avgHeartRate: (dict["avgHeartRate"] as? Int) ?? 0,
                            maxHeartRate: (dict["maxHeartRate"] as? Int) ?? 0,
                            rhythmType: (dict["rhythmType"] as? Int) ?? 0,
                            confidence: (dict["confidence"] as? Int) ?? 0,
                            duration: 30
                        )
                        self.state = .completed(report)
                        self.rebuildContent()
                        self.updateStartButton()
                        BTService.shared().measureReq.sendECGLatencyMode(withStatus: false) { _ in }
                    }
                })
            }
        }
    }

    // MARK: - Card Builders

    private func makeHeroCard() -> UIView {
        let card = makeCard()
        let iconBg = UIView()
        iconBg.backgroundColor = UIColor(red: 0.4, green: 0.3, blue: 0.9, alpha: 1.0)
        iconBg.layer.cornerRadius = 30
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: "waveform.path.ecg", withConfiguration: iconConfig))
        iconIV.tintColor = .white
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconIV)

        let titleLabel = makeLabel(t(.ecgHeroTitle), font: .systemFont(ofSize: 20, weight: .bold), color: .label)
        let descLabel = makeLabel(
            t(.ecgHeroDescription),
            font: .systemFont(ofSize: 14), color: .secondaryLabel, lines: 0
        )

        card.addSubview(iconBg)
        card.addSubview(titleLabel)
        card.addSubview(descLabel)

        NSLayoutConstraint.activate([
            iconBg.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            iconBg.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 60),
            iconBg.heightAnchor.constraint(equalToConstant: 60),

            iconIV.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconBg.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            descLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            descLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        return card
    }

    private func makePrerequisitesCard() -> UIView {
        let card = makeCard()
        let titleLabel = makeLabel(t(.ecgPrerequisitesTitle), font: .systemFont(ofSize: 15, weight: .semibold), color: .label)
        let items = [
            ("checkmark.circle.fill", t(.ecgPrereqRingConnected), UIColor.systemGreen),
            ("bolt.fill", t(.ecgPrereqBoosterMode), UIColor(red: 0.4, green: 0.3, blue: 0.9, alpha: 1.0)),
        ]
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (icon, text, color) in items {
            let row = makeCheckRow(icon: icon, text: text, color: color)
            stack.addArrangedSubview(row)
        }
        card.addSubview(titleLabel)
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeHandPickerCard() -> UIView {
        let card = makeCard()
        let titleLabel = makeLabel(t(.ecgHandPreferenceTitle), font: .systemFont(ofSize: 15, weight: .semibold), color: .label)
        card.addSubview(titleLabel)
        card.addSubview(handSegment)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            handSegment.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            handSegment.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            handSegment.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            handSegment.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeStatusCard(message: String, showSpinner: Bool) -> UIView {
        let card = makeCard()
        card.backgroundColor = UIColor(red: 0.4, green: 0.3, blue: 0.9, alpha: 0.08)

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = UIColor(red: 0.4, green: 0.3, blue: 0.9, alpha: 1.0)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        if showSpinner { spinner.startAnimating() }

        let label = makeLabel(message, font: .systemFont(ofSize: 14, weight: .medium),
                               color: UIColor(red: 0.4, green: 0.3, blue: 0.9, alpha: 1.0), lines: 0)

        card.addSubview(spinner)
        card.addSubview(label)
        NSLayoutConstraint.activate([
            spinner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            spinner.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            label.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 10),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeResultCard(report: ECGReport) -> UIView {
        let card = makeCard()
        let titleLabel = makeLabel(t(.ecgResultsTitle), font: .systemFont(ofSize: 15, weight: .semibold), color: .label)

        let rhythmName: String
        switch report.rhythmType {
        case 0: rhythmName = t(.ecgRhythmNormal)
        case 1: rhythmName = t(.ecgRhythmAtrialFibrillation)
        case 2: rhythmName = t(.ecgRhythmTachycardia)
        case 3: rhythmName = t(.ecgRhythmBradycardia)
        default: rhythmName = String(format: t(.ecgRhythmUnknownFormat), report.rhythmType)
        }

        let metricsStack = UIStackView()
        metricsStack.axis = .horizontal
        metricsStack.distribution = .fillEqually
        metricsStack.spacing = 8
        metricsStack.translatesAutoresizingMaskIntoConstraints = false

        metricsStack.addArrangedSubview(makeMetricItem(label: t(.ecgMetricMinHR), value: "\(report.minHeartRate)", unit: t(.unitBpm)))
        metricsStack.addArrangedSubview(makeMetricItem(label: t(.ecgMetricAvgHR), value: "\(report.avgHeartRate)", unit: t(.unitBpm)))
        metricsStack.addArrangedSubview(makeMetricItem(label: t(.ecgMetricMaxHR), value: "\(report.maxHeartRate)", unit: t(.unitBpm)))

        let rhythmLabel = makeLabel(String(format: t(.ecgRhythmFormat), rhythmName), font: .systemFont(ofSize: 14, weight: .medium), color: .label)
        let confidenceLabel = makeLabel(String(format: t(.ecgConfidenceFormat), report.confidence), font: .systemFont(ofSize: 13), color: .secondaryLabel)

        card.addSubview(titleLabel)
        card.addSubview(metricsStack)
        card.addSubview(rhythmLabel)
        card.addSubview(confidenceLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            metricsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            metricsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            metricsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            rhythmLabel.topAnchor.constraint(equalTo: metricsStack.bottomAnchor, constant: 12),
            rhythmLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            confidenceLabel.topAnchor.constraint(equalTo: rhythmLabel.bottomAnchor, constant: 4),
            confidenceLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            confidenceLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeErrorCard(message: String) -> UIView {
        let card = makeCard()
        card.backgroundColor = UIColor.systemRed.withAlphaComponent(0.08)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: iconConfig))
        iconIV.tintColor = .systemRed
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let label = makeLabel(message, font: .systemFont(ofSize: 14, weight: .medium), color: .systemRed, lines: 0)

        card.addSubview(iconIV)
        card.addSubview(label)
        NSLayoutConstraint.activate([
            iconIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconIV.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),

            label.leadingAnchor.constraint(equalTo: iconIV.trailingAnchor, constant: 10),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    // MARK: - Reusable Helpers

    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        card.layer.shadowOffset = AppDesign.Shadow.cardOffset
        card.layer.shadowRadius = AppDesign.Shadow.cardRadius
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    private func makeLabel(_ text: String, font: UIFont, color: UIColor, lines: Int = 1) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = font
        lbl.textColor = color
        lbl.numberOfLines = lines
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }

    private func makeCheckRow(icon: String, text: String, color: UIColor) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iv = UIImageView(image: UIImage(systemName: icon, withConfiguration: cfg))
        iv.tintColor = color
        iv.translatesAutoresizingMaskIntoConstraints = false
        let lbl = makeLabel(text, font: .systemFont(ofSize: 14), color: .label)
        row.addSubview(iv)
        row.addSubview(lbl)
        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            iv.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            lbl.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 8),
            lbl.topAnchor.constraint(equalTo: row.topAnchor, constant: 2),
            lbl.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -2),
        ])
        return row
    }

    private func makeMetricItem(label: String, value: String, unit: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = AppDesign.CornerRadius.button
        container.translatesAutoresizingMaskIntoConstraints = false

        let lbl = makeLabel(label, font: .systemFont(ofSize: 11), color: .secondaryLabel)
        lbl.textAlignment = .center
        let valLbl = makeLabel(value, font: .systemFont(ofSize: 22, weight: .bold), color: .label)
        valLbl.textAlignment = .center
        let unitLbl = makeLabel(unit, font: .systemFont(ofSize: 11), color: .secondaryLabel)
        unitLbl.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [lbl, valLbl, unitLbl])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        ])
        return container
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
        present(alert, animated: true)
    }
}
