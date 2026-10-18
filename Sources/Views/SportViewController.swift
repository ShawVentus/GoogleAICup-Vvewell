import UIKit
import RingSDK
import Combine
import CoreMotion

class SportViewController: UIViewController {

    // MARK: - State

    private enum SportState {
        case idle
        case active(sportID: Data, type: SportType, elapsed: Int)
        case paused(sportID: Data, type: SportType, elapsed: Int)
        case completed(summary: SportSummary)
        case failed(String)
    }

    private var state: SportState = .idle
    private var selectedSportType: SportType = .indoorWalk
    private var elapsedSeconds = 0
    private var timer: Timer?
    private var realTimeData: SportRealTimeData?
    private var summaryData: SportSummary?
    private var cancellables = Set<AnyCancellable>()
    private let sportService = RingSportService()

    // Core Motion pedometer — fallback/supplement for data Ring doesn't return
    private let pedometer = CMPedometer()
    private var pedometerSteps: Int = 0
    private var pedometerDistance: Int = 0       // meters
    private var pedometerCalories: Int = 0       // estimated
    private var pedometerCurrentPace: Double = 0 // seconds per meter (speed = 1/pace)
    private var pedometerCadence: Double = 0     // steps per second
    private var pedometerAvgPace: Double = 0     // seconds per meter (average)
    private var pedometerFloorsUp: Int = 0
    private var pedometerFloorsDown: Int = 0

    // MARK: - Sport Types

    private let sportTypes: [(type: SportType, icon: String)] = [
        (.indoorWalk, "figure.walk"),
        (.indoorBike, "bicycle"),
        (.indoorRun, "figure.run"),
        (.outdoorWalk, "figure.walk"),
        (.outdoorRun, "figure.run"),
        (.outdoorBike, "bicycle"),
    ]

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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = t(.sportTrackingTitle)
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
        title = t(.sportTrackingTitle)
        rebuildContent()
        updateStartButton()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
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

        switch state {
        case .idle:
            contentStack.addArrangedSubview(makeSportPickerCard())
        case .active(_, let type, let elapsed):
            contentStack.addArrangedSubview(makeActiveSessionCard(type: type, elapsed: elapsed))
            if let rt = realTimeData {
                contentStack.addArrangedSubview(makeRealTimeCard(data: rt))
            }
        case .paused(_, let type, let elapsed):
            contentStack.addArrangedSubview(makePausedCard(type: type, elapsed: elapsed))
        case .completed(let summary):
            contentStack.addArrangedSubview(makeSportPickerCard())
            contentStack.addArrangedSubview(makeSummaryCard(summary: summary))
        case .failed(let message):
            contentStack.addArrangedSubview(makeSportPickerCard())
            contentStack.addArrangedSubview(makeErrorCard(message: message))
        }
    }

    private func updateStartButton() {
        let isConnected = BTService.shared().isConnected
        let accentColor = AppDesign.Color.activity

        switch state {
        case .idle, .completed, .failed:
            startButton.backgroundColor = isConnected ? accentColor : .tertiarySystemFill
            startButton.setTitleColor(isConnected ? .white : .tertiaryLabel, for: .normal)
            startButton.tintColor = isConnected ? .white : .tertiaryLabel
            startButton.isEnabled = isConnected
            startButton.setTitle(t(.sportStart), for: .normal)
        case .active:
            startButton.backgroundColor = .systemOrange
            startButton.setTitleColor(.white, for: .normal)
            startButton.isEnabled = true
            startButton.setTitle(t(.sportPause), for: .normal)
        case .paused:
            startButton.backgroundColor = accentColor
            startButton.setTitleColor(.white, for: .normal)
            startButton.isEnabled = true
            startButton.setTitle(t(.sportResume), for: .normal)
        }
    }

    // MARK: - Actions

    @objc private func startTapped() {
        switch state {
        case .idle, .completed, .failed:
            startSport()
        case .active(let sportID, let type, let elapsed):
            pauseSport(sportID: sportID, type: type, elapsed: elapsed)
        case .paused(let sportID, let type, let elapsed):
            resumeSport(sportID: sportID, type: type, elapsed: elapsed)
        }
    }

    @objc private func stopTapped() {
        switch state {
        case .active(let sportID, _, let elapsed), .paused(let sportID, _, let elapsed):
            stopSport(sportID: sportID, elapsed: elapsed)
        default:
            break
        }
    }

    private func startSport() {
        guard BTService.shared().isConnected else {
            showAlert(title: t(.deviceCheckNotConnectedTitle), message: t(.sportNotConnectedMessage))
            return
        }

        let sdkType = BTSportType(rawValue: UInt8(selectedSportType.rawValue)) ?? .indoorWalk
        let sportID = BTSport.generateId()
        elapsedSeconds = 0
        realTimeData = nil

        BTService.shared().sportReq.execute(.start, sportWith: sdkType, sportID: sportID) { [weak self] status in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if status != nil {
                    self.state = .active(sportID: sportID, type: self.selectedSportType, elapsed: 0)
                    self.rebuildContent()
                    self.updateStartButton()
                    self.startPedometer()
                    self.startTimer(sportID: sportID)
                } else {
                    self.state = .failed(t(.sportStartFailed))
                    self.rebuildContent()
                    self.updateStartButton()
                }
            }
        }
    }

    private func pauseSport(sportID: Data, type: SportType, elapsed: Int) {
        timer?.invalidate()
        timer = nil
        BTService.shared().sportReq.execute(.pause, sportWith: BTSportType(rawValue: UInt8(type.rawValue)) ?? .indoorWalk, sportID: sportID) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.state = .paused(sportID: sportID, type: type, elapsed: elapsed)
                self.rebuildContent()
                self.updateStartButton()
            }
        }
    }

    private func resumeSport(sportID: Data, type: SportType, elapsed: Int) {
        BTService.shared().sportReq.execute(.resume, sportWith: BTSportType(rawValue: UInt8(type.rawValue)) ?? .indoorWalk, sportID: sportID) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.state = .active(sportID: sportID, type: type, elapsed: elapsed)
                self.rebuildContent()
                self.updateStartButton()
                self.startTimer(sportID: sportID)
            }
        }
    }

    private func stopSport(sportID: Data, elapsed: Int) {
        timer?.invalidate()
        timer = nil
        stopPedometer()
        let type: BTSportType
        if case .active(_, let sType, _) = state {
            type = BTSportType(rawValue: UInt8(sType.rawValue)) ?? .indoorWalk
        } else if case .paused(_, let sType, _) = state {
            type = BTSportType(rawValue: UInt8(sType.rawValue)) ?? .indoorWalk
        } else {
            type = .indoorWalk
        }

        BTService.shared().sportReq.execute(.stop, sportWith: type, sportID: sportID) { [weak self] _ in
            guard let self = self else { return }
            BTService.shared().sportReq.requestSummary(sportID) { model in
                DispatchQueue.main.async {
                    if let model = model {
                        let summary = SportSummary(
                            sportType: SportType(rawValue: Int(model.sportType)) ?? .indoorWalk,
                            duration: Int(model.duration),
                            calories: self.effectiveCalories(ring: Int(model.calories)),
                            steps: self.effectiveSteps(ring: Int(model.steps)),
                            distance: self.effectiveDistance(ring: Int(model.distance)),
                            avgHeartRate: Int(model.avgHr),
                            avgPace: Int(model.avgPace)
                        )
                        self.state = .completed(summary: summary)
                    } else {
                        self.state = .idle
                    }
                    self.rebuildContent()
                    self.updateStartButton()
                }
            }
        }
    }

    // MARK: - Pedometer (iPhone fallback for steps/distance/calories)

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("[Sport] Pedometer not available on this device")
            return
        }
        pedometerSteps = 0
        pedometerDistance = 0
        pedometerCalories = 0
        pedometerCurrentPace = 0
        pedometerCadence = 0
        pedometerAvgPace = 0
        pedometerFloorsUp = 0
        pedometerFloorsDown = 0

        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            DispatchQueue.main.async {
                self.pedometerSteps = data.numberOfSteps.intValue
                self.pedometerDistance = data.distance?.intValue ?? 0
                self.pedometerFloorsUp = data.floorsAscended?.intValue ?? 0
                self.pedometerFloorsDown = data.floorsDescended?.intValue ?? 0

                // currentPace: seconds per meter → speed in km/h = 3600 / (pace * 1000)
                if let pace = data.currentPace?.doubleValue, pace > 0 {
                    self.pedometerCurrentPace = pace
                }
                // currentCadence: steps per second → steps per minute = cadence * 60
                if let cadence = data.currentCadence?.doubleValue, cadence > 0 {
                    self.pedometerCadence = cadence
                }
                // averageActivePace: seconds per meter (overall average)
                if let avgPace = data.averageActivePace?.doubleValue, avgPace > 0 {
                    self.pedometerAvgPace = avgPace
                }

                // Calorie estimate: MET-based (walking ~3.5 MET, running ~8 MET)
                // Simplified: ~0.04 kcal/step (walking), ~0.07 kcal/step (running pace < 2 s/m)
                let kcalPerStep: Double = self.pedometerCurrentPace > 0 && self.pedometerCurrentPace < 2.0 ? 0.07 : 0.04
                self.pedometerCalories = Int(Double(self.pedometerSteps) * kcalPerStep)
            }
        }
        print("[Sport] Pedometer started (iPhone supplement)")
    }

    private func stopPedometer() {
        pedometer.stopUpdates()
        print("[Sport] Pedometer stopped. Steps=\(pedometerSteps) Distance=\(pedometerDistance)m Calories=\(pedometerCalories) AvgPace=\(pedometerAvgPace) Cadence=\(pedometerCadence) FloorsUp=\(pedometerFloorsUp) FloorsDown=\(pedometerFloorsDown)")
    }

    /// Returns the best available value: Ring data if > 0, otherwise iPhone pedometer
    private func effectiveSteps(ring: Int) -> Int { ring > 0 ? ring : pedometerSteps }
    private func effectiveDistance(ring: Int) -> Int { ring > 0 ? ring : pedometerDistance }
    private func effectiveCalories(ring: Int) -> Int { ring > 0 ? ring : pedometerCalories }

    private func startTimer(sportID: Data) {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedSeconds += 1
            if case .active(let sid, let type, _) = self.state {
                self.state = .active(sportID: sid, type: type, elapsed: self.elapsedSeconds)
                // Fetch real-time data every 5 seconds
                if self.elapsedSeconds % 5 == 0 {
                    BTService.shared().sportReq.requestRealTimeData(forSport: sportID) { model in
                        guard let model = model else { return }
                        DispatchQueue.main.async {
                            // Keep previous HR/temp if new value is 0 (sensor blip)
                            let prevHR = self.realTimeData?.heartRate ?? 0
                            let prevTemp = self.realTimeData?.temperature ?? 0
                            let newHR = Int(model.heartRate)
                            let newTemp = model.temperature

                            self.realTimeData = SportRealTimeData(
                                heartRate: newHR > 0 ? newHR : prevHR,
                                calories: self.effectiveCalories(ring: Int(model.calories)),
                                steps: self.effectiveSteps(ring: Int(model.steps)),
                                distance: self.effectiveDistance(ring: Int(model.distance)),
                                pace: Int(model.pace),
                                cadence: Int(model.cadence),
                                temperature: newTemp > 0 ? newTemp : prevTemp
                            )
                            self.rebuildContent()
                        }
                    }
                } else {
                    self.rebuildContent()
                }
            }
        }
    }

    // MARK: - Card Builders

    private func makeSportPickerCard() -> UIView {
        let card = makeCard()
        let titleLabel = makeLabel(t(.sportSelectSport), font: .systemFont(ofSize: 15, weight: .semibold), color: .label)
        card.addSubview(titleLabel)

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10
        grid.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(grid)

        for rowStart in stride(from: 0, to: sportTypes.count, by: 3) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            row.distribution = .fillEqually

            for col in 0..<3 {
                let idx = rowStart + col
                if idx < sportTypes.count {
                    let item = sportTypes[idx]
                    row.addArrangedSubview(makeSportTypeCell(type: item.type, icon: item.icon, label: sportLabel(for: item.type)))
                } else {
                    row.addArrangedSubview(UIView())
                }
            }
            grid.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            grid.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            grid.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            grid.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            grid.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
        return card
    }

    private func makeSportTypeCell(type: SportType, icon: String, label: String) -> UIView {
        let isSelected = type == selectedSportType
        let container = UIView()
        container.backgroundColor = isSelected ? AppDesign.Color.activity.withAlphaComponent(0.15) : .secondarySystemBackground
        container.layer.cornerRadius = AppDesign.CornerRadius.button
        container.layer.borderWidth = isSelected ? 1.5 : 0
        container.layer.borderColor = isSelected ? AppDesign.Color.activity.cgColor : UIColor.clear.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconIV.tintColor = isSelected ? AppDesign.Color.activity : .secondaryLabel
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let lbl = makeLabel(label, font: .systemFont(ofSize: 11, weight: .medium), color: isSelected ? .label : .secondaryLabel)
        lbl.textAlignment = .center
        lbl.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [iconIV, lbl])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -4),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(sportTypeTapped(_:)))
        container.addGestureRecognizer(tap)
        container.tag = type.rawValue

        return container
    }

    @objc private func sportTypeTapped(_ gesture: UITapGestureRecognizer) {
        guard case .idle = state else { return }
        guard let rawValue = gesture.view?.tag,
              let type = SportType(rawValue: rawValue) else { return }
        selectedSportType = type
        rebuildContent()
    }

    private func makeActiveSessionCard(type: SportType, elapsed: Int) -> UIView {
        let card = makeCard()
        let accentColor = AppDesign.Color.activity
        card.backgroundColor = accentColor.withAlphaComponent(0.06)

        let typeLabel = makeLabel(sportLabel(for: type), font: .systemFont(ofSize: 17, weight: .bold), color: .label)
        let timeLabel = makeLabel(formatTime(elapsed), font: .monospacedSystemFont(ofSize: 40, weight: .bold), color: accentColor)
        let subLabel = makeLabel(t(.sportElapsedTime), font: .systemFont(ofSize: 12), color: .secondaryLabel)

        let stopBtn = UIButton(type: .system)
        stopBtn.setTitle(t(.sportStop), for: .normal)
        stopBtn.setTitleColor(.systemRed, for: .normal)
        stopBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        stopBtn.layer.cornerRadius = AppDesign.CornerRadius.button
        stopBtn.layer.borderWidth = 1.5
        stopBtn.layer.borderColor = UIColor.systemRed.cgColor
        stopBtn.translatesAutoresizingMaskIntoConstraints = false
        stopBtn.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)

        card.addSubview(typeLabel)
        card.addSubview(timeLabel)
        card.addSubview(subLabel)
        card.addSubview(stopBtn)

        NSLayoutConstraint.activate([
            typeLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            typeLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            timeLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 8),
            timeLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            subLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 2),
            subLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            stopBtn.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 16),
            stopBtn.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stopBtn.widthAnchor.constraint(equalToConstant: 100),
            stopBtn.heightAnchor.constraint(equalToConstant: 36),
            stopBtn.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        return card
    }

    private func makePausedCard(type: SportType, elapsed: Int) -> UIView {
        let card = makeCard()
        card.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.06)

        let typeLabel = makeLabel(sportLabel(for: type), font: .systemFont(ofSize: 17, weight: .bold), color: .label)
        let timeLabel = makeLabel(formatTime(elapsed), font: .monospacedSystemFont(ofSize: 40, weight: .bold), color: .systemOrange)
        let pausedLabel = makeLabel(t(.sportPaused).uppercased(), font: .systemFont(ofSize: 12, weight: .semibold), color: .systemOrange)

        let stopBtn = UIButton(type: .system)
        stopBtn.setTitle(t(.sportStop), for: .normal)
        stopBtn.setTitleColor(.systemRed, for: .normal)
        stopBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        stopBtn.layer.cornerRadius = AppDesign.CornerRadius.button
        stopBtn.layer.borderWidth = 1.5
        stopBtn.layer.borderColor = UIColor.systemRed.cgColor
        stopBtn.translatesAutoresizingMaskIntoConstraints = false
        stopBtn.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)

        card.addSubview(typeLabel)
        card.addSubview(timeLabel)
        card.addSubview(pausedLabel)
        card.addSubview(stopBtn)

        NSLayoutConstraint.activate([
            typeLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            typeLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            timeLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 8),
            timeLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            pausedLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 2),
            pausedLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            stopBtn.topAnchor.constraint(equalTo: pausedLabel.bottomAnchor, constant: 16),
            stopBtn.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stopBtn.widthAnchor.constraint(equalToConstant: 100),
            stopBtn.heightAnchor.constraint(equalToConstant: 36),
            stopBtn.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        return card
    }

    private func makeRealTimeCard(data: SportRealTimeData) -> UIView {
        let card = makeCard()
        let titleLabel = makeLabel(t(.sportLiveData), font: .systemFont(ofSize: 13, weight: .semibold), color: .secondaryLabel)

        let tempStr = data.temperature > 0 ? String(format: "%.1f", data.temperature) : "--"

        // Speed from iPhone pace: km/h = 3600 / (pace_sec_per_meter * 1000)
        let speedStr: String
        if pedometerCurrentPace > 0 {
            let kmh = 3.6 / pedometerCurrentPace  // 1 m/s = 3.6 km/h
            speedStr = String(format: "%.1f", kmh)
        } else { speedStr = "--" }

        // Cadence from iPhone: steps/min = cadence * 60
        let cadenceStr: String
        if pedometerCadence > 0 {
            cadenceStr = "\(Int(pedometerCadence * 60))"
        } else { cadenceStr = "--" }

        // Avg stride length: distance / steps (meters)
        let strideStr: String
        if pedometerSteps > 0 && pedometerDistance > 0 {
            let stride = Double(pedometerDistance) / Double(pedometerSteps)
            strideStr = String(format: "%.2f", stride)
        } else { strideStr = "--" }

        // Ring data
        let ringMetrics: [(icon: String, color: UIColor, label: String, value: String, unit: String)] = [
            ("heart.fill", AppDesign.Color.heartRate, t(.ringCheckMetricHeartRate), data.heartRate > 0 ? "\(data.heartRate)" : "--", t(.unitBpm)),
            ("thermometer.medium", AppDesign.Color.temperature, t(.sportMetricTemperatureShort), tempStr, t(.unitCelsius)),
        ]

        // iPhone + computed data
        let phoneMetrics: [(icon: String, color: UIColor, label: String, value: String, unit: String)] = [
            ("figure.walk", AppDesign.Color.stress, t(.ringCheckSteps), data.steps > 0 ? "\(data.steps)" : "--", ""),
            ("point.topleft.down.to.point.bottomright.curvepath", AppDesign.Color.bloodOxygen, t(.ringCheckDistance), data.distance > 0 ? "\(data.distance)" : "--", t(.unitMeters)),
            ("flame.fill", AppDesign.Color.activity, t(.ringCheckCalories), data.calories > 0 ? "\(data.calories)" : "--", t(.unitKilocalories)),
            ("speedometer", AppDesign.Color.cyan, t(.sportMetricSpeed), speedStr, t(.unitKilometersPerHour)),
            ("metronome", AppDesign.Color.sleep, t(.sportMetricCadence), cadenceStr, t(.unitStepsPerMinute)),
            ("ruler", AppDesign.Color.temperature, t(.sportMetricStride), strideStr, t(.unitMeters)),
        ]

        // Section: Ring
        let ringLabel = makeLabel(t(.sportRing), font: .systemFont(ofSize: 11, weight: .semibold), color: .tertiaryLabel)

        let ringRow = UIStackView()
        ringRow.axis = .horizontal
        ringRow.distribution = .fillEqually
        ringRow.spacing = 8
        ringRow.translatesAutoresizingMaskIntoConstraints = false
        for m in ringMetrics {
            ringRow.addArrangedSubview(makeMetricCell(icon: m.icon, color: m.color, label: m.label, value: m.value, unit: m.unit))
        }

        // Section: iPhone
        let phoneLabel = makeLabel(t(.sportPhone), font: .systemFont(ofSize: 11, weight: .semibold), color: .tertiaryLabel)

        var phoneRows: [UIStackView] = []
        for rowStart in stride(from: 0, to: phoneMetrics.count, by: 3) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 8
            row.translatesAutoresizingMaskIntoConstraints = false
            for i in rowStart..<min(rowStart + 3, phoneMetrics.count) {
                let m = phoneMetrics[i]
                row.addArrangedSubview(makeMetricCell(icon: m.icon, color: m.color, label: m.label, value: m.value, unit: m.unit))
            }
            // Balance incomplete row
            let remainder = min(rowStart + 3, phoneMetrics.count) - rowStart
            if remainder < 3 {
                for _ in 0..<(3 - remainder) { row.addArrangedSubview(UIView()) }
            }
            phoneRows.append(row)
        }

        card.addSubview(titleLabel)
        card.addSubview(ringLabel)
        card.addSubview(ringRow)
        card.addSubview(phoneLabel)
        for r in phoneRows { card.addSubview(r) }

        var constraints = [
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            ringLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            ringLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            ringRow.topAnchor.constraint(equalTo: ringLabel.bottomAnchor, constant: 6),
            ringRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            ringRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            phoneLabel.topAnchor.constraint(equalTo: ringRow.bottomAnchor, constant: 12),
            phoneLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
        ]

        var prevAnchor = phoneLabel.bottomAnchor
        for (i, row) in phoneRows.enumerated() {
            constraints.append(contentsOf: [
                row.topAnchor.constraint(equalTo: prevAnchor, constant: 6),
                row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
                row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            ])
            prevAnchor = row.bottomAnchor
            if i == phoneRows.count - 1 {
                constraints.append(row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12))
            }
        }

        NSLayoutConstraint.activate(constraints)
        return card
    }

    private func makeSummaryCard(summary: SportSummary) -> UIView {
        let card = makeCard()
        let titleLabel = makeLabel(t(.sportSessionSummary), font: .systemFont(ofSize: 15, weight: .semibold), color: .label)
        let typeLabel = makeLabel(sportLabel(for: summary.sportType), font: .systemFont(ofSize: 13), color: .secondaryLabel)

        let metrics: [(label: String, value: String, unit: String)] = [
            (t(.sportElapsedTime), formatTime(summary.duration), ""),
            (t(.ringCheckCalories), summary.calories > 0 ? "\(summary.calories)" : "--", t(.unitKilocalories)),
            (t(.ringCheckSteps), summary.steps > 0 ? "\(summary.steps)" : "--", ""),
            (t(.ringCheckDistance), summary.distance > 0 ? "\(summary.distance)" : "--", t(.unitMeters)),
            (t(.ecgMetricAvgHR), summary.avgHeartRate > 0 ? "\(summary.avgHeartRate)" : "--", t(.unitBpm)),
            (t(.sportAveragePace), summary.avgPace > 0 ? "\(summary.avgPace)" : "--", t(.unitMinutesPerKilometer)),
        ]

        let row1 = UIStackView()
        row1.axis = .horizontal
        row1.distribution = .fillEqually
        row1.spacing = 8
        row1.translatesAutoresizingMaskIntoConstraints = false

        let row2 = UIStackView()
        row2.axis = .horizontal
        row2.distribution = .fillEqually
        row2.spacing = 8
        row2.translatesAutoresizingMaskIntoConstraints = false

        for (i, m) in metrics.enumerated() {
            let cell = makeSummaryCell(label: m.label, value: m.value, unit: m.unit)
            if i < 3 { row1.addArrangedSubview(cell) } else { row2.addArrangedSubview(cell) }
        }

        card.addSubview(titleLabel)
        card.addSubview(typeLabel)
        card.addSubview(row1)
        card.addSubview(row2)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            typeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            typeLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            row1.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 12),
            row1.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            row1.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            row2.topAnchor.constraint(equalTo: row1.bottomAnchor, constant: 8),
            row2.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            row2.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            row2.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
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

    // MARK: - Cell Builders

    private func makeMetricCell(icon: String, color: UIColor, label: String, value: String, unit: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = AppDesign.CornerRadius.button
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 80).isActive = true

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iv = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iv.tintColor = color
        iv.translatesAutoresizingMaskIntoConstraints = false

        let lbl = makeLabel(label, font: .systemFont(ofSize: 11), color: .secondaryLabel)
        let valLbl = makeLabel(value, font: .systemFont(ofSize: 22, weight: .bold), color: .label)
        let unitLbl = makeLabel(unit, font: .systemFont(ofSize: 11), color: .secondaryLabel)

        let topRow = UIStackView(arrangedSubviews: [iv, lbl])
        topRow.axis = .horizontal
        topRow.spacing = 4
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(topRow)
        container.addSubview(valLbl)
        container.addSubview(unitLbl)

        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            topRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),

            valLbl.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 4),
            valLbl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),

            unitLbl.topAnchor.constraint(equalTo: valLbl.bottomAnchor, constant: 2),
            unitLbl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
        ])
        return container
    }

    private func makeSummaryCell(label: String, value: String, unit: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = AppDesign.CornerRadius.button
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let lbl = makeLabel(label, font: .systemFont(ofSize: 11), color: .secondaryLabel)
        lbl.textAlignment = .center
        let valLbl = makeLabel(value, font: .systemFont(ofSize: 20, weight: .bold), color: .label)
        valLbl.textAlignment = .center
        let unitLbl = makeLabel(unit, font: .systemFont(ofSize: 10), color: .secondaryLabel)
        unitLbl.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [lbl, valLbl, unitLbl])
        stack.axis = .vertical
        stack.spacing = 1
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
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

    private func formatTime(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        formatter.calendar?.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        return formatter.string(from: TimeInterval(seconds)) ?? "00:00"
    }

    private func sportLabel(for type: SportType) -> String {
        switch type {
        case .indoorWalk: return t(.sportTypeIndoorWalk)
        case .indoorBike: return t(.sportTypeIndoorBike)
        case .indoorRun: return t(.sportTypeIndoorRun)
        case .outdoorWalk: return t(.sportTypeOutdoorWalk)
        case .outdoorRun: return t(.sportTypeOutdoorRun)
        case .outdoorBike: return t(.sportTypeOutdoorBike)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
        present(alert, animated: true)
    }
}
