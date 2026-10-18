import UIKit
import Combine

class ThermalCameraViewController: UIViewController {

    private let session = ThermalCameraSession()
    private var cancellables = Set<AnyCancellable>()
    private let estimator = RespiratoryRateEstimator()

    private let themeColor = UIColor(red: 0.9, green: 0.45, blue: 0.2, alpha: 1.0)

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

    private let previewView = UIView()
    private let colorBar = ThermalColorBarView()
    private let tempPanel = UIView()
    private let rrCard = UIView()

    private let minTempLabel = UILabel()
    private let maxTempLabel = UILabel()
    private let avgTempLabel = UILabel()

    private let bpmLabel = UILabel()
    private let qualityLabel = UILabel()
    private let waveformView = RespiratoryWaveformView()

    private var isSessionActive = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = t(.thermalCameraTitle)
        view.backgroundColor = .secondarySystemBackground
        setupUI()
        observeSession()
        startSession()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isSessionActive {
            _ = session.startPreview(in: previewView)
            _ = session.startThermometry()
            session.startFrameCapture()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopPreview()
        session.stopThermometry()
        session.stopFrameCapture()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])

        contentStack.addArrangedSubview(makePreviewSection())
        contentStack.addArrangedSubview(makeTemperaturePanel())
        contentStack.addArrangedSubview(makeRespiratoryRateCard())
    }

    private func makePreviewSection() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        previewView.backgroundColor = .black
        previewView.layer.cornerRadius = AppDesign.CornerRadius.card
        previewView.clipsToBounds = true
        previewView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(previewView)

        colorBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(colorBar)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: container.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: colorBar.leadingAnchor, constant: -8),
            previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor, multiplier: 0.75),

            colorBar.topAnchor.constraint(equalTo: previewView.topAnchor),
            colorBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            colorBar.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            colorBar.widthAnchor.constraint(equalToConstant: 44),

            container.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
        ])

        return container
    }

    private func makeTemperaturePanel() -> UIView {
        tempPanel.backgroundColor = .systemBackground
        tempPanel.layer.cornerRadius = AppDesign.CornerRadius.card
        tempPanel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        tempPanel.addSubview(stack)

        let minCard = makeTempItem(label: t(.thermalCameraMinTemp), valueLabel: minTempLabel, color: .systemBlue)
        let avgCard = makeTempItem(label: t(.thermalCameraAvgTemp), valueLabel: avgTempLabel, color: themeColor)
        let maxCard = makeTempItem(label: t(.thermalCameraMaxTemp), valueLabel: maxTempLabel, color: .systemRed)

        stack.addArrangedSubview(minCard)
        stack.addArrangedSubview(avgCard)
        stack.addArrangedSubview(maxCard)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: tempPanel.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: tempPanel.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: tempPanel.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: tempPanel.bottomAnchor, constant: -16),
        ])

        return tempPanel
    }

    private func makeTempItem(label: String, valueLabel: UILabel, color: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        valueLabel.text = "--"
        valueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        valueLabel.textColor = color
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func makeRespiratoryRateCard() -> UIView {
        rrCard.backgroundColor = .systemBackground
        rrCard.layer.cornerRadius = AppDesign.CornerRadius.card
        rrCard.translatesAutoresizingMaskIntoConstraints = false

        let headerLabel = UILabel()
        headerLabel.text = t(.thermalCameraRespiratoryRate)
        headerLabel.font = .systemFont(ofSize: 14, weight: .medium)
        headerLabel.textColor = .secondaryLabel
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        rrCard.addSubview(headerLabel)

        bpmLabel.text = t(.thermalCameraAnalyzing)
        bpmLabel.font = .systemFont(ofSize: 48, weight: .bold)
        bpmLabel.textColor = themeColor
        bpmLabel.textAlignment = .center
        bpmLabel.translatesAutoresizingMaskIntoConstraints = false
        rrCard.addSubview(bpmLabel)

        let bpmUnitLabel = UILabel()
        bpmUnitLabel.text = t(.thermalCameraBpm)
        bpmUnitLabel.font = .systemFont(ofSize: 14, weight: .medium)
        bpmUnitLabel.textColor = .secondaryLabel
        bpmUnitLabel.textAlignment = .center
        bpmUnitLabel.translatesAutoresizingMaskIntoConstraints = false
        rrCard.addSubview(bpmUnitLabel)

        qualityLabel.text = ""
        qualityLabel.font = .systemFont(ofSize: 12)
        qualityLabel.textColor = .secondaryLabel
        qualityLabel.textAlignment = .center
        qualityLabel.translatesAutoresizingMaskIntoConstraints = false
        rrCard.addSubview(qualityLabel)

        waveformView.translatesAutoresizingMaskIntoConstraints = false
        rrCard.addSubview(waveformView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: rrCard.topAnchor, constant: 16),
            headerLabel.centerXAnchor.constraint(equalTo: rrCard.centerXAnchor),

            bpmLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            bpmLabel.centerXAnchor.constraint(equalTo: rrCard.centerXAnchor),

            bpmUnitLabel.topAnchor.constraint(equalTo: bpmLabel.bottomAnchor, constant: 2),
            bpmUnitLabel.centerXAnchor.constraint(equalTo: rrCard.centerXAnchor),

            qualityLabel.topAnchor.constraint(equalTo: bpmUnitLabel.bottomAnchor, constant: 4),
            qualityLabel.centerXAnchor.constraint(equalTo: rrCard.centerXAnchor),

            waveformView.topAnchor.constraint(equalTo: qualityLabel.bottomAnchor, constant: 12),
            waveformView.leadingAnchor.constraint(equalTo: rrCard.leadingAnchor, constant: 16),
            waveformView.trailingAnchor.constraint(equalTo: rrCard.trailingAnchor, constant: -16),
            waveformView.heightAnchor.constraint(equalToConstant: 60),
            waveformView.bottomAnchor.constraint(equalTo: rrCard.bottomAnchor, constant: -16),
        ])

        return rrCard
    }

    // MARK: - Session

    private func startSession() {
        guard let device = DeviceManager.shared.device(for: .thermalCamera) as? ThermalCameraDevice,
              device.isPaired() else {
            showDisconnectedState()
            return
        }

        isSessionActive = true
        _ = session.startPreview(in: previewView)
        _ = session.startThermometry()
        session.startFrameCapture()
    }

    private func showDisconnectedState() {
        bpmLabel.text = "--"
        qualityLabel.text = t(.thermalCameraDisconnected)
        minTempLabel.text = "--"
        maxTempLabel.text = "--"
        avgTempLabel.text = "--"
    }

    // MARK: - Observe

    private func observeSession() {
        session.thermometry
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reading in
                self?.updateTemperature(reading)
            }
            .store(in: &cancellables)

        session.frameCapture
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                self?.estimator.processFrame(image)
            }
            .store(in: &cancellables)

        estimator.results
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.updateRespiratoryRate(result)
            }
            .store(in: &cancellables)
    }

    private func updateTemperature(_ reading: ThermometryReading) {
        minTempLabel.text = String(format: "%.1f°C", reading.minTemp)
        maxTempLabel.text = String(format: "%.1f°C", reading.maxTemp)
        avgTempLabel.text = String(format: "%.1f°C", reading.avgTemp)
        colorBar.minTemp = reading.minTemp
        colorBar.maxTemp = reading.maxTemp
        colorBar.avgTemp = reading.avgTemp
    }

    private func updateRespiratoryRate(_ result: RespiratoryRateResult) {
        if let bpm = result.bpm, result.isReliable {
            bpmLabel.text = String(format: "%.0f", bpm)
            qualityLabel.textColor = AppDesign.Color.connectedGreen
            qualityLabel.text = "● \(String(format: "%.0f%%", result.qualityScore * 100))"
        } else if result.buffering {
            bpmLabel.text = t(.thermalCameraAnalyzing)
            qualityLabel.text = ""
            qualityLabel.textColor = .secondaryLabel
        } else {
            bpmLabel.text = "--"
            qualityLabel.text = t(.thermalCameraNoSignal)
            qualityLabel.textColor = .systemGray
        }
        waveformView.update(with: result.filteredSignal, bpm: result.bpm)
    }

    @objc private func languageChanged() {
        title = t(.thermalCameraTitle)
        rebuildContent()
    }

    private func rebuildContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        setupUI()
    }
}
