import UIKit
import RingSDK

class EmotionCheckViewController: UIViewController {

    // MARK: - State

    private enum EmotionState {
        case idle
        case queryingStatus
        case measuring(ppiCount: Int, secondsRemaining: Int)
        case completed(ppiCount: Int)
        case failed(String)
    }

    private var state: EmotionState = .idle
    private var ppiCount = 0
    private var countdownTimer: Timer?
    private var remainingSeconds = 0

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

    private lazy var durationSegment: UISegmentedControl = {
        let sc = UISegmentedControl(items: [t(.emotionDuration1m), t(.emotionDuration3m), t(.emotionDuration5m)])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = t(.emotionCheckTitle)
        view.backgroundColor = .secondarySystemBackground
        hidesBottomBarWhenPushed = true
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
        setupScrollView()
        setupBottomBar()
        rebuildContent()
        updateStartButton()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopMeasurementIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func languageChanged() {
        title = t(.emotionCheckTitle)
        durationSegment.setTitle(t(.emotionDuration1m), forSegmentAt: 0)
        durationSegment.setTitle(t(.emotionDuration3m), forSegmentAt: 1)
        durationSegment.setTitle(t(.emotionDuration5m), forSegmentAt: 2)
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
        contentStack.addArrangedSubview(makeDurationPickerCard())

        switch state {
        case .idle:
            break
        case .queryingStatus:
            contentStack.addArrangedSubview(makeStatusCard(message: t(.emotionCheckingDeviceStatus)))
        case .measuring(let count, let seconds):
            contentStack.addArrangedSubview(makeMeasuringCard(ppiCount: count, secondsRemaining: seconds))
        case .completed(let count):
            contentStack.addArrangedSubview(makeResultCard(ppiCount: count))
        case .failed(let message):
            contentStack.addArrangedSubview(makeErrorCard(message: message))
        }
    }

    private func updateStartButton() {
        let isConnected = BTService.shared().isConnected
        let accentColor = AppDesign.Color.bloodOxygen
        switch state {
        case .idle, .completed, .failed:
            startButton.backgroundColor = isConnected ? accentColor : .tertiarySystemFill
            startButton.setTitleColor(isConnected ? .white : .tertiaryLabel, for: .normal)
            startButton.isEnabled = isConnected
            startButton.setTitle(t(.emotionStartMeasurement), for: .normal)
        case .queryingStatus, .measuring:
            startButton.backgroundColor = .systemRed
            startButton.setTitleColor(.white, for: .normal)
            startButton.isEnabled = true
            startButton.setTitle(t(.emotionStopMeasurement), for: .normal)
        }
    }

    // MARK: - Actions

    @objc private func startTapped() {
        switch state {
        case .queryingStatus, .measuring:
            stopMeasurementIfNeeded()
            state = .idle
            rebuildContent()
            updateStartButton()
            return
        default:
            break
        }

        guard BTService.shared().isConnected else {
            showAlert(title: t(.deviceCheckNotConnectedTitle), message: t(.emotionNotConnectedMessage))
            return
        }

        state = .queryingStatus
        rebuildContent()
        updateStartButton()

        BTRtPPI.sharedInstance().queryEmotionMeasureStatus { [weak self] _, _, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.startMeasurement()
            }
        }
    }

    private func startMeasurement() {
        let durations = [60, 180, 300]
        let seconds = durations[durationSegment.selectedSegmentIndex]
        remainingSeconds = seconds
        ppiCount = 0
        state = .measuring(ppiCount: 0, secondsRemaining: seconds)
        rebuildContent()
        updateStartButton()

        BTRtPPI.sharedInstance().startEmotionMeasurement(
            with: .PPI,
            duration: UInt(seconds),
            mode: 0x01
        ) { [weak self] _, result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if result != 0 {
                    self.countdownTimer?.invalidate()
                    self.state = .failed(String(format: t(.emotionStartFailedFormat), result))
                    self.rebuildContent()
                    self.updateStartButton()
                }
            }
        }

        BTRtPPI.sharedInstance().rtPPIDateHandle = { [weak self] _ in
            guard let self = self else { return }
            self.ppiCount += 1
            DispatchQueue.main.async {
                if case .measuring(_, let secs) = self.state {
                    self.state = .measuring(ppiCount: self.ppiCount, secondsRemaining: secs)
                    self.rebuildContent()
                }
            }
        }

        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.remainingSeconds -= 1
            if self.remainingSeconds <= 0 {
                timer.invalidate()
                self.countdownTimer = nil
                self.state = .completed(ppiCount: self.ppiCount)
                self.rebuildContent()
                self.updateStartButton()
                BTRtPPI.sharedInstance().rtPPIDateHandle = { _ in }
            } else {
                if case .measuring(let count, _) = self.state {
                    self.state = .measuring(ppiCount: count, secondsRemaining: self.remainingSeconds)
                    self.rebuildContent()
                }
            }
        }
    }

    private func stopMeasurementIfNeeded() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        BTRtPPI.sharedInstance().rtPPIDateHandle = { _ in }
        BTRtPPI.sharedInstance().stopRealTimeMeasure(with: .PPI) { _, _ in }
    }

    // MARK: - Card Builders

    private func makeHeroCard() -> UIView {
        let card = makeCard()
        let accentColor = AppDesign.Color.bloodOxygen

        let iconBg = UIView()
        iconBg.backgroundColor = accentColor
        iconBg.layer.cornerRadius = 30
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: "face.smiling", withConfiguration: iconConfig))
        iconIV.tintColor = .white
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconIV)

        let titleLabel = makeLabel(t(.emotionHeroTitle), font: .systemFont(ofSize: 20, weight: .bold), color: .label)
        let descLabel = makeLabel(
            t(.emotionHeroDescription),
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

    private func makeDurationPickerCard() -> UIView {
        let card = makeCard()
        let titleLabel = makeLabel(t(.emotionDurationTitle), font: .systemFont(ofSize: 15, weight: .semibold), color: .label)
        card.addSubview(titleLabel)
        card.addSubview(durationSegment)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            durationSegment.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            durationSegment.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            durationSegment.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            durationSegment.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeStatusCard(message: String) -> UIView {
        let accentColor = AppDesign.Color.bloodOxygen
        let card = makeCard()
        card.backgroundColor = accentColor.withAlphaComponent(0.08)

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = accentColor
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let label = makeLabel(message, font: .systemFont(ofSize: 14, weight: .medium), color: accentColor, lines: 0)

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

    private func makeMeasuringCard(ppiCount: Int, secondsRemaining: Int) -> UIView {
        let accentColor = AppDesign.Color.bloodOxygen
        let card = makeCard()
        card.backgroundColor = accentColor.withAlphaComponent(0.08)

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = accentColor
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let timeStr = localizedCountdownString(secondsRemaining)

        let statusLabel = makeLabel(String(format: t(.emotionMeasuringRemainingFormat), timeStr), font: .systemFont(ofSize: 14, weight: .semibold), color: accentColor)
        let countLabel = makeLabel(String(format: t(.emotionDataPointsCollectedFormat), ppiCount), font: .systemFont(ofSize: 13), color: .secondaryLabel)

        card.addSubview(spinner)
        card.addSubview(statusLabel)
        card.addSubview(countLabel)

        NSLayoutConstraint.activate([
            spinner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            spinner.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),

            statusLabel.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 10),
            statusLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            countLabel.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 10),
            countLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            countLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeResultCard(ppiCount: Int) -> UIView {
        let card = makeCard()
        let titleLabel = makeLabel(t(.emotionMeasurementComplete), font: .systemFont(ofSize: 15, weight: .semibold), color: .label)
        let countLabel = makeLabel(String(format: t(.emotionDataCollectedPointsFormat), ppiCount), font: .systemFont(ofSize: 22, weight: .bold), color: .label)
        let noteLabel = makeLabel(
            t(.emotionServerNotConfigured),
            font: .systemFont(ofSize: 13), color: .secondaryLabel, lines: 0
        )

        card.addSubview(titleLabel)
        card.addSubview(countLabel)
        card.addSubview(noteLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            countLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            countLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            noteLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 10),
            noteLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            noteLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            noteLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
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

    private func localizedCountdownString(_ totalSeconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        formatter.calendar?.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        return formatter.string(from: TimeInterval(totalSeconds)) ?? "00:00"
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
        present(alert, animated: true)
    }
}
