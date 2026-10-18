import UIKit
import Combine
import RingSDK

class RingCheckViewController: UIViewController {

    private let themeColor = AppDesign.Color.primaryGreen
    private var cancellables = Set<AnyCancellable>()
    private var measureCancellables = Set<AnyCancellable>()
    private var isConnected = false

    // MARK: - Measurement State

    private struct CheckResult {
        var heartRate: Float?
        var spo2: Float?
        var temperature: Float?
        var stress: Float?
        var bodyComp: Float?
        var bodyCompData: BodyCompositionData?
        var uv: Float?
        var hrv: Int?               // From health data, not real-time measurement
        var timestamp: Date?
    }

    private enum CheckState {
        case idle
        case measuring(MeasureType)
        case completed
        case failed(String)
    }

    private var checkState: CheckState = .idle
    private var currentResult = CheckResult()
    private var lastResult: CheckResult?

    /// UV + HRV loaded on page enter (no measurement needed)
    private var passiveUV: Float?
    private var passiveHRV: Int?
    private var uvHistory: [(date: String, value: Float)] = []   // 7-day UV trend
    private var hrvHistory: [(date: String, value: Int)] = []     // 7-day HRV trend

    /// Activity data fetched on page enter
    private var activitySteps: Int?
    private var activityCalories: Double?
    private var activityDistance: Double?

    /// Sleep data fetched on page enter
    private var sleepTotalMinutes: Int?
    private var sleepDeepMinutes: Int?
    private var sleepLightMinutes: Int?
    private var sleepREMMinutes: Int?
    private var sleepAwakeMinutes: Int?
    private var sleepStartTime: String?
    private var sleepEndTime: String?

    /// Device capabilities — determines which metrics to show
    private var supportsUV: Bool = false
    private var supportsBodyComp: Bool = false
    private var hasHRVData: Bool = false

    /// The ordered list of measurements to run during a quick check.
    /// Built dynamically — body composition only included if hardware supports it.
    private var measureSequence: [MeasureType] = [.heartRate, .spo2, .temperature]

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

    private lazy var bottomBar: UIView = {
        let bar = UIView()
        bar.backgroundColor = .secondarySystemBackground
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()

    private lazy var startButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.layer.cornerRadius = 25
        btn.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        btn.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        btn.setTitle("  \(t(.ringCheckStartAction))", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        btn.addTarget(self, action: #selector(startCheckTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
        setupScrollView()
        setupBottomBar()
        syncConnectionState()
        observeDevice()
        updateTitle()
        queryDeviceFeatures()
        rebuildContent()
        updateStartButton()
        loadPassiveMetrics()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func languageChanged() {
        updateTitle()
        rebuildContent()
        updateStartButton()
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
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])

        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        scrollView.scrollIndicatorInsets = scrollView.contentInset
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

    // MARK: - State

    private func syncConnectionState() {
        let device = DeviceManager.shared.device(for: .ring)
        let connected = device?.isConnected() ?? false
        let isPaired = device?.isPaired() ?? false
        print("[RingCheck] syncConnectionState: device=\(device != nil), isPaired=\(isPaired), isConnected=\(connected), registeredTypes=\(DeviceManager.shared.registeredTypes)")
        isConnected = connected
    }

    private func updateTitle() {
        var deviceName: String?
        DeviceManager.shared.device(for: .ring)?.deviceInfo
            .compactMap { $0 }
            .first()
            .sink { info in
                if !info.name.isEmpty { deviceName = info.name }
            }
            .store(in: &cancellables)

        if let name = deviceName, !name.isEmpty {
            title = String(format: t(.ringTitleWithNameFormat), t(.ringDetailTitle), name)
        } else {
            title = t(.ringCheckTitle)
        }
    }

    private func observeDevice() {
        DeviceManager.shared.connectionStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (type, state) in
                guard let self = self else { return }
                self.syncConnectionState()

                // Detect disconnect while measuring
                if type == .ring, !self.isConnected {
                    if case .measuring(let currentType) = self.checkState {
                        DeviceManager.shared.ring()?.healthService.stopMeasurement(type: currentType)
                        self.measureCancellables.removeAll()
                        self.savePartialResult()
                        self.checkState = .failed(t(.ringCheckDisconnectedDuringMeasurement))
                    }
                }

                self.rebuildContent()
                self.updateStartButton()
            }
            .store(in: &cancellables)

        DeviceManager.shared.device(for: .ring)?.deviceInfo
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTitle()
            }
            .store(in: &cancellables)
    }

    // MARK: - Start / Stop Check

    @objc private func startCheckTapped() {
        // If currently measuring, stop the measurement
        if case .measuring(let currentType) = checkState {
            stopCurrentMeasurement(type: currentType)
            return
        }

        guard isConnected else { return }

        // Only allow starting when idle, completed, or failed
        switch checkState {
        case .measuring:
            return
        case .idle, .completed, .failed:
            break
        }

        currentResult = CheckResult()
        measureCancellables.removeAll()
        runNextMeasurement(index: 0)
    }

    private func stopCurrentMeasurement(type: MeasureType) {
        DeviceManager.shared.ring()?.healthService.stopMeasurement(type: type)
        measureCancellables.removeAll()
        savePartialResult()
        checkState = .failed(t(.ringCheckMeasurementCancelled))
        rebuildContent()
        updateStartButton()
    }

    /// Preserve any partial data collected so far.
    private func savePartialResult() {
        if currentResult.heartRate != nil || currentResult.spo2 != nil
            || currentResult.temperature != nil
            || currentResult.uv != nil {
            currentResult.timestamp = Date()
            lastResult = currentResult
        }
    }

    private func runNextMeasurement(index: Int) {
        guard index < measureSequence.count else {
            // All real-time measurements done
            currentResult.timestamp = Date()
            currentResult.uv = passiveUV     // Use already-loaded passive data
            currentResult.hrv = passiveHRV
            lastResult = currentResult
            checkState = .completed
            rebuildContent()
            updateStartButton()
            return
        }

        let type = measureSequence[index]
        checkState = .measuring(type)
        rebuildContent()
        updateStartButton()

        guard let ring = DeviceManager.shared.ring() else {
            checkState = .failed(t(.ringCheckDeviceUnavailable))
            rebuildContent()
            updateStartButton()
            return
        }

        ring.healthService.startMeasurement(type: type)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                if case .failure(let error) = completion {
                    self.savePartialResult()
                    self.checkState = .failed(error.localizedDescription)
                    self.rebuildContent()
                    self.updateStartButton()
                }
            }, receiveValue: { [weak self] result in
                guard let self = self else { return }
                switch result.type {
                case .heartRate:
                    self.currentResult.heartRate = result.value
                case .spo2:
                    self.currentResult.spo2 = result.value
                case .temperature:
                    self.currentResult.temperature = result.value
                default:
                    break
                }
                // Update display immediately after each metric completes
                self.currentResult.timestamp = Date()
                self.lastResult = self.currentResult
                self.runNextMeasurement(index: index + 1)
            })
            .store(in: &measureCancellables)
    }

    // MARK: - Device Feature Query

    private func queryDeviceFeatures() {
        guard isConnected else { return }
        BTService.shared().baseReq.fetch(.features) { [weak self] obj, _ in
            guard let self = self, let features = obj as? BTFeatureModel else { return }
            DispatchQueue.main.async {
                print("[RingCheck] Features: BC=\(features.isSupportBC), UV=\(features.isUVSupported), ECG=\(features.ecgMeasurement), Stress=\(features.isSupportStress), Emotion=\(features.isSupportEmotion), Glu=\(features.isSupportGlu)")
                self.rebuildContent()
            }
        }
    }

    // MARK: - Passive Metrics (loaded on page enter)

    private func loadPassiveMetrics() {
        print("[RingCheck] loadPassiveMetrics called, isConnected=\(isConnected)")
        guard isConnected else {
            print("[RingCheck] ❌ skipped — not connected")
            return
        }

        fetchLatestUV { [weak self] uv in
            guard let self = self else { return }
            print("[RingCheck] UV fetch returned: \(String(describing: uv))")
            if let uv = uv {
                self.supportsUV = true
                self.passiveUV = uv
            }
            self.rebuildContent()
        }

        fetch7DayHRV { [weak self] history in
            guard let self = self else { return }
            self.hrvHistory = history
            if let latest = history.last {
                self.hasHRVData = true
                self.passiveHRV = latest.value
            }
            print("[RingCheck] HRV 7-day: \(history.map { "\($0.date):\($0.value)" })")
            self.rebuildContent()
        }

        fetchActivityToday()
        fetchSleepLastNight()
    }

    private func fetchActivityToday() {
        BTService.shared().baseReq.queryRealData { [weak self] model in
            guard let self = self, let model = model else { return }
            DispatchQueue.main.async {
                self.activitySteps = Int(model.steps)
                self.activityCalories = Double(model.calories)
                self.activityDistance = Double(model.distance)
                self.rebuildContent()
            }
        }
    }

    private func fetchSleepLastNight() {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return }
        let dc = calendar.dateComponents([.year, .month, .day], from: yesterday)

        BTService.shared().sleepReq.handleData { [weak self] summary, _ in
            guard let self = self, let summary = summary else { return }
            DispatchQueue.main.async {
                let totalMin = Int(summary.totalSleepDuration)
                guard totalMin > 0 else { return }
                self.sleepTotalMinutes = totalMin
                self.sleepDeepMinutes = Int(summary.deepSleepDuration)
                self.sleepLightMinutes = Int(summary.lightSleepDuration)
                self.sleepREMMinutes = Int(summary.remSleepDuration)
                self.sleepAwakeMinutes = Int(summary.awakeDuration)

                let timeFmt = self.localizedClockFormatter()
                let startDate = Date(timeIntervalSince1970: TimeInterval(summary.startTimestamp))
                let endDate = Date(timeIntervalSince1970: TimeInterval(summary.endTimestamp))
                self.sleepStartTime = timeFmt.string(from: startDate)
                self.sleepEndTime = timeFmt.string(from: endDate)
                self.rebuildContent()
            }
        }
        BTService.shared().sleepReq.fetch(with: dc)
    }

    // MARK: - UV + HRV Data Fetch

    private var uvDataManager: BTOriginalDataManager?

    private func fetchLatestUV(completion: @escaping (Float?) -> Void) {
        print("[RingCheck:UV] Step 1: Checking UV feature support...")

        // Step 1: Query device features to ensure UV is supported
        BTService.shared().baseReq.fetch(.features) { [weak self] obj, _ in
            guard let self = self else { return }
            guard let features = obj as? BTFeatureModel else {
                print("[RingCheck:UV] ❌ Failed to fetch features")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            print("[RingCheck:UV] Feature check: isUVSupported=\(features.isUVSupported)")

            guard features.isUVSupported != 0 else {
                print("[RingCheck:UV] ❌ UV not supported on this device")
                DispatchQueue.main.async {
                    self.supportsUV = false
                    completion(nil)
                }
                return
            }

            // Step 2: Fetch UV data via BTOriginalDataManager
            DispatchQueue.main.async {
                self.supportsUV = true
                self.doFetchUVData(completion: completion)
            }
        }
    }

    private func doFetchUVData(completion: @escaping (Float?) -> Void) {
        print("[RingCheck:UV] Step 2: Starting UV fetch via BTOriginalDataManager")
        uvDataManager = BTOriginalDataManager()

        uvDataManager?.logHandler = { msg in
            print("[RingCheck:UV:SDK] \(msg)")
        }

        let today = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: today)
        guard let year = components.year, let month = components.month, let day = components.day else {
            print("[RingCheck:UV] ❌ Failed to get date components")
            completion(nil)
            return
        }

        let timeBytes = Data([
            UInt8(max(0, year - 2000)),
            UInt8(month),
            UInt8(day),
            0x00, 0x00, 0x00
        ])

        print("[RingCheck:UV] Requesting UV data for \(year)-\(month)-\(day)")

        uvDataManager?.startReceiving(withStartTime: timeBytes, dataType: .UV, ackFrequency: 5, timeout: 30) { [weak self] data, error in
            DispatchQueue.main.async {
                self?.uvDataManager = nil
                if let error = error {
                    print("[RingCheck:UV] ❌ Error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                guard let data = data else {
                    print("[RingCheck:UV] ❌ No data returned (nil)")
                    completion(nil)
                    return
                }
                print("[RingCheck:UV] Received \(data.count) packet(s)")
                // Parse UV data
                if let resultArray = BTOriginalDataPacket().parseUVDataToResultArray(from: data) as? [[String: Any]] {
                    print("[RingCheck:UV] Parsed \(resultArray.count) entries: \(resultArray)")
                    if let lastEntry = resultArray.last,
                       let uvValue = lastEntry["uv"] as? NSNumber {
                        print("[RingCheck:UV] ✅ UV value: \(uvValue.floatValue)")
                        completion(uvValue.floatValue)
                    } else {
                        print("[RingCheck:UV] ❌ No 'uv' key in last entry, keys: \(resultArray.last?.keys.joined(separator: ", ") ?? "none")")
                        completion(nil)
                    }
                } else {
                    print("[RingCheck:UV] ❌ parseUVDataToResultArray returned nil or wrong type")
                    completion(nil)
                }
            }
        }
    }

    /// Fetch HRV for the last 7 days
    private func fetch7DayHRV(completion: @escaping ([(date: String, value: Int)]) -> Void) {
        print("[RingCheck:HRV] Starting 7-day HRV fetch")
        guard let ring = DeviceManager.shared.ring() else {
            print("[RingCheck:HRV] ❌ Ring not found")
            completion([])
            return
        }

        let calendar = Calendar.current
        let dayFmt = localizedMonthDayFormatter()

        var results: [(date: String, value: Int)] = []
        var remaining = 7
        let lock = NSLock()

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else {
                lock.lock(); remaining -= 1; lock.unlock()
                continue
            }
            let dc = calendar.dateComponents([.year, .month, .day], from: date)
            let label = dayFmt.string(from: date)

            ring.healthService.fetchHealthData(date: dc)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { result in
                    if case .failure = result {
                        lock.lock()
                        remaining -= 1
                        let done = remaining == 0
                        lock.unlock()
                        if done {
                            let sorted = results.sorted { $0.date < $1.date }
                            completion(sorted)
                        }
                    }
                }, receiveValue: { [lock] dataList in
                    let hrv = dataList.reversed().first(where: { $0.hrv > 0 })?.hrv ?? 0
                    lock.lock()
                    if hrv > 0 {
                        results.append((date: label, value: hrv))
                    }
                    remaining -= 1
                    let done = remaining == 0
                    lock.unlock()
                    if done {
                        let sorted = results.sorted { $0.date < $1.date }
                        completion(sorted)
                    }
                })
                .store(in: &measureCancellables)
        }

        // Timeout fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            lock.lock()
            let wasDone = remaining <= 0
            remaining = 0
            lock.unlock()
            if !wasDone {
                let sorted = results.sorted { $0.date < $1.date }
                completion(sorted)
            }
        }
    }

    // MARK: - Build Content

    private func rebuildContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        contentStack.addArrangedSubview(makeHeroCard())

        // Show progress card while measuring
        if case .measuring(let type) = checkState {
            contentStack.addArrangedSubview(makeMeasuringCard(currentType: type))
        }

        // Show error card on failure
        if case .failed(let message) = checkState {
            contentStack.addArrangedSubview(makeErrorCard(message: message))
        }

        // Show latest results (either from current check or previous)
        let displayResult = lastResult
        contentStack.addArrangedSubview(makeLatestCheckCard(result: displayResult))

        // Passive / accumulated data — separate cards with trends
        if hasHRVData {
            contentStack.addArrangedSubview(makeTrendCard(
                icon: "waveform.path", iconColor: AppDesign.Color.cyan,
                title: t(.ringCheckTrendHRVTitle), subtitle: t(.ringCheckTrendHRVSubtitle),
                latestValue: passiveHRV.map { "\($0)" } ?? "--", unit: t(.unitMilliseconds),
                history: hrvHistory.map { (label: $0.date, value: CGFloat($0.value)) }
            ))
        }
        if supportsUV {
            contentStack.addArrangedSubview(makeTrendCard(
                icon: "sun.max.fill", iconColor: AppDesign.Color.activity,
                title: t(.ringCheckTrendUVTitle), subtitle: t(.ringCheckTrendUVSubtitle),
                latestValue: passiveUV.map { String(format: "%.1f", $0) } ?? "--", unit: "",
                history: uvHistory.map { (label: $0.date, value: CGFloat($0.value)) }
            ))
        }

        // Activity Today card
        contentStack.addArrangedSubview(makeActivityCard())

        // Last Night Sleep card
        contentStack.addArrangedSubview(makeSleepCard())

        // Health Score placeholder card
        contentStack.addArrangedSubview(makeHealthScoreCard())

        contentStack.addArrangedSubview(makeCapabilitiesCard())
    }

    private func updateStartButton() {
        let isMeasuring: Bool
        if case .measuring = checkState { isMeasuring = true } else { isMeasuring = false }

        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)

        if isMeasuring {
            startButton.backgroundColor = UIColor.systemRed
            startButton.setTitleColor(.white, for: .normal)
            startButton.tintColor = .white
            startButton.isEnabled = true
            startButton.setImage(UIImage(systemName: "stop.fill", withConfiguration: config), for: .normal)
            startButton.setTitle("  \(t(.ringCheckStopAction))", for: .normal)
        } else {
            startButton.backgroundColor = isConnected ? themeColor : UIColor.tertiarySystemFill
            startButton.setTitleColor(isConnected ? .white : .tertiaryLabel, for: .normal)
            startButton.tintColor = isConnected ? .white : .tertiaryLabel
            startButton.isEnabled = isConnected
            startButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
            startButton.setTitle("  \(t(.ringCheckStartAction))", for: .normal)
        }
    }

    // MARK: - Measuring Progress Card

    private func makeMeasuringCard(currentType: MeasureType) -> UIView {
        let card = UIView()
        card.backgroundColor = themeColor.withAlphaComponent(0.08)
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.translatesAutoresizingMaskIntoConstraints = false

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = themeColor
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = themeColor
        label.translatesAutoresizingMaskIntoConstraints = false

        let stepIndex = measureSequence.firstIndex(of: currentType).map { $0 + 1 } ?? 0
        label.text = String(format: t(.ringCheckMeasuringFormat), displayName(for: currentType), stepIndex, measureSequence.count)

        // Progress dots
        let dotsStack = UIStackView()
        dotsStack.axis = .horizontal
        dotsStack.spacing = 8
        dotsStack.translatesAutoresizingMaskIntoConstraints = false

        for (i, type) in measureSequence.enumerated() {
            let dot = UIView()
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])

            if type == currentType {
                dot.backgroundColor = themeColor
            } else if i < stepIndex - 1 {
                dot.backgroundColor = themeColor.withAlphaComponent(0.5)
            } else {
                dot.backgroundColor = UIColor.tertiarySystemFill
            }
            dotsStack.addArrangedSubview(dot)
        }

        card.addSubview(spinner)
        card.addSubview(label)
        card.addSubview(dotsStack)

        NSLayoutConstraint.activate([
            spinner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            spinner.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            label.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 10),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),

            dotsStack.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            dotsStack.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            dotsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    // MARK: - Error Card

    private func makeErrorCard(message: String) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.systemRed.withAlphaComponent(0.08)
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: iconConfig))
        iconIV.tintColor = .systemRed
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = message
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemRed
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let retryButton = UIButton(type: .system)
        retryButton.setTitle(t(.symptomChatRetry), for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        retryButton.setTitleColor(.systemRed, for: .normal)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconIV)
        card.addSubview(label)
        card.addSubview(retryButton)

        NSLayoutConstraint.activate([
            iconIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconIV.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),

            label.leadingAnchor.constraint(equalTo: iconIV.trailingAnchor, constant: 10),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: retryButton.leadingAnchor, constant: -8),

            retryButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            retryButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    @objc private func retryTapped() {
        checkState = .idle
        rebuildContent()
        updateStartButton()
        startCheckTapped()
    }

    // MARK: - Hero Card

    private func makeHeroCard() -> UIView {
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
        iconContainer.layer.cornerRadius = 30
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: "circle.circle", withConfiguration: iconConfig))
        iconIV.tintColor = .white
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconIV)

        let titleLabel = UILabel()
        titleLabel.text = t(.ringCheckHeroName)
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = t(.ringCheckHeroDescription)
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

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

        card.addSubview(iconContainer)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(statusPill)

        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            iconContainer.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 60),
            iconContainer.heightAnchor.constraint(equalToConstant: 60),

            iconIV.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            statusPill.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusPill.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            statusPill.heightAnchor.constraint(equalToConstant: 20),

            statusDot.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            statusDot.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 8),
            statusDot.widthAnchor.constraint(equalToConstant: 6),
            statusDot.heightAnchor.constraint(equalToConstant: 6),

            statusText.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            statusText.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 6),
            statusText.trailingAnchor.constraint(equalTo: statusPill.trailingAnchor, constant: -8),

            subtitleLabel.topAnchor.constraint(equalTo: statusPill.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])

        return card
    }

    // MARK: - Latest Check Card

    private func makeLatestCheckCard(result: CheckResult?) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        card.layer.shadowOffset = AppDesign.Shadow.cardOffset
        card.layer.shadowRadius = AppDesign.Shadow.cardRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        let latestLabel = UILabel()
        latestLabel.text = t(.ringCheckLatestCheck)
        latestLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        latestLabel.textColor = .secondaryLabel
        latestLabel.translatesAutoresizingMaskIntoConstraints = false

        let latestTime = UILabel()
        if let ts = result?.timestamp {
            let fmt = localizedDateTimeFormatter()
            latestTime.text = fmt.string(from: ts)
        } else {
            latestTime.text = t(.ringCheckNoDataYet)
        }
        latestTime.font = .systemFont(ofSize: 12)
        latestTime.textColor = .tertiaryLabel
        latestTime.translatesAutoresizingMaskIntoConstraints = false

        // Vitals list — one metric per row
        let hrVal = result?.heartRate.map { String(Int($0)) } ?? "--"
        let spo2Val = result?.spo2.map { String(Int($0)) } ?? "--"
        let tempVal = result?.temperature.map { String(format: "%.1f", $0) } ?? "--"
        let items: [(icon: String, color: UIColor, title: String, value: String, unit: String)] = [
            ("heart.fill", AppDesign.Color.heartRate, t(.ringCheckMetricHeartRate), hrVal, t(.unitBpm)),
            ("lungs.fill", AppDesign.Color.bloodOxygen, t(.ringCheckMetricSpO2), spo2Val, t(.unitPercent)),
            ("thermometer.medium", AppDesign.Color.temperature, t(.ringCheckMetricTemperature), tempVal, t(.unitCelsius)),
        ]
        let vitalsStack = UIStackView()
        vitalsStack.axis = .vertical
        vitalsStack.spacing = 0
        vitalsStack.translatesAutoresizingMaskIntoConstraints = false

        for (i, item) in items.enumerated() {
            let row = makeVitalRow(icon: item.icon, iconColor: item.color, title: item.title, value: item.value, unit: item.unit)
            vitalsStack.addArrangedSubview(row)
            if i < items.count - 1 {
                let sep = UIView()
                sep.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
                sep.translatesAutoresizingMaskIntoConstraints = false
                sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                vitalsStack.addArrangedSubview(sep)
            }
        }

        card.addSubview(latestLabel)
        card.addSubview(latestTime)
        card.addSubview(vitalsStack)

        NSLayoutConstraint.activate([
            latestLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            latestLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            latestTime.centerYAnchor.constraint(equalTo: latestLabel.centerYAnchor),
            latestTime.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            vitalsStack.topAnchor.constraint(equalTo: latestLabel.bottomAnchor, constant: 12),
            vitalsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            vitalsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            vitalsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
        ])

        return card
    }

    // MARK: - Trend Card (UV / HRV)

    private func makeTrendCard(icon: String, iconColor: UIColor, title: String, subtitle: String, latestValue: String, unit: String, history: [(label: String, value: CGFloat)]) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        card.layer.shadowOffset = AppDesign.Shadow.cardOffset
        card.layer.shadowRadius = AppDesign.Shadow.cardRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        // Header row: icon + title + subtitle
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconIV.tintColor = iconColor
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .tertiaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Latest value
        let valueLabel = UILabel()
        valueLabel.text = latestValue
        valueLabel.font = .systemFont(ofSize: 34, weight: .bold)
        valueLabel.textColor = latestValue == "--" ? .tertiaryLabel : iconColor
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let unitLabel = UILabel()
        unitLabel.text = unit
        unitLabel.font = .systemFont(ofSize: 14)
        unitLabel.textColor = .secondaryLabel
        unitLabel.translatesAutoresizingMaskIntoConstraints = false

        let latestTag = UILabel()
        latestTag.text = t(.ringCheckLatestTag)
        latestTag.font = .systemFont(ofSize: 11)
        latestTag.textColor = .tertiaryLabel
        latestTag.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconIV)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(latestTag)
        card.addSubview(valueLabel)
        card.addSubview(unitLabel)

        NSLayoutConstraint.activate([
            iconIV.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            titleLabel.centerYAnchor.constraint(equalTo: iconIV.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconIV.trailingAnchor, constant: 8),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            latestTag.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 10),
            latestTag.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            valueLabel.topAnchor.constraint(equalTo: latestTag.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            unitLabel.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 4),
            unitLabel.bottomAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: -6),
        ])

        // 7-day trend chart (or "No history" message)
        if history.count >= 2 {
            let chartLabel = UILabel()
            chartLabel.text = t(.ringCheckLast7Days)
            chartLabel.font = .systemFont(ofSize: 11)
            chartLabel.textColor = .tertiaryLabel
            chartLabel.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(chartLabel)

            let chartView = TrendLineView(data: history.map { $0.value }, color: iconColor)
            chartView.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(chartView)

            // Date labels row
            let dateStack = UIStackView()
            dateStack.axis = .horizontal
            dateStack.distribution = .equalSpacing
            dateStack.translatesAutoresizingMaskIntoConstraints = false
            for point in history {
                let lbl = UILabel()
                lbl.text = point.label
                lbl.font = .systemFont(ofSize: 9)
                lbl.textColor = .tertiaryLabel
                lbl.textAlignment = .center
                dateStack.addArrangedSubview(lbl)
            }
            card.addSubview(dateStack)

            NSLayoutConstraint.activate([
                chartLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 14),
                chartLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

                chartView.topAnchor.constraint(equalTo: chartLabel.bottomAnchor, constant: 6),
                chartView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                chartView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                chartView.heightAnchor.constraint(equalToConstant: 50),

                dateStack.topAnchor.constraint(equalTo: chartView.bottomAnchor, constant: 4),
                dateStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                dateStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                dateStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            ])
        } else {
            let noDataLabel = UILabel()
            noDataLabel.text = history.isEmpty ? t(.ringCheckNoHistory) : t(.ringCheckCollectingData)
            noDataLabel.font = .systemFont(ofSize: 12)
            noDataLabel.textColor = .tertiaryLabel
            noDataLabel.numberOfLines = 0
            noDataLabel.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(noDataLabel)

            NSLayoutConstraint.activate([
                noDataLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 12),
                noDataLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                noDataLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                noDataLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            ])
        }

        return card
    }

    /// Simple inline trend line — no external dependency needed
    private class TrendLineView: UIView {
        let data: [CGFloat]
        let color: UIColor

        init(data: [CGFloat], color: UIColor) {
            self.data = data
            self.color = color
            super.init(frame: .zero)
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) { fatalError() }

        override func draw(_ rect: CGRect) {
            guard data.count >= 2, let ctx = UIGraphicsGetCurrentContext() else { return }
            let maxVal = data.max() ?? 1
            let minVal = data.min() ?? 0
            let range = max(maxVal - minVal, 1)
            let padding: CGFloat = 4
            let stepX = rect.width / CGFloat(data.count - 1)

            // Gradient fill
            let path = CGMutablePath()
            var linePoints: [CGPoint] = []
            for (i, val) in data.enumerated() {
                let x = CGFloat(i) * stepX
                let norm = (val - minVal) / range
                let y = rect.height - padding - norm * (rect.height - padding * 2)
                linePoints.append(CGPoint(x: x, y: y))
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            // Fill area
            let fillPath = path.mutableCopy()!
            fillPath.addLine(to: CGPoint(x: rect.width, y: rect.height))
            fillPath.addLine(to: CGPoint(x: 0, y: rect.height))
            fillPath.closeSubpath()

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [color.withAlphaComponent(0.25).cgColor,
                                               color.withAlphaComponent(0.0).cgColor] as CFArray,
                                      locations: [0, 1])!
            ctx.saveGState()
            ctx.addPath(fillPath)
            ctx.clip()
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: rect.height), options: [])
            ctx.restoreGState()

            // Line
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(2)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(path)
            ctx.strokePath()

            // Dots
            for pt in linePoints {
                ctx.setFillColor(color.cgColor)
                ctx.fillEllipse(in: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6))
            }
        }
    }

    // MARK: - Activity Today Card

    private func makeActivityCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        card.layer.shadowOffset = AppDesign.Shadow.cardOffset
        card.layer.shadowRadius = AppDesign.Shadow.cardRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        let sectionLabel = UILabel()
        sectionLabel.text = t(.ringCheckActivityToday)
        sectionLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        sectionLabel.textColor = .secondaryLabel
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        let stepsStr = activitySteps.map { "\($0)" } ?? "--"
        let calStr = activityCalories.map { String(format: "%.0f", $0) } ?? "--"
        let distStr = activityDistance.map { String(format: "%.2f", $0 / 1000) } ?? "--"

        let stepsView = makeActivityMetric(icon: "figure.walk", iconColor: AppDesign.Color.activity,
                                           title: t(.ringCheckSteps), value: stepsStr, unit: "")
        let calView = makeActivityMetric(icon: "flame.fill", iconColor: UIColor.systemOrange,
                                         title: t(.ringCheckCalories), value: calStr, unit: t(.unitKilocalories))
        let distView = makeActivityMetric(icon: "location.fill", iconColor: AppDesign.Color.cyan,
                                          title: t(.ringCheckDistance), value: distStr, unit: t(.unitKilometers))

        let metricsStack = UIStackView(arrangedSubviews: [stepsView, calView, distView])
        metricsStack.axis = .horizontal
        metricsStack.distribution = .fillEqually
        metricsStack.alignment = .top
        metricsStack.spacing = 0
        metricsStack.translatesAutoresizingMaskIntoConstraints = false

        // Vertical dividers
        let div1 = UIView()
        div1.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        div1.translatesAutoresizingMaskIntoConstraints = false
        let div2 = UIView()
        div2.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        div2.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(sectionLabel)
        card.addSubview(metricsStack)
        card.addSubview(div1)
        card.addSubview(div2)

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            sectionLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            metricsStack.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 8),
            metricsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            metricsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            metricsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            div1.leadingAnchor.constraint(equalTo: metricsStack.leadingAnchor,
                                          constant: (UIScreen.main.bounds.width - 40 - 16) / 3),
            div1.topAnchor.constraint(equalTo: metricsStack.topAnchor, constant: 8),
            div1.bottomAnchor.constraint(equalTo: metricsStack.bottomAnchor, constant: -8),
            div1.widthAnchor.constraint(equalToConstant: 0.5),

            div2.trailingAnchor.constraint(equalTo: metricsStack.trailingAnchor,
                                           constant: -(UIScreen.main.bounds.width - 40 - 16) / 3),
            div2.topAnchor.constraint(equalTo: metricsStack.topAnchor, constant: 8),
            div2.bottomAnchor.constraint(equalTo: metricsStack.bottomAnchor, constant: -8),
            div2.widthAnchor.constraint(equalToConstant: 0.5),
        ])

        return card
    }

    private func makeActivityMetric(icon: String, iconColor: UIColor, title: String, value: String, unit: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconIV.tintColor = iconColor
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        valueLabel.textColor = value == "--" ? .tertiaryLabel : iconColor
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let unitLabel = UILabel()
        unitLabel.text = unit
        unitLabel.font = .systemFont(ofSize: 11)
        unitLabel.textColor = .tertiaryLabel
        unitLabel.textAlignment = .center
        unitLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconIV, titleLabel, valueLabel, unitLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])

        return container
    }

    // MARK: - Sleep Card

    private func makeSleepCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        card.layer.shadowOffset = AppDesign.Shadow.cardOffset
        card.layer.shadowRadius = AppDesign.Shadow.cardRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        let sectionLabel = UILabel()
        sectionLabel.text = t(.ringCheckLastNightSleep)
        sectionLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        sectionLabel.textColor = .secondaryLabel
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(sectionLabel)

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            sectionLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
        ])

        guard let totalMin = sleepTotalMinutes, totalMin > 0 else {
            // No data state
            let noDataLabel = UILabel()
            noDataLabel.text = t(.ringCheckNoSleepData)
            noDataLabel.font = .systemFont(ofSize: 14)
            noDataLabel.textColor = .tertiaryLabel
            noDataLabel.textAlignment = .center
            noDataLabel.numberOfLines = 0
            noDataLabel.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(noDataLabel)
            NSLayoutConstraint.activate([
                noDataLabel.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 16),
                noDataLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                noDataLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                noDataLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            ])
            return card
        }

        // Total sleep time display
        let totalLabel = UILabel()
        totalLabel.text = localizedDurationString(minutes: totalMin)
        totalLabel.font = .systemFont(ofSize: 34, weight: .bold)
        totalLabel.textColor = AppDesign.Color.sleep
        totalLabel.translatesAutoresizingMaskIntoConstraints = false

        // Start/end time
        let timeRangeLabel = UILabel()
        let startStr = sleepStartTime ?? "--"
        let endStr = sleepEndTime ?? "--"
        timeRangeLabel.text = String(format: t(.ringCheckTimeRangeFormat), startStr, endStr)
        timeRangeLabel.font = .systemFont(ofSize: 13)
        timeRangeLabel.textColor = .secondaryLabel
        timeRangeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Sleep stage bar
        let stageBar = makeSleepStageBar(total: totalMin,
                                         deep: sleepDeepMinutes ?? 0,
                                         light: sleepLightMinutes ?? 0,
                                         rem: sleepREMMinutes ?? 0,
                                         awake: sleepAwakeMinutes ?? 0)
        stageBar.translatesAutoresizingMaskIntoConstraints = false

        // Stage legend
        let legendStack = makeSleepLegend(deep: sleepDeepMinutes ?? 0,
                                          light: sleepLightMinutes ?? 0,
                                          rem: sleepREMMinutes ?? 0,
                                          awake: sleepAwakeMinutes ?? 0)
        legendStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(totalLabel)
        card.addSubview(timeRangeLabel)
        card.addSubview(stageBar)
        card.addSubview(legendStack)

        NSLayoutConstraint.activate([
            totalLabel.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 8),
            totalLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            timeRangeLabel.centerYAnchor.constraint(equalTo: totalLabel.centerYAnchor),
            timeRangeLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            stageBar.topAnchor.constraint(equalTo: totalLabel.bottomAnchor, constant: 12),
            stageBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stageBar.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stageBar.heightAnchor.constraint(equalToConstant: 10),

            legendStack.topAnchor.constraint(equalTo: stageBar.bottomAnchor, constant: 10),
            legendStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            legendStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            legendStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func makeSleepStageBar(total: Int, deep: Int, light: Int, rem: Int, awake: Int) -> UIView {
        let container = UIView()
        container.layer.cornerRadius = 5
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false

        let totalF = CGFloat(max(total, 1))
        let segments: [(color: UIColor, minutes: Int)] = [
            (UIColor.systemIndigo, deep),
            (AppDesign.Color.sleep, light),
            (.systemTeal, rem),
            (.systemGray3, awake),
        ]

        var accumulated: CGFloat = 0
        let barContainer = UIView()
        barContainer.translatesAutoresizingMaskIntoConstraints = false

        for seg in segments {
            guard seg.minutes > 0 else { continue }
            let fraction = CGFloat(seg.minutes) / totalF
            let segView = UIView()
            segView.backgroundColor = seg.color
            segView.translatesAutoresizingMaskIntoConstraints = false
            barContainer.addSubview(segView)
            NSLayoutConstraint.activate([
                segView.topAnchor.constraint(equalTo: barContainer.topAnchor),
                segView.bottomAnchor.constraint(equalTo: barContainer.bottomAnchor),
                segView.leadingAnchor.constraint(equalTo: barContainer.leadingAnchor,
                                                  constant: accumulated * (UIScreen.main.bounds.width - 40 - 32)),
                segView.widthAnchor.constraint(equalTo: barContainer.widthAnchor, multiplier: fraction),
            ])
            accumulated += fraction
        }

        container.addSubview(barContainer)
        NSLayoutConstraint.activate([
            barContainer.topAnchor.constraint(equalTo: container.topAnchor),
            barContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            barContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            barContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        return container
    }

    private func makeSleepLegend(deep: Int, light: Int, rem: Int, awake: Int) -> UIStackView {
        let items: [(color: UIColor, label: String, minutes: Int)] = [
            (UIColor.systemIndigo, t(.ringCheckSleepDeep), deep),
            (AppDesign.Color.sleep, t(.ringCheckSleepLight), light),
            (.systemTeal, t(.ringCheckSleepRem), rem),
            (.systemGray3, t(.ringCheckSleepAwake), awake),
        ]
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 4

        for item in items {
            let dot = UIView()
            dot.backgroundColor = item.color
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

            let timeStr = localizedDurationString(minutes: item.minutes)
            let label = UILabel()
            label.text = "\(item.label)\n\(timeStr)"
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabel
            label.numberOfLines = 2
            label.translatesAutoresizingMaskIntoConstraints = false

            let cell = UIStackView(arrangedSubviews: [dot, label])
            cell.axis = .horizontal
            cell.spacing = 4
            cell.alignment = .center
            stack.addArrangedSubview(cell)
        }
        return stack
    }

    // MARK: - Health Score Card

    private func makeHealthScoreCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        card.layer.shadowOffset = AppDesign.Shadow.cardOffset
        card.layer.shadowRadius = AppDesign.Shadow.cardRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: "star.circle.fill", withConfiguration: iconConfig))
        iconIV.tintColor = UIColor.systemYellow
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = t(.ringCheckHealthScore)
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let messageLabel = UILabel()
        messageLabel.text = t(.ringCheckHealthScoreHint)
        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconIV)
        card.addSubview(titleLabel)
        card.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            iconIV.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            titleLabel.centerYAnchor.constraint(equalTo: iconIV.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconIV.trailingAnchor, constant: 10),

            messageLabel.topAnchor.constraint(equalTo: iconIV.bottomAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    // MARK: - Capabilities Card

    private func makeCapabilitiesCard() -> UIView {
        typealias CapabilityTag = (id: String, icon: String, title: String)
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = AppDesign.CornerRadius.card
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        card.layer.shadowOffset = AppDesign.Shadow.cardOffset
        card.layer.shadowRadius = AppDesign.Shadow.cardRadius
        card.translatesAutoresizingMaskIntoConstraints = false

        let sectionLabel = UILabel()
        sectionLabel.text = t(.ringCheckHealthMetrics)
        sectionLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        sectionLabel.textColor = .secondaryLabel
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        let specialLabel = UILabel()
        specialLabel.text = t(.ringCheckSpecialExams)
        specialLabel.font = .systemFont(ofSize: 12)
        specialLabel.textColor = .tertiaryLabel
        specialLabel.translatesAutoresizingMaskIntoConstraints = false

        let trackingLabel = UILabel()
        trackingLabel.text = t(.ringCheckContinuousTracking)
        trackingLabel.font = .systemFont(ofSize: 12)
        trackingLabel.textColor = .tertiaryLabel
        trackingLabel.translatesAutoresizingMaskIntoConstraints = false

        let specialTags: [CapabilityTag] = [
            ("ecg", "waveform.path.ecg", t(.ringDetailFeatureECGTitle)),
            ("glucose", "drop.fill", t(.ringDetailCapabilityBloodGlucoseTitle)),
            ("emotion", "face.smiling", t(.ringDetailCapabilityEmotionPPITitle)),
        ]
        let trackingTags: [CapabilityTag] = [
            ("sleep", "bed.double.fill", t(.ringDetailFeatureSleepTitle)),
            ("sport", "figure.run", t(.ringDetailFeatureSportsTitle)),
            ("steps", "figure.walk", t(.ringCheckSteps)),
            ("calories", "flame.fill", t(.ringCheckCalories)),
            ("distance", "point.topleft.down.to.point.bottomright.curvepath", t(.ringCheckDistance)),
        ]

        // Destinations for tappable tags (stable id → action)
        let tappableDestinations: [String: () -> Void] = [
            "ecg": { [weak self] in
                guard let self = self else { return }
                self.navigationController?.pushViewController(ECGCheckViewController(), animated: true)
            },
            "glucose": { [weak self] in
                guard let self = self else { return }
                self.navigationController?.pushViewController(GlucoseCheckViewController(), animated: true)
            },
            "emotion": { [weak self] in
                guard let self = self else { return }
                self.navigationController?.pushViewController(EmotionCheckViewController(), animated: true)
            },
            "sport": { [weak self] in
                guard let self = self else { return }
                self.navigationController?.pushViewController(SportViewController(), animated: true)
            },
        ]

        let tagsGrid = UIStackView()
        tagsGrid.axis = .vertical
        tagsGrid.spacing = 10
        tagsGrid.translatesAutoresizingMaskIntoConstraints = false

        let tagAccentColors: [String: UIColor] = [
            "ecg": UIColor(red: 0.4, green: 0.3, blue: 0.9, alpha: 1.0),
            "glucose": UIColor(red: 0.984, green: 0.749, blue: 0.149, alpha: 1.0),
            "emotion": AppDesign.Color.bloodOxygen,
            "sport": AppDesign.Color.activity,
        ]

        func addTagRows(tags: [CapabilityTag], to stack: UIStackView) {
            for rowStart in stride(from: 0, to: tags.count, by: 2) {
                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = 12
                row.distribution = .fillEqually

                let tagA = makeCapabilityTag(icon: tags[rowStart].icon, title: tags[rowStart].title, accentColor: tagAccentColors[tags[rowStart].id])
                if let action = tappableDestinations[tags[rowStart].id] {
                    tagA.isUserInteractionEnabled = true
                    let tap = UITapGestureRecognizer(target: nil, action: nil)
                    tap.addTarget(self, action: #selector(capabilityTagTapped(_:)))
                    tagA.addGestureRecognizer(tap)
                    tagA.accessibilityIdentifier = tags[rowStart].id
                    _ = action // capture for later use via accessibilityIdentifier
                }
                row.addArrangedSubview(tagA)

                if rowStart + 1 < tags.count {
                    let tagB = makeCapabilityTag(icon: tags[rowStart + 1].icon, title: tags[rowStart + 1].title, accentColor: tagAccentColors[tags[rowStart + 1].id])
                    if tappableDestinations[tags[rowStart + 1].id] != nil {
                        tagB.isUserInteractionEnabled = true
                        let tap = UITapGestureRecognizer(target: self, action: #selector(capabilityTagTapped(_:)))
                        tagB.addGestureRecognizer(tap)
                        tagB.accessibilityIdentifier = tags[rowStart + 1].id
                    }
                    row.addArrangedSubview(tagB)
                } else {
                    row.addArrangedSubview(UIView())
                }
                row.heightAnchor.constraint(equalToConstant: 40).isActive = true
                stack.addArrangedSubview(row)
            }
        }

        tagsGrid.addArrangedSubview(specialLabel)
        addTagRows(tags: specialTags, to: tagsGrid)

        let spacer2 = UIView()
        spacer2.heightAnchor.constraint(equalToConstant: 4).isActive = true
        tagsGrid.addArrangedSubview(spacer2)

        tagsGrid.addArrangedSubview(trackingLabel)
        addTagRows(tags: trackingTags, to: tagsGrid)

        card.addSubview(sectionLabel)
        card.addSubview(tagsGrid)

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            sectionLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            tagsGrid.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 12),
            tagsGrid.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            tagsGrid.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            tagsGrid.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    // MARK: - Helpers

    private func displayName(for type: MeasureType) -> String {
        switch type {
        case .heartRate: return t(.ringCheckMetricHeartRate)
        case .spo2: return t(.ringCheckMetricSpO2)
        case .temperature: return t(.ringCheckMetricTemperature)
        case .stress: return t(.ringCheckMetricStress)
        case .bloodPressure: return t(.ringCheckMetricBloodPressure)
        case .bodyComposition: return t(.ringCheckMetricBodyComposition)
        case .uv: return t(.ringCheckMetricUV)
        }
    }

    private func localizedClockFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("hm")
        return formatter
    }

    private func localizedMonthDayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter
    }

    private func localizedDateTimeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("MMMdhm")
        return formatter
    }

    private func localizedDurationString(minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = minutes >= 60 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropLeading]
        formatter.calendar?.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes)m"
    }

    private func makeVitalRow(icon: String, iconColor: UIColor, title: String, value: String, unit: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Colored icon circle
        let iconBg = UIView()
        iconBg.backgroundColor = iconColor.withAlphaComponent(0.12)
        iconBg.layer.cornerRadius = 16
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconIV.tintColor = iconColor
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconIV)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = value == "--" ? .tertiaryLabel : iconColor
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let unitLabel = UILabel()
        unitLabel.text = unit
        unitLabel.font = .systemFont(ofSize: 13)
        unitLabel.textColor = .secondaryLabel
        unitLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconBg)
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        container.addSubview(unitLabel)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 56),

            iconBg.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconBg.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 32),
            iconBg.heightAnchor.constraint(equalToConstant: 32),

            iconIV.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            unitLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            unitLabel.lastBaselineAnchor.constraint(equalTo: valueLabel.lastBaselineAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: unitLabel.leadingAnchor, constant: -4),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    private func makeCapabilityTag(icon: String, title: String, accentColor: UIColor? = nil) -> UIView {
        let hasAccent = accentColor != nil
        let color = accentColor ?? themeColor

        let container = UIView()
        container.backgroundColor = hasAccent ? color.withAlphaComponent(0.12) : UIColor.secondarySystemBackground
        container.layer.cornerRadius = 20
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconIV.tintColor = color
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14, weight: hasAccent ? .semibold : .medium)
        label.textColor = hasAccent ? color : .label
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

    // MARK: - Capability Tag Navigation

    @objc private func capabilityTagTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.accessibilityIdentifier else { return }
        switch tag {
        case "ecg":
            navigationController?.pushViewController(ECGCheckViewController(), animated: true)
        case "glucose":
            navigationController?.pushViewController(GlucoseCheckViewController(), animated: true)
        case "emotion":
            navigationController?.pushViewController(EmotionCheckViewController(), animated: true)
        case "sport":
            navigationController?.pushViewController(SportViewController(), animated: true)
        default:
            break
        }
    }
}
