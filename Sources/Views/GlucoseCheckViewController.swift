import UIKit
import RingSDK

class GlucoseCheckViewController: UIViewController {

    // MARK: - State

    private enum GluState {
        case idle
        case collectingPackets(count: Int)
        case uploading
        case analyzing
        case completed(GluReport)
        case failed(String)
    }

    private var state: GluState = .idle
    private var packetCount = 0

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

    private lazy var mealSegment: UISegmentedControl = {
        let sc = UISegmentedControl(items: [t(.glucoseMealFasting), t(.glucoseMealPostMeal)])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = t(.glucoseCheckTitle)
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
        title = t(.glucoseCheckTitle)
        mealSegment.setTitle(t(.glucoseMealFasting), forSegmentAt: 0)
        mealSegment.setTitle(t(.glucoseMealPostMeal), forSegmentAt: 1)
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
        contentStack.addArrangedSubview(makeMealPickerCard())

        switch state {
        case .idle:
            break
        case .collectingPackets(let count):
            contentStack.addArrangedSubview(makeProgressCard(message: String(format: t(.glucoseCollectingPacketsFormat), count), progress: min(Float(count) / 10.0, 1.0)))
        case .uploading:
            contentStack.addArrangedSubview(makeStatusCard(message: t(.glucoseUploadingStatus)))
        case .analyzing:
            contentStack.addArrangedSubview(makeStatusCard(message: t(.glucoseAnalyzingStatus)))
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
            let accentColor = UIColor(red: 0.984, green: 0.749, blue: 0.149, alpha: 1.0)
            startButton.backgroundColor = isConnected ? accentColor : .tertiarySystemFill
            startButton.setTitleColor(isConnected ? .black : .tertiaryLabel, for: .normal)
            startButton.isEnabled = isConnected
            startButton.setTitle(t(.glucoseStartMeasurement), for: .normal)
        case .collectingPackets, .uploading, .analyzing:
            startButton.backgroundColor = .systemRed
            startButton.setTitleColor(.white, for: .normal)
            startButton.isEnabled = true
            startButton.setTitle(t(.glucoseStopMeasurement), for: .normal)
        }
    }

    // MARK: - Actions

    @objc private func startTapped() {
        switch state {
        case .collectingPackets, .uploading, .analyzing:
            state = .idle
            rebuildContent()
            updateStartButton()
            return
        default:
            break
        }

        guard BTService.shared().isConnected else {
            showAlert(title: t(.deviceCheckNotConnectedTitle), message: t(.glucoseNotConnectedMessage))
            return
        }

        packetCount = 0
        state = .collectingPackets(count: 0)
        rebuildContent()
        updateStartButton()

        BTService.shared().measureReq.startGluMeasure(ack: { [weak self] success in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if !success {
                    self.state = .failed(t(.glucoseStartFailed))
                    self.rebuildContent()
                    self.updateStartButton()
                }
            }
        }, pkt: { [weak self] _ in
            guard let self = self else { return }
            self.packetCount += 1
            DispatchQueue.main.async {
                self.state = .collectingPackets(count: self.packetCount)
                self.rebuildContent()
            }
        }, allPkts: { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Server upload not yet configured — show placeholder result
                self.state = .uploading
                self.rebuildContent()

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    let placeholderReport = GluReport(
                        glucoseValue: 0,
                        riskLevel: 0,
                        timestamp: Date(),
                        rawData: [:]
                    )
                    self.state = .completed(placeholderReport)
                    self.rebuildContent()
                    self.updateStartButton()
                }
            }
        })
    }

    // MARK: - Card Builders

    private func makeHeroCard() -> UIView {
        let card = makeCard()
        let accentColor = UIColor(red: 0.984, green: 0.749, blue: 0.149, alpha: 1.0)

        let iconBg = UIView()
        iconBg.backgroundColor = accentColor
        iconBg.layer.cornerRadius = 30
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: "drop.fill", withConfiguration: iconConfig))
        iconIV.tintColor = .white
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconIV)

        let titleLabel = makeLabel(t(.glucoseCheckTitle), font: .systemFont(ofSize: 20, weight: .bold), color: .label)
        let descLabel = makeLabel(
            t(.glucoseHeroDescription),
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

    private func makeMealPickerCard() -> UIView {
        let card = makeCard()
        let titleLabel = makeLabel(t(.glucoseMeasurementContext), font: .systemFont(ofSize: 15, weight: .semibold), color: .label)
        card.addSubview(titleLabel)
        card.addSubview(mealSegment)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            mealSegment.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            mealSegment.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            mealSegment.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            mealSegment.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeProgressCard(message: String, progress: Float) -> UIView {
        let accentColor = UIColor(red: 0.984, green: 0.749, blue: 0.149, alpha: 1.0)
        let card = makeCard()
        card.backgroundColor = accentColor.withAlphaComponent(0.08)

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = accentColor
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let label = makeLabel(message, font: .systemFont(ofSize: 14, weight: .medium), color: accentColor, lines: 0)

        let progressBar = UIProgressView(progressViewStyle: .default)
        progressBar.progressTintColor = accentColor
        progressBar.trackTintColor = accentColor.withAlphaComponent(0.2)
        progressBar.progress = progress
        progressBar.layer.cornerRadius = AppDesign.CornerRadius.progressBar
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(spinner)
        card.addSubview(label)
        card.addSubview(progressBar)

        NSLayoutConstraint.activate([
            spinner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            spinner.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),

            label.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 10),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            progressBar.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
            progressBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            progressBar.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            progressBar.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            progressBar.heightAnchor.constraint(equalToConstant: 6),
        ])
        return card
    }

    private func makeStatusCard(message: String) -> UIView {
        let accentColor = UIColor(red: 0.984, green: 0.749, blue: 0.149, alpha: 1.0)
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

    private func makeResultCard(report: GluReport) -> UIView {
        let card = makeCard()
        let titleLabel = makeLabel(t(.glucoseResultTitle), font: .systemFont(ofSize: 15, weight: .semibold), color: .label)

        let isPlaceholder = report.glucoseValue == 0
        let valueStr = isPlaceholder ? "--" : String(format: "%.1f", report.glucoseValue)
        let valueLabel = makeLabel(valueStr, font: .systemFont(ofSize: 40, weight: .bold), color: isPlaceholder ? .tertiaryLabel : .label)
        let unitLabel = makeLabel(t(.unitMillimolesPerLiter), font: .systemFont(ofSize: 14), color: .secondaryLabel)
        let noteLabel = makeLabel(
            t(.glucoseServerNotConfigured),
            font: .systemFont(ofSize: 13), color: .secondaryLabel, lines: 0
        )

        card.addSubview(titleLabel)
        card.addSubview(valueLabel)
        card.addSubview(unitLabel)
        card.addSubview(noteLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            valueLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            unitLabel.firstBaselineAnchor.constraint(equalTo: valueLabel.firstBaselineAnchor),
            unitLabel.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 6),

            noteLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 12),
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

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
        present(alert, animated: true)
    }
}
