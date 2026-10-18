import UIKit
import Combine

final class MainViewController: UIViewController {

    let themeColor = AppDesign.Color.primaryGreen
    let cardGreenColor = AppDesign.Color.darkTeal
    let metricCardColor = AppDesign.Color.metricCardOverlay
    var homeMetricCards: [HomeMetricType: HomeMetricCardViews] = [:]
    let homeMetricDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    enum HomeMetricType {
        case heartRate
        case spo2
        case stress
        case bloodPressure
    }

    struct HomeMetricCardViews {
        let titleLabel: UILabel
        let valueLabel: UILabel
        let unitLabel: UILabel
        let statusLabel: UILabel
        let statusDot: UIView
    }

    // MARK: - ScrollView

    let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    weak var healthOverviewLabel: UILabel?
    weak var aiCheckerLabel: UILabel?
    weak var quickAccessLabel: UILabel?
    var viewAllButton: UIButton?
    weak var welcomeLabelRef: UILabel?
    weak var lastCheckLabel: UILabel?
    weak var remindersTitleLabel: UILabel?
    weak var recommendedTitleLabel: UILabel?
    var recommendedSeeAllButton: UIButton?
    var quickAccessTitleLabels: [UILabel] = []
    var reminderEntries: [(title: UILabel, time: UILabel, actionView: UIView)] = []
    var articleEntries: [(tag: UILabel, title: UILabel, time: UILabel)] = []
    weak var connectedDeviceTitleLabel: UILabel?
    weak var connectedDeviceSubtitleLabel: UILabel?
    var deviceStateCancellables = Set<AnyCancellable>()

    // MARK: - Header

    let greetingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let welcomeLabel: UILabel = {
        let label = UILabel()
        label.text = nil
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    lazy var notificationButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        button.setImage(UIImage(systemName: "bell", withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    lazy var languageButton: UIButton = makeHeaderButton(symbol: "globe")
    lazy var syncButton: UIButton = makeHeaderButton(symbol: "arrow.triangle.2.circlepath")

    let badgeView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemRed
        view.layer.cornerRadius = 9
        view.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "3"
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            view.widthAnchor.constraint(equalToConstant: 18),
            view.heightAnchor.constraint(equalToConstant: 18),
        ])
        return view
    }()

    // MARK: - Health Overview Card

    let healthCardView: UIView = {
        let view = UIView()
        view.backgroundColor = AppDesign.Color.darkTeal
        view.layer.cornerRadius = 20
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var startCheckButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        let greenColor = AppDesign.Color.darkTeal
        button.setTitle(nil, for: .normal)
        button.setImage(UIImage(systemName: "viewfinder"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        button.setTitleColor(greenColor, for: .normal)
        button.tintColor = greenColor
        button.addTarget(self, action: #selector(startCheckTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - AI Symptom Checker Card

    let symptomCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.04
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let symptomInputContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let symptomInputIcon: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        imageView.tintColor = .tertiaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let symptomTextField: UITextField = {
        let field = UITextField()
        field.placeholder = nil
        field.font = .systemFont(ofSize: 14)
        field.backgroundColor = .clear
        field.textAlignment = .natural
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    lazy var analyzeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(nil, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = cardGreenColor.withAlphaComponent(0.7)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Quick Access

    let quickAccessRow1: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    let quickAccessRow2: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    let connectedDeviceBanner: UIControl = {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = AppDesign.Surface.canvasBackground
        updateGreeting()
        setupScrollView()
        setupHeader()
        setupCoachSection()
        setupHealthCard()
        setupQuickAccess()
        setupConnectedDeviceBanner()
        bindConnectedDeviceBanner()
        setupReminders()
        setupRecommended()
        updateTexts()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(recordsDidUpdate), name: .healthRecordsDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(activeProfileDidChange), name: .activeHealthProfileDidChange, object: nil)
        symptomTextField.returnKeyType = .send
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshHealthOverview()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Actions

    @objc func startCheckTapped() {
        let healthCheckVC = HealthCheckViewController()
        navigationController?.pushViewController(healthCheckVC, animated: true)
    }

    @objc func analyzeSymptomsTapped() {
        let initialText = (symptomTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        openSymptomChat(prefillText: initialText.isEmpty ? nil : initialText)
    }

    private func openSymptomChat(prefillText: String?) {
        if let tabController = tabBarController as? MainTabBarController {
            tabController.openChatTab(prefillText: prefillText)
        } else {
            let vc = SymptomChatViewController(initialMessage: prefillText)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func quickAccessItemTapped(_ sender: UIButton) {
        switch sender.tag {
        case 101: // AI检测 -> RPPG
            startCheckTapped()
        case 102: // 问诊咨询 -> AI对话
            openSymptomChat(prefillText: nil)
        case 103: // 医疗 -> 全球医疗评估/申请 (CareApplicationViewController)
            let vc = CareApplicationViewController()
            navigationController?.pushViewController(vc, animated: true)
        case 104: // 健康档案 -> 切换到健康 Tab
            if let tabController = tabBarController as? MainTabBarController {
                tabController.openHealthTab()
            } else {
                tabBarController?.selectedIndex = MainTabBarController.Tab.health.rawValue
            }
        case 105: // 健康内容 -> OCR/report history entry
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            navigationController?.pushViewController(
                OcrHistoryListViewController(dateFormatter: formatter),
                animated: true
            )
        case 107:
            let vc = AndroidNutritionCenterViewController()
            navigationController?.pushViewController(vc, animated: true)
        case 106: // 设备 -> 我的设备 (MyDevicesViewController)
            let vc = DeviceCenterViewController()
            navigationController?.pushViewController(vc, animated: true)
        case 108: // 公益 -> keep the route explicit without manufacturing a service
            let alert = UIAlertController(title: "公益服务", message: "公益项目入口将在服务方接入后开放。当前不会提交任何捐赠。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
        default:
            let alert = UIAlertController(
                title: "入口暂不可用",
                message: "该功能尚未接入 iOS 服务，不会执行未确认的操作。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
            present(alert, animated: true)
        }
    }

    @objc func homeNotificationsTapped() {
        navigationController?.pushViewController(AndroidNotificationSettingsViewController(), animated: true)
    }

    @objc func homeLanguageTapped() {
        navigationController?.pushViewController(AndroidLanguageSettingsViewController(), animated: true)
    }

    @objc func homeSyncTapped() {
        syncButton.isEnabled = false
        SyncEngine.shared.syncNow { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.syncButton.isEnabled = true
                let alert = UIAlertController(title: "同步状态", message: "已请求同步本地健康记录；不会上传未确认的演示数据。", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "知道了", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    private func makeHeaderButton(symbol: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18)), for: .normal)
        button.tintColor = .label
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 36).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }

    @objc func homeProfileTapped() {
        if let tabController = tabBarController as? MainTabBarController {
            tabController.selectedIndex = MainTabBarController.Tab.profile.rawValue
        }
    }

    @objc func connectedDeviceBannerTapped() {
        navigationController?.pushViewController(DeviceCenterViewController(), animated: true)
    }

    @objc func recommendedSeeAllTapped() {
        navigationController?.pushViewController(AndroidNutritionCenterViewController(), animated: true)
    }

    func bindConnectedDeviceBanner() {
        refreshConnectedDeviceBanner()
        DeviceManager.shared.connectionStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshConnectedDeviceBanner() }
            .store(in: &deviceStateCancellables)
    }

    func refreshConnectedDeviceBanner() {
        let manager = DeviceManager.shared
        let connected = manager.registeredTypes.filter { manager.device(for: $0)?.isConnected() == true }
        if connected.isEmpty {
            connectedDeviceTitleLabel?.text = "已连接设备"
            connectedDeviceSubtitleLabel?.text = "暂无在线设备 · 点击添加 Alloop、AIZORING、Robot 或 JDY-23"
            connectedDeviceBanner.accessibilityValue = "0 台在线"
            return
        }
        let names = connected.map { type -> String in
            switch type {
            case .ring: return "Alloop / AIZORING"
            case .robot: return "vvewell Robot"
            case .radar: return "JDY-23"
            case .watch: return "智能手表"
            case .band: return "健康手环"
            case .thermalCamera: return "红外不可用"
            }
        }
        connectedDeviceTitleLabel?.text = "已连接设备 · \(connected.count) 台在线"
        connectedDeviceSubtitleLabel?.text = names.joined(separator: "、")
        connectedDeviceBanner.accessibilityValue = names.joined(separator: ", ")
    }
}
