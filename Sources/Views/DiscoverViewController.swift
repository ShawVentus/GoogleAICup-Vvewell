import UIKit

final class DiscoverViewController: UIViewController {

    // MARK: - Theme Colors

    private let themeColor = AppDesign.Color.primaryGreen
    private let darkTealColor = AppDesign.Color.darkTeal

    // MARK: - UI Components for Incremental Updates

    // Header
    private let headerTitleLabel = UILabel()
    private let headerSubtitleLabel = UILabel()
    // Emergency Banner
    private let emergencyTitleLabel = UILabel()
    private let emergencyDetailLabel = UILabel()
    private let emergencyCallButton = UIButton(type: .system)

    // Active Service Orders
    private let activeOrdersSectionTitle = UILabel()
    private let activeOrderNumberLabel = UILabel()
    private let activeOrderStatusBadgeLabel = UILabel()
    private let activeHospitalLabel = UILabel()
    private let activeLocationLabel = UILabel()
    private let activeProgressTitleLabel = UILabel()
    private let activeStepLabel = UILabel()
    private weak var activeOrderChevronView: UIImageView?

    // Service Process
    private let serviceProcessSectionTitle = UILabel()
    private let processStep1TitleLabel = UILabel()
    private let processStep1ItemsLabels: [UILabel] = [UILabel(), UILabel(), UILabel()]
    private let processStep2TitleLabel = UILabel()
    private let processStep2ItemsLabels: [UILabel] = [UILabel(), UILabel(), UILabel()]
    private let processStep3TitleLabel = UILabel()
    private let processStep3ItemsLabels: [UILabel] = [UILabel(), UILabel(), UILabel()]

    // AI Assessment
    private let aiTitleLabel = UILabel()
    private let aiDescLabel = UILabel()
    private let aiStartButton = UIButton(type: .system)

    // Service Packages
    private let packagesSectionTitle = UILabel()
    private let charityButton = UIButton(type: .system)
    
    // Package Cards (we'll update their content if they are stored or accessible)
    private var packageCardViews: [PackageCardUI] = []
    
    // Partner Hospitals
    private let hospitalsSectionTitle = UILabel()
    private var hospitalCardViews: [HospitalCardUI] = []
    private let viewAllHospitalsButton = UIButton(type: .system)

    // Bottom Stats
    private var statItemsLabels: [(title: UILabel, subtitle: UILabel)] = []

    // MARK: - ScrollView

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = .secondarySystemBackground
        setupScrollView()
        setupHeader()
        setupEmergencyBanner()
        setupActiveServiceOrders()
        setupServiceProcess()
        setupAIAssessment()
        setupServicePackages()
        setupPartnerHospitals()
        setupBottomStats()
        addBottomSpacer()
        
        updateTexts() // Initial text setup
        
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup ScrollView

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])
    }

    // MARK: - Header

    private func setupHeader() {
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false

        // Icon circle
        let iconCircle = UIView()
        iconCircle.backgroundColor = darkTealColor
        iconCircle.layer.cornerRadius = 22
        iconCircle.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: "airplane", withConfiguration: iconConfig))
        iconIV.tintColor = .white
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconIV)

        headerTitleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        headerTitleLabel.textColor = .label
        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        headerSubtitleLabel.font = .systemFont(ofSize: 15)
        headerSubtitleLabel.textColor = .secondaryLabel
        headerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(iconCircle)
        headerView.addSubview(headerTitleLabel)
        headerView.addSubview(headerSubtitleLabel)

        NSLayoutConstraint.activate([
            headerView.heightAnchor.constraint(equalToConstant: 60),

            iconCircle.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            iconCircle.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 4),
            iconCircle.widthAnchor.constraint(equalToConstant: 44),
            iconCircle.heightAnchor.constraint(equalToConstant: 44),

            iconIV.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),

            headerTitleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 4),
            headerTitleLabel.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 12),

            headerSubtitleLabel.topAnchor.constraint(equalTo: headerTitleLabel.bottomAnchor, constant: 4),
            headerSubtitleLabel.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 12),
            headerSubtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor),
            headerTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor),
        ])

        contentStack.addArrangedSubview(headerView)
    }

    // MARK: - Emergency Banner

    private func setupEmergencyBanner() {
        let banner = UIView()
        banner.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.25, green: 0.18, blue: 0.10, alpha: 1.0)
                : UIColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 1.0)
        }
        banner.layer.cornerRadius = 16
        banner.layer.borderWidth = 1
        banner.layer.borderColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.45, green: 0.32, blue: 0.18, alpha: 1.0)
                : UIColor(red: 1.0, green: 0.9, blue: 0.75, alpha: 1.0)
        }.cgColor
        banner.translatesAutoresizingMaskIntoConstraints = false

        // Phone icon circle
        let phoneCircle = UIView()
        phoneCircle.backgroundColor = UIColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 0.15)
        phoneCircle.layer.cornerRadius = 18
        phoneCircle.translatesAutoresizingMaskIntoConstraints = false

        let phoneConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let phoneIV = UIImageView(image: UIImage(systemName: "phone.fill", withConfiguration: phoneConfig))
        phoneIV.tintColor = UIColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1.0)
        phoneIV.translatesAutoresizingMaskIntoConstraints = false
        phoneCircle.addSubview(phoneIV)

        emergencyTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        emergencyTitleLabel.textColor = .label
        emergencyTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        emergencyDetailLabel.font = .systemFont(ofSize: 12)
        emergencyDetailLabel.textColor = .secondaryLabel
        emergencyDetailLabel.translatesAutoresizingMaskIntoConstraints = false

        emergencyCallButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        emergencyCallButton.setTitleColor(.white, for: .normal)
        emergencyCallButton.backgroundColor = UIColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1.0)
        emergencyCallButton.layer.cornerRadius = 16
        emergencyCallButton.translatesAutoresizingMaskIntoConstraints = false

        banner.addSubview(phoneCircle)
        banner.addSubview(emergencyTitleLabel)
        banner.addSubview(emergencyDetailLabel)
        banner.addSubview(emergencyCallButton)

        NSLayoutConstraint.activate([
            banner.heightAnchor.constraint(equalToConstant: 60),

            phoneCircle.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            phoneCircle.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            phoneCircle.widthAnchor.constraint(equalToConstant: 36),
            phoneCircle.heightAnchor.constraint(equalToConstant: 36),

            phoneIV.centerXAnchor.constraint(equalTo: phoneCircle.centerXAnchor),
            phoneIV.centerYAnchor.constraint(equalTo: phoneCircle.centerYAnchor),

            emergencyTitleLabel.topAnchor.constraint(equalTo: banner.topAnchor, constant: 12),
            emergencyTitleLabel.leadingAnchor.constraint(equalTo: phoneCircle.trailingAnchor, constant: 10),

            emergencyDetailLabel.topAnchor.constraint(equalTo: emergencyTitleLabel.bottomAnchor, constant: 2),
            emergencyDetailLabel.leadingAnchor.constraint(equalTo: phoneCircle.trailingAnchor, constant: 10),

            emergencyCallButton.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            emergencyCallButton.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
            emergencyCallButton.widthAnchor.constraint(equalToConstant: 80),
            emergencyCallButton.heightAnchor.constraint(equalToConstant: 32),
        ])

        contentStack.addArrangedSubview(banner)
    }

    // MARK: - Active Service Orders

    private func setupActiveServiceOrders() {
        let card = makeCardView()

        // Section title
        activeOrdersSectionTitle.font = .systemFont(ofSize: 18, weight: .bold)
        activeOrdersSectionTitle.textColor = .label
        activeOrdersSectionTitle.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(activeOrdersSectionTitle)

        // Order card
        let orderCard = UIView()
        orderCard.backgroundColor = UIColor.secondarySystemBackground
        orderCard.layer.cornerRadius = 12
        orderCard.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(orderCard)

        // Order number and status
        activeOrderNumberLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        activeOrderNumberLabel.textColor = .label
        activeOrderNumberLabel.translatesAutoresizingMaskIntoConstraints = false

        let statusBadge = makePillBadge(text: "", bgColor: themeColor.withAlphaComponent(0.15), textColor: darkTealColor, outLabel: activeOrderStatusBadgeLabel)

        let chevron = UIImageView(image: directionalChevronImage(pointSize: 14))
        chevron.tintColor = .tertiaryLabel
        chevron.translatesAutoresizingMaskIntoConstraints = false
        activeOrderChevronView = chevron

        // Hospital info
        let hospitalIcon = UIImageView(image: UIImage(systemName: "building.2"))
        hospitalIcon.tintColor = .secondaryLabel
        hospitalIcon.translatesAutoresizingMaskIntoConstraints = false

        activeHospitalLabel.font = .systemFont(ofSize: 13)
        activeHospitalLabel.textColor = .secondaryLabel
        activeHospitalLabel.translatesAutoresizingMaskIntoConstraints = false

        // Location & type
        let locationIcon = UIImageView(image: UIImage(systemName: "mappin"))
        locationIcon.tintColor = .tertiaryLabel
        locationIcon.translatesAutoresizingMaskIntoConstraints = false

        activeLocationLabel.font = .systemFont(ofSize: 12)
        activeLocationLabel.textColor = .tertiaryLabel
        activeLocationLabel.translatesAutoresizingMaskIntoConstraints = false

        // Progress
        activeProgressTitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        activeProgressTitleLabel.textColor = .secondaryLabel
        activeProgressTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let progressPercent = UILabel()
        progressPercent.text = "65%"
        progressPercent.font = .systemFont(ofSize: 13, weight: .semibold)
        progressPercent.textColor = darkTealColor
        progressPercent.translatesAutoresizingMaskIntoConstraints = false

        let progressBarBg = UIView()
        progressBarBg.backgroundColor = UIColor.separator.withAlphaComponent(0.2)
        progressBarBg.layer.cornerRadius = 4
        progressBarBg.translatesAutoresizingMaskIntoConstraints = false

        let progressBarFill = UIView()
        progressBarFill.backgroundColor = darkTealColor
        progressBarFill.layer.cornerRadius = 4
        progressBarFill.translatesAutoresizingMaskIntoConstraints = false

        // Current step
        let stepIcon = UIImageView(image: UIImage(systemName: "circle.fill"))
        stepIcon.tintColor = darkTealColor
        stepIcon.translatesAutoresizingMaskIntoConstraints = false

        activeStepLabel.font = .systemFont(ofSize: 12)
        activeStepLabel.textColor = .secondaryLabel
        activeStepLabel.translatesAutoresizingMaskIntoConstraints = false

        orderCard.addSubview(activeOrderNumberLabel)
        orderCard.addSubview(statusBadge)
        orderCard.addSubview(chevron)
        orderCard.addSubview(hospitalIcon)
        orderCard.addSubview(activeHospitalLabel)
        orderCard.addSubview(locationIcon)
        orderCard.addSubview(activeLocationLabel)
        orderCard.addSubview(activeProgressTitleLabel)
        orderCard.addSubview(progressPercent)
        orderCard.addSubview(progressBarBg)
        progressBarBg.addSubview(progressBarFill)
        orderCard.addSubview(stepIcon)
        orderCard.addSubview(activeStepLabel)

        NSLayoutConstraint.activate([
            activeOrdersSectionTitle.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            activeOrdersSectionTitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),

            orderCard.topAnchor.constraint(equalTo: activeOrdersSectionTitle.bottomAnchor, constant: 14),
            orderCard.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            orderCard.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            orderCard.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            activeOrderNumberLabel.topAnchor.constraint(equalTo: orderCard.topAnchor, constant: 14),
            activeOrderNumberLabel.leadingAnchor.constraint(equalTo: orderCard.leadingAnchor, constant: 14),

            statusBadge.centerYAnchor.constraint(equalTo: activeOrderNumberLabel.centerYAnchor),
            statusBadge.leadingAnchor.constraint(equalTo: activeOrderNumberLabel.trailingAnchor, constant: 8),

            chevron.centerYAnchor.constraint(equalTo: activeOrderNumberLabel.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: orderCard.trailingAnchor, constant: -14),
            chevron.widthAnchor.constraint(equalToConstant: 10),

            hospitalIcon.topAnchor.constraint(equalTo: activeOrderNumberLabel.bottomAnchor, constant: 10),
            hospitalIcon.leadingAnchor.constraint(equalTo: orderCard.leadingAnchor, constant: 14),
            hospitalIcon.widthAnchor.constraint(equalToConstant: 16),
            hospitalIcon.heightAnchor.constraint(equalToConstant: 16),

            activeHospitalLabel.centerYAnchor.constraint(equalTo: hospitalIcon.centerYAnchor),
            activeHospitalLabel.leadingAnchor.constraint(equalTo: hospitalIcon.trailingAnchor, constant: 6),

            locationIcon.topAnchor.constraint(equalTo: hospitalIcon.bottomAnchor, constant: 6),
            locationIcon.leadingAnchor.constraint(equalTo: orderCard.leadingAnchor, constant: 14),
            locationIcon.widthAnchor.constraint(equalToConstant: 16),
            locationIcon.heightAnchor.constraint(equalToConstant: 16),

            activeLocationLabel.centerYAnchor.constraint(equalTo: locationIcon.centerYAnchor),
            activeLocationLabel.leadingAnchor.constraint(equalTo: locationIcon.trailingAnchor, constant: 6),

            activeProgressTitleLabel.topAnchor.constraint(equalTo: locationIcon.bottomAnchor, constant: 12),
            activeProgressTitleLabel.leadingAnchor.constraint(equalTo: orderCard.leadingAnchor, constant: 14),

            progressPercent.centerYAnchor.constraint(equalTo: activeProgressTitleLabel.centerYAnchor),
            progressPercent.trailingAnchor.constraint(equalTo: orderCard.trailingAnchor, constant: -14),

            progressBarBg.topAnchor.constraint(equalTo: activeProgressTitleLabel.bottomAnchor, constant: 6),
            progressBarBg.leadingAnchor.constraint(equalTo: orderCard.leadingAnchor, constant: 14),
            progressBarBg.trailingAnchor.constraint(equalTo: orderCard.trailingAnchor, constant: -14),
            progressBarBg.heightAnchor.constraint(equalToConstant: 8),

            progressBarFill.topAnchor.constraint(equalTo: progressBarBg.topAnchor),
            progressBarFill.leadingAnchor.constraint(equalTo: progressBarBg.leadingAnchor),
            progressBarFill.heightAnchor.constraint(equalTo: progressBarBg.heightAnchor),
            progressBarFill.widthAnchor.constraint(equalTo: progressBarBg.widthAnchor, multiplier: 0.65),

            stepIcon.topAnchor.constraint(equalTo: progressBarBg.bottomAnchor, constant: 10),
            stepIcon.leadingAnchor.constraint(equalTo: orderCard.leadingAnchor, constant: 14),
            stepIcon.widthAnchor.constraint(equalToConstant: 8),
            stepIcon.heightAnchor.constraint(equalToConstant: 8),

            activeStepLabel.centerYAnchor.constraint(equalTo: stepIcon.centerYAnchor),
            activeStepLabel.leadingAnchor.constraint(equalTo: stepIcon.trailingAnchor, constant: 6),
            activeStepLabel.bottomAnchor.constraint(equalTo: orderCard.bottomAnchor, constant: -14),
        ])

        contentStack.addArrangedSubview(card)
    }

    // MARK: - Our Service Process

    private func setupServiceProcess() {
        let card = makeCardView()

        serviceProcessSectionTitle.font = .systemFont(ofSize: 18, weight: .bold)
        serviceProcessSectionTitle.textColor = .label
        serviceProcessSectionTitle.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(serviceProcessSectionTitle)

        let stepsStack = UIStackView()
        stepsStack.axis = .horizontal
        stepsStack.distribution = .fillEqually
        stepsStack.spacing = 10
        stepsStack.translatesAutoresizingMaskIntoConstraints = false

        let step1 = makeProcessStep(
            icon: "doc.text.magnifyingglass",
            titleLabel: processStep1TitleLabel,
            itemsLabels: processStep1ItemsLabels
        )
        let step2 = makeProcessStep(
            icon: "cross.case",
            titleLabel: processStep2TitleLabel,
            itemsLabels: processStep2ItemsLabels
        )
        let step3 = makeProcessStep(
            icon: "checkmark.circle",
            titleLabel: processStep3TitleLabel,
            itemsLabels: processStep3ItemsLabels
        )

        stepsStack.addArrangedSubview(step1)
        stepsStack.addArrangedSubview(step2)
        stepsStack.addArrangedSubview(step3)

        card.addSubview(stepsStack)

        NSLayoutConstraint.activate([
            serviceProcessSectionTitle.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            serviceProcessSectionTitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),

            stepsStack.topAnchor.constraint(equalTo: serviceProcessSectionTitle.bottomAnchor, constant: 16),
            stepsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stepsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stepsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])

        contentStack.addArrangedSubview(card)
    }

    // MARK: - AI Medical Assessment

    private func setupAIAssessment() {
        let card = UIView()
        card.backgroundColor = darkTealColor.withAlphaComponent(0.08)
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = darkTealColor.withAlphaComponent(0.2).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let aiIconCircle = UIView()
        aiIconCircle.backgroundColor = darkTealColor.withAlphaComponent(0.15)
        aiIconCircle.layer.cornerRadius = 20
        aiIconCircle.translatesAutoresizingMaskIntoConstraints = false

        let aiConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let aiIV = UIImageView(image: UIImage(systemName: "brain.head.profile", withConfiguration: aiConfig))
        aiIV.tintColor = darkTealColor
        aiIV.translatesAutoresizingMaskIntoConstraints = false
        aiIconCircle.addSubview(aiIV)

        aiTitleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        aiTitleLabel.textColor = .label
        aiTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        aiDescLabel.font = .systemFont(ofSize: 13)
        aiDescLabel.textColor = .secondaryLabel
        aiDescLabel.numberOfLines = 0
        aiDescLabel.translatesAutoresizingMaskIntoConstraints = false

        aiStartButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        aiStartButton.setTitleColor(.white, for: .normal)
        aiStartButton.backgroundColor = darkTealColor
        aiStartButton.layer.cornerRadius = 12
        aiStartButton.translatesAutoresizingMaskIntoConstraints = false
        aiStartButton.addTarget(self, action: #selector(startGlobalCareFlow), for: .touchUpInside)

        card.addSubview(aiIconCircle)
        card.addSubview(aiTitleLabel)
        card.addSubview(aiDescLabel)
        card.addSubview(aiStartButton)

        NSLayoutConstraint.activate([
            aiIconCircle.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            aiIconCircle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            aiIconCircle.widthAnchor.constraint(equalToConstant: 40),
            aiIconCircle.heightAnchor.constraint(equalToConstant: 40),

            aiIV.centerXAnchor.constraint(equalTo: aiIconCircle.centerXAnchor),
            aiIV.centerYAnchor.constraint(equalTo: aiIconCircle.centerYAnchor),

            aiTitleLabel.centerYAnchor.constraint(equalTo: aiIconCircle.centerYAnchor),
            aiTitleLabel.leadingAnchor.constraint(equalTo: aiIconCircle.trailingAnchor, constant: 12),

            aiDescLabel.topAnchor.constraint(equalTo: aiIconCircle.bottomAnchor, constant: 12),
            aiDescLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            aiDescLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            aiStartButton.topAnchor.constraint(equalTo: aiDescLabel.bottomAnchor, constant: 16),
            aiStartButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            aiStartButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            aiStartButton.heightAnchor.constraint(equalToConstant: 44),
            aiStartButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])

        contentStack.addArrangedSubview(card)
    }

    // MARK: - Service Packages

    private func setupServicePackages() {
        // Section header with Charity Support link
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false

        packagesSectionTitle.font = .systemFont(ofSize: 18, weight: .bold)
        packagesSectionTitle.textColor = .label
        packagesSectionTitle.translatesAutoresizingMaskIntoConstraints = false

        let heartConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        charityButton.setImage(UIImage(systemName: "heart.fill", withConfiguration: heartConfig), for: .normal)
        charityButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        charityButton.tintColor = darkTealColor
        charityButton.setTitleColor(darkTealColor, for: .normal)
        charityButton.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(packagesSectionTitle)
        headerView.addSubview(charityButton)

        NSLayoutConstraint.activate([
            headerView.heightAnchor.constraint(equalToConstant: 30),
            packagesSectionTitle.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            packagesSectionTitle.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            charityButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            charityButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
        ])

        contentStack.addArrangedSubview(headerView)

        // Basic Care Package
        let basicCardUI = makePackageCard(
            isPopular: false,
            isBestValue: false,
            isSelected: false,
            itemCount: 5
        )
        packageCardViews.append(basicCardUI)
        contentStack.addArrangedSubview(basicCardUI.view)

        // Standard Care Package (Most Popular, Selected)
        let standardCardUI = makePackageCard(
            isPopular: true,
            isBestValue: false,
            isSelected: true,
            itemCount: 7
        )
        packageCardViews.append(standardCardUI)
        contentStack.addArrangedSubview(standardCardUI.view)

        // Premium Care Package
        let premiumCardUI = makePackageCard(
            isPopular: false,
            isBestValue: true,
            isSelected: false,
            itemCount: 9
        )
        packageCardViews.append(premiumCardUI)
        contentStack.addArrangedSubview(premiumCardUI.view)
    }

    // MARK: - Partner Hospitals

    private func setupPartnerHospitals() {
        // Section header
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false

        hospitalsSectionTitle.font = .systemFont(ofSize: 18, weight: .bold)
        hospitalsSectionTitle.textColor = .label
        hospitalsSectionTitle.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(hospitalsSectionTitle)

        NSLayoutConstraint.activate([
            headerView.heightAnchor.constraint(equalToConstant: 30),
            hospitalsSectionTitle.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            hospitalsSectionTitle.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
        ])

        contentStack.addArrangedSubview(headerView)

        // Hospital cards
        let hospital1 = makeHospitalCard(
            rating: "4.9",
            reviews: "3847",
            priceLevel: "$$",
            accredited: true,
            specialtyCount: 3,
            imageName: "building.2.fill",
            imageColor: UIColor(red: 0.22, green: 0.50, blue: 0.72, alpha: 1.0)
        )
        hospitalCardViews.append(hospital1)
        contentStack.addArrangedSubview(hospital1.view)

        let hospital2 = makeHospitalCard(
            rating: "4.8",
            reviews: "1920",
            priceLevel: "$$$",
            accredited: true,
            specialtyCount: 3,
            imageName: "cross.case.fill",
            imageColor: UIColor(red: 0.65, green: 0.35, blue: 0.25, alpha: 1.0)
        )
        hospitalCardViews.append(hospital2)
        contentStack.addArrangedSubview(hospital2.view)

        let hospital3 = makeHospitalCard(
            rating: "4.7",
            reviews: "2150",
            priceLevel: "$",
            accredited: true,
            specialtyCount: 3,
            imageName: "heart.circle.fill",
            imageColor: UIColor(red: 0.25, green: 0.60, blue: 0.55, alpha: 1.0)
        )
        hospitalCardViews.append(hospital3)
        contentStack.addArrangedSubview(hospital3.view)

        // View All Partner Hospitals button
        let arrowConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        viewAllHospitalsButton.setImage(UIImage(systemName: "chevron.down", withConfiguration: arrowConfig), for: .normal)
        viewAllHospitalsButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        viewAllHospitalsButton.setTitleColor(darkTealColor, for: .normal)
        viewAllHospitalsButton.tintColor = darkTealColor
        viewAllHospitalsButton.backgroundColor = .systemBackground
        viewAllHospitalsButton.layer.cornerRadius = 12
        viewAllHospitalsButton.layer.borderWidth = 1
        viewAllHospitalsButton.layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor
        viewAllHospitalsButton.translatesAutoresizingMaskIntoConstraints = false
        viewAllHospitalsButton.heightAnchor.constraint(equalToConstant: 48).isActive = true

        contentStack.addArrangedSubview(viewAllHospitalsButton)
    }

    // MARK: - Bottom Stats

    private func setupBottomStats() {
        let statsContainer = UIView()
        statsContainer.backgroundColor = .systemBackground
        statsContainer.layer.cornerRadius = 16
        statsContainer.translatesAutoresizingMaskIntoConstraints = false

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 12
        grid.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.distribution = .fillEqually
        topRow.spacing = 12
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let bottomRow = UIStackView()
        bottomRow.axis = .horizontal
        bottomRow.distribution = .fillEqually
        bottomRow.spacing = 12
        bottomRow.translatesAutoresizingMaskIntoConstraints = false

        let stat1 = makeStatItem(icon: "lock.shield.fill")
        let stat2 = makeStatItem(icon: "person.3.fill")
        let stat3 = makeStatItem(icon: "building.2.fill")
        let stat4 = makeStatItem(icon: "clock.fill")
        
        statItemsLabels.append(stat1.labels)
        statItemsLabels.append(stat2.labels)
        statItemsLabels.append(stat3.labels)
        statItemsLabels.append(stat4.labels)

        topRow.addArrangedSubview(stat1.view)
        topRow.addArrangedSubview(stat2.view)

        bottomRow.addArrangedSubview(stat3.view)
        bottomRow.addArrangedSubview(stat4.view)

        grid.addArrangedSubview(topRow)
        grid.addArrangedSubview(bottomRow)
        statsContainer.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: statsContainer.topAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor, constant: -16),
            grid.bottomAnchor.constraint(equalTo: statsContainer.bottomAnchor, constant: -16),
        ])

        contentStack.addArrangedSubview(statsContainer)
    }

    // MARK: - Bottom Spacer

    private func addBottomSpacer() {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        contentStack.addArrangedSubview(spacer)
    }

    // MARK: - Helper: Card View

    private func makeCardView() -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    // MARK: - Helper: Pill Badge

    private func makePillBadge(text: String, bgColor: UIColor, textColor: UIColor, outLabel: UILabel? = nil) -> UIView {
        let pill = UIView()
        pill.backgroundColor = bgColor
        pill.layer.cornerRadius = 10
        pill.translatesAutoresizingMaskIntoConstraints = false

        let label = outLabel ?? UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = textColor
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -3),
        ])

        return pill
    }

    // MARK: - Helper: Process Step

    private func makeProcessStep(icon: String, titleLabel: UILabel, itemsLabels: [UILabel]) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Icon circle
        let iconCircle = UIView()
        iconCircle.backgroundColor = darkTealColor.withAlphaComponent(0.1)
        iconCircle.layer.cornerRadius = 22
        iconCircle.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconIV.tintColor = darkTealColor
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconIV)

        titleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconCircle)
        container.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconCircle.topAnchor.constraint(equalTo: container.topAnchor),
            iconCircle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 44),
            iconCircle.heightAnchor.constraint(equalToConstant: 44),

            iconIV.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconCircle.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
        ])

        // Bullet items
        var lastView: UIView = titleLabel
        for bulletLabel in itemsLabels {
            bulletLabel.font = .systemFont(ofSize: 10)
            bulletLabel.textColor = .secondaryLabel
            bulletLabel.numberOfLines = 1
            bulletLabel.lineBreakMode = .byTruncatingTail
            bulletLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(bulletLabel)

            NSLayoutConstraint.activate([
                bulletLabel.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 4),
                bulletLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                bulletLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
            ])
            lastView = bulletLabel
        }

        lastView.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true

        return container
    }

    // MARK: - Helper: Package Card Structs

    private struct PackageCardUI {
        let view: UIView
        let titleLabel: UILabel
        let badgeLabel: UILabel?
        let priceLabel: UILabel
        let originalPriceLabel: UILabel
        let subtitleLabel: UILabel
        let itemLabels: [UILabel]
        let actionButton: UIButton
    }

    private func makePackageCard(
        isPopular: Bool,
        isBestValue: Bool,
        isSelected: Bool,
        itemCount: Int
    ) -> PackageCardUI {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false

        if isSelected {
            card.layer.borderWidth = 2
            card.layer.borderColor = darkTealColor.cgColor
            card.layer.shadowColor = darkTealColor.cgColor
            card.layer.shadowOpacity = 0.15
            card.layer.shadowOffset = CGSize(width: 0, height: 4)
            card.layer.shadowRadius = 12
        } else {
            card.layer.borderWidth = 1
            card.layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor
        }

        // Title row
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)

        // Badge
        var outBadgeLabel: UILabel? = nil
        if isPopular || isBestValue {
            let badgeLabel = UILabel()
            let badge = makePillBadge(
                text: "",
                bgColor: darkTealColor,
                textColor: .white,
                outLabel: badgeLabel
            )
            card.addSubview(badge)
            outBadgeLabel = badgeLabel

            NSLayoutConstraint.activate([
                badge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
                badge.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            ])
        }

        // Price
        let priceLabel = UILabel()
        priceLabel.font = .systemFont(ofSize: 24, weight: .bold)
        priceLabel.textColor = darkTealColor
        priceLabel.translatesAutoresizingMaskIntoConstraints = false

        let originalPriceLabel = UILabel()
        originalPriceLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(priceLabel)
        card.addSubview(originalPriceLabel)

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),

            priceLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            priceLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            originalPriceLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 2),
            originalPriceLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: priceLabel.leadingAnchor, constant: -8),
        ])

        // Checklist items
        var itemLabels: [UILabel] = []
        var lastView: UIView = subtitleLabel
        for _ in 0..<itemCount {
            let row = UIView()
            row.translatesAutoresizingMaskIntoConstraints = false

            let checkCircle = UIView()
            checkCircle.backgroundColor = darkTealColor.withAlphaComponent(0.12)
            checkCircle.layer.cornerRadius = 9
            checkCircle.translatesAutoresizingMaskIntoConstraints = false

            let checkConfig = UIImage.SymbolConfiguration(pointSize: 8, weight: .bold)
            let checkIV = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: checkConfig))
            checkIV.tintColor = darkTealColor
            checkIV.translatesAutoresizingMaskIntoConstraints = false
            checkCircle.addSubview(checkIV)

            let itemLabel = UILabel()
            itemLabel.font = .systemFont(ofSize: 14)
            itemLabel.textColor = .secondaryLabel
            itemLabel.translatesAutoresizingMaskIntoConstraints = false
            itemLabels.append(itemLabel)

            row.addSubview(checkCircle)
            row.addSubview(itemLabel)
            card.addSubview(row)

            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 10),
                row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
                row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
                row.heightAnchor.constraint(equalToConstant: 20),

                checkCircle.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                checkCircle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                checkCircle.widthAnchor.constraint(equalToConstant: 18),
                checkCircle.heightAnchor.constraint(equalToConstant: 18),

                checkIV.centerXAnchor.constraint(equalTo: checkCircle.centerXAnchor),
                checkIV.centerYAnchor.constraint(equalTo: checkCircle.centerYAnchor),

                itemLabel.leadingAnchor.constraint(equalTo: checkCircle.trailingAnchor, constant: 10),
                itemLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])

            lastView = row
        }

        // Action button
        let actionButton = UIButton(type: .system)
        if isSelected {
            actionButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            actionButton.setTitleColor(.white, for: .normal)
            actionButton.backgroundColor = darkTealColor
        } else {
            actionButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            actionButton.setTitleColor(darkTealColor, for: .normal)
            actionButton.backgroundColor = .clear
        }
        actionButton.layer.cornerRadius = 22
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(actionButton)

        NSLayoutConstraint.activate([
            actionButton.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 16),
            actionButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 160),
            actionButton.heightAnchor.constraint(equalToConstant: 44),
            actionButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])

        return PackageCardUI(
            view: card,
            titleLabel: titleLabel,
            badgeLabel: outBadgeLabel,
            priceLabel: priceLabel,
            originalPriceLabel: originalPriceLabel,
            subtitleLabel: subtitleLabel,
            itemLabels: itemLabels,
            actionButton: actionButton
        )
    }

    // MARK: - Helper: Hospital Card Structs

    private struct HospitalCardUI {
        let view: UIView
        let nameLabel: UILabel
        let locationLabel: UILabel
        let ratingLabel: UILabel
        let reviewsLabel: UILabel
        let priceLevelLabel: UILabel
        let specialtyLabels: [UILabel]
        let accLabel: UILabel?
    }

    private func makeHospitalCard(
        rating: String,
        reviews: String,
        priceLevel: String,
        accredited: Bool,
        specialtyCount: Int,
        imageName: String,
        imageColor: UIColor
    ) -> HospitalCardUI {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        // Image area
        let imageArea = UIView()
        imageArea.backgroundColor = imageColor.withAlphaComponent(0.15)
        imageArea.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: imageName, withConfiguration: iconConfig))
        iconIV.tintColor = imageColor.withAlphaComponent(0.4)
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        imageArea.addSubview(iconIV)

        card.addSubview(imageArea)

        // JCI Accredited badge
        var outAccLabel: UILabel? = nil
        if accredited {
            let accBadge = UIView()
            accBadge.backgroundColor = .systemBackground
            accBadge.layer.cornerRadius = 10
            accBadge.translatesAutoresizingMaskIntoConstraints = false

            let accLabel = UILabel()
            accLabel.font = .systemFont(ofSize: 10, weight: .semibold)
            accLabel.textColor = darkTealColor
            accLabel.translatesAutoresizingMaskIntoConstraints = false
            accBadge.addSubview(accLabel)
            outAccLabel = accLabel

            let accIcon = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))
            accIcon.tintColor = darkTealColor
            accIcon.translatesAutoresizingMaskIntoConstraints = false
            accBadge.addSubview(accIcon)

            imageArea.addSubview(accBadge)

            NSLayoutConstraint.activate([
                accBadge.topAnchor.constraint(equalTo: imageArea.topAnchor, constant: 10),
                accBadge.trailingAnchor.constraint(equalTo: imageArea.trailingAnchor, constant: -10),

                accIcon.leadingAnchor.constraint(equalTo: accBadge.leadingAnchor, constant: 6),
                accIcon.centerYAnchor.constraint(equalTo: accBadge.centerYAnchor),
                accIcon.widthAnchor.constraint(equalToConstant: 12),
                accIcon.heightAnchor.constraint(equalToConstant: 12),

                accLabel.leadingAnchor.constraint(equalTo: accIcon.trailingAnchor, constant: 3),
                accLabel.trailingAnchor.constraint(equalTo: accBadge.trailingAnchor, constant: -8),
                accLabel.topAnchor.constraint(equalTo: accBadge.topAnchor, constant: 4),
                accLabel.bottomAnchor.constraint(equalTo: accBadge.bottomAnchor, constant: -4),
            ])
        }

        // Info section
        let nameLabel = UILabel()
        nameLabel.font = .systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let locationIV = UIImageView(image: UIImage(systemName: "mappin"))
        locationIV.tintColor = .secondaryLabel
        locationIV.translatesAutoresizingMaskIntoConstraints = false

        let locationLabel = UILabel()
        locationLabel.font = .systemFont(ofSize: 13)
        locationLabel.textColor = .secondaryLabel
        locationLabel.translatesAutoresizingMaskIntoConstraints = false

        // Rating
        let starIV = UIImageView(image: UIImage(systemName: "star.fill"))
        starIV.tintColor = UIColor(red: 0.95, green: 0.75, blue: 0.2, alpha: 1.0)
        starIV.translatesAutoresizingMaskIntoConstraints = false

        let ratingLabel = UILabel()
        ratingLabel.text = "\(rating)"
        ratingLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        ratingLabel.textColor = .label
        ratingLabel.translatesAutoresizingMaskIntoConstraints = false

        let reviewsLabel = UILabel()
        reviewsLabel.text = "(\(reviews))"
        reviewsLabel.font = .systemFont(ofSize: 12)
        reviewsLabel.textColor = .tertiaryLabel
        reviewsLabel.translatesAutoresizingMaskIntoConstraints = false

        let priceLevelLabel = UILabel()
        priceLevelLabel.text = priceLevel
        priceLevelLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        priceLevelLabel.textColor = darkTealColor
        priceLevelLabel.translatesAutoresizingMaskIntoConstraints = false

        // Specialties
        let specialtyStack = UIStackView()
        specialtyStack.axis = .horizontal
        specialtyStack.spacing = 6
        specialtyStack.translatesAutoresizingMaskIntoConstraints = false

        var specialtyLabels: [UILabel] = []
        for _ in 0..<specialtyCount {
            let tag = UIView()
            tag.backgroundColor = UIColor.secondarySystemBackground
            tag.layer.cornerRadius = 10
            tag.translatesAutoresizingMaskIntoConstraints = false

            let tagLabel = UILabel()
            tagLabel.font = .systemFont(ofSize: 11, weight: .medium)
            tagLabel.textColor = .secondaryLabel
            tagLabel.translatesAutoresizingMaskIntoConstraints = false
            tag.addSubview(tagLabel)
            specialtyLabels.append(tagLabel)

            NSLayoutConstraint.activate([
                tagLabel.leadingAnchor.constraint(equalTo: tag.leadingAnchor, constant: 8),
                tagLabel.trailingAnchor.constraint(equalTo: tag.trailingAnchor, constant: -8),
                tagLabel.topAnchor.constraint(equalTo: tag.topAnchor, constant: 4),
                tagLabel.bottomAnchor.constraint(equalTo: tag.bottomAnchor, constant: -4),
            ])

            specialtyStack.addArrangedSubview(tag)
        }

        card.addSubview(nameLabel)
        card.addSubview(locationIV)
        card.addSubview(locationLabel)
        card.addSubview(starIV)
        card.addSubview(ratingLabel)
        card.addSubview(reviewsLabel)
        card.addSubview(priceLevelLabel)
        card.addSubview(specialtyStack)

        NSLayoutConstraint.activate([
            imageArea.topAnchor.constraint(equalTo: card.topAnchor),
            imageArea.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageArea.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageArea.heightAnchor.constraint(equalToConstant: 130),

            iconIV.centerXAnchor.constraint(equalTo: imageArea.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: imageArea.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: imageArea.bottomAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            locationIV.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            locationIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            locationIV.widthAnchor.constraint(equalToConstant: 12),
            locationIV.heightAnchor.constraint(equalToConstant: 12),

            locationLabel.centerYAnchor.constraint(equalTo: locationIV.centerYAnchor),
            locationLabel.leadingAnchor.constraint(equalTo: locationIV.trailingAnchor, constant: 4),

            starIV.topAnchor.constraint(equalTo: locationIV.bottomAnchor, constant: 8),
            starIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            starIV.widthAnchor.constraint(equalToConstant: 14),
            starIV.heightAnchor.constraint(equalToConstant: 14),

            ratingLabel.centerYAnchor.constraint(equalTo: starIV.centerYAnchor),
            ratingLabel.leadingAnchor.constraint(equalTo: starIV.trailingAnchor, constant: 4),

            reviewsLabel.centerYAnchor.constraint(equalTo: starIV.centerYAnchor),
            reviewsLabel.leadingAnchor.constraint(equalTo: ratingLabel.trailingAnchor, constant: 4),

            priceLevelLabel.centerYAnchor.constraint(equalTo: starIV.centerYAnchor),
            priceLevelLabel.leadingAnchor.constraint(equalTo: reviewsLabel.trailingAnchor, constant: 8),

            specialtyStack.topAnchor.constraint(equalTo: starIV.bottomAnchor, constant: 10),
            specialtyStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            specialtyStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        return HospitalCardUI(
            view: card,
            nameLabel: nameLabel,
            locationLabel: locationLabel,
            ratingLabel: ratingLabel,
            reviewsLabel: reviewsLabel,
            priceLevelLabel: priceLevelLabel,
            specialtyLabels: specialtyLabels,
            accLabel: outAccLabel
        )
    }

    // MARK: - Helper: Stat Item

    private func makeStatItem(icon: String) -> (view: UIView, labels: (title: UILabel, subtitle: UILabel)) {
        let container = UIView()
        container.backgroundColor = UIColor.secondarySystemBackground
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconIV.tintColor = darkTealColor
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconIV)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 70),

            iconIV.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            iconIV.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),

            titleLabel.topAnchor.constraint(equalTo: iconIV.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
        ])

        return (container, (titleLabel, subtitleLabel))
    }

    // MARK: - 全球送诊流程入口

    @objc private func startGlobalCareFlow() {
        let vc = CareApplicationViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - 语言切换响应

    @objc private func languageChanged() {
        updateTexts()
        applyNaturalAlignment()
    }

    private func updateTexts() {
        applyNaturalAlignment()
        // Header
        headerTitleLabel.text = t(.discoverHeaderTitle)
        headerSubtitleLabel.text = t(.discoverHeaderSubtitle)
        
        // Emergency Banner
        emergencyTitleLabel.text = t(.discoverEmergencyTitle)
        emergencyDetailLabel.text = t(.discoverEmergencyDetail)
        emergencyCallButton.setTitle(t(.discoverEmergencyCallButton), for: .normal)
        
        // Active Orders
        activeOrdersSectionTitle.text = t(.discoverActiveOrdersTitle)
        activeOrderNumberLabel.text = "ORD-2024-001"
        activeOrderStatusBadgeLabel.text = t(.discoverStatusActive)
        activeHospitalLabel.text = t(.discoverActiveHospitalName)
        activeLocationLabel.text = t(.discoverActiveLocationThailandStandard)
        activeProgressTitleLabel.text = t(.discoverProgressTitle)
        activeStepLabel.text = t(.discoverCurrentStepTreatment)
        
        // Service Process
        serviceProcessSectionTitle.text = t(.discoverServiceProcessTitle)
        
        processStep1TitleLabel.text = t(.discoverStep1Title)
        let step1Items = [t(.discoverStep1Item1), t(.discoverStep1Item2), t(.discoverStep1Item3)]
        for (i, label) in processStep1ItemsLabels.enumerated() {
            if i < step1Items.count { label.text = "• \(step1Items[i])" }
        }
        
        processStep2TitleLabel.text = t(.discoverStep2Title)
        let step2Items = [t(.discoverStep2Item1), t(.discoverStep2Item2), t(.discoverStep2Item3)]
        for (i, label) in processStep2ItemsLabels.enumerated() {
            if i < step2Items.count { label.text = "• \(step2Items[i])" }
        }
        
        processStep3TitleLabel.text = t(.discoverStep3Title)
        let step3Items = [t(.discoverStep3Item1), t(.discoverStep3Item2), t(.discoverStep3Item3)]
        for (i, label) in processStep3ItemsLabels.enumerated() {
            if i < step3Items.count { label.text = "• \(step3Items[i])" }
        }
        
        // AI Assessment
        aiTitleLabel.text = t(.discoverAIAssessmentTitle)
        aiDescLabel.text = t(.discoverAIAssessmentDesc)
        aiStartButton.setTitle(t(.discoverAIAssessmentStartButton), for: .normal)
        
        // Service Packages
        packagesSectionTitle.text = t(.discoverPackagesTitle)
        charityButton.setTitle(" " + t(.discoverCharitySupport), for: .normal)
        
        if packageCardViews.count >= 3 {
            // Basic
            let basic = packageCardViews[0]
            basic.titleLabel.text = t(.discoverPackageBasicTitle)
            basic.subtitleLabel.text = t(.discoverPackageBasicSubtitle)
            basic.priceLabel.text = "$2,999"
            setupStrikethrough(basic.originalPriceLabel, text: "$3,099")
            basic.actionButton.setTitle(t(.discoverPackageActionSelect), for: .normal)
            let basicItems = [
                t(.discoverPackageBasicItem1),
                t(.discoverPackageBasicItem2),
                t(.discoverPackageBasicItem3),
                t(.discoverPackageBasicItem4),
                t(.discoverPackageBasicItem5)
            ]
            for (i, label) in basic.itemLabels.enumerated() {
                if i < basicItems.count { label.text = basicItems[i] }
            }
            
            // Standard
            let standard = packageCardViews[1]
            standard.titleLabel.text = t(.discoverPackageStandardTitle)
            standard.subtitleLabel.text = t(.discoverPackageStandardSubtitle)
            standard.priceLabel.text = "$5,999"
            setupStrikethrough(standard.originalPriceLabel, text: "$7,099")
            standard.badgeLabel?.text = t(.discoverBadgeMostPopular)
            standard.actionButton.setTitle(t(.discoverPackageActionSelected), for: .normal)
            let standardItems = [
                t(.discoverPackageStandardItem1),
                t(.discoverPackageStandardItem2),
                t(.discoverPackageStandardItem3),
                t(.discoverPackageStandardItem4),
                t(.discoverPackageStandardItem5),
                t(.discoverPackageStandardItem6),
                t(.discoverPackageStandardItem7)
            ]
            for (i, label) in standard.itemLabels.enumerated() {
                if i < standardItems.count { label.text = standardItems[i] }
            }
            
            // Premium
            let premium = packageCardViews[2]
            premium.titleLabel.text = t(.discoverPackagePremiumTitle)
            premium.subtitleLabel.text = t(.discoverPackagePremiumSubtitle)
            premium.priceLabel.text = "$12,999"
            setupStrikethrough(premium.originalPriceLabel, text: "$15,999")
            premium.badgeLabel?.text = t(.discoverBadgeBestValue)
            premium.actionButton.setTitle(t(.discoverPackageActionSelect), for: .normal)
            let premiumItems = [
                t(.discoverPackagePremiumItem1),
                t(.discoverPackagePremiumItem2),
                t(.discoverPackagePremiumItem3),
                t(.discoverPackagePremiumItem4),
                t(.discoverPackagePremiumItem5),
                t(.discoverPackagePremiumItem6),
                t(.discoverPackagePremiumItem7),
                t(.discoverPackagePremiumItem8),
                t(.discoverPackagePremiumItem9)
            ]
            for (i, label) in premium.itemLabels.enumerated() {
                if i < premiumItems.count { label.text = premiumItems[i] }
            }
        }
        
        // Hospitals
        hospitalsSectionTitle.text = t(.discoverHospitalsTitle)
        viewAllHospitalsButton.setTitle("  " + t(.discoverHospitalsViewAll), for: .normal)
        
        if hospitalCardViews.count >= 3 {
            let h1 = hospitalCardViews[0]
            h1.nameLabel.text = t(.discoverHospital1Name)
            h1.locationLabel.text = t(.discoverHospital1Location)
            h1.accLabel?.text = t(.discoverBadgeAccredited)
            let h1Specs = [t(.discoverSpecCardiology), t(.discoverSpecOncology), t(.discoverSpecOrthopedics)]
            for (i, label) in h1.specialtyLabels.enumerated() {
                if i < h1Specs.count { label.text = h1Specs[i] }
            }
            
            let h2 = hospitalCardViews[1]
            h2.nameLabel.text = t(.discoverHospital2Name)
            h2.locationLabel.text = t(.discoverHospital2Location)
            h2.accLabel?.text = t(.discoverBadgeAccredited)
            let h2Specs = [t(.discoverSpecNeurosurgery), t(.discoverSpecTransplant), t(.discoverSpecPediatrics)]
            for (i, label) in h2.specialtyLabels.enumerated() {
                if i < h2Specs.count { label.text = h2Specs[i] }
            }
            
            let h3 = hospitalCardViews[2]
            h3.nameLabel.text = t(.discoverHospital3Name)
            h3.locationLabel.text = t(.discoverHospital3Location)
            h3.accLabel?.text = t(.discoverBadgeAccredited)
            let h3Specs = [t(.discoverSpecCardiacSurgery), t(.discoverSpecSpineSurgery), t(.discoverSpecUrology)]
            for (i, label) in h3.specialtyLabels.enumerated() {
                if i < h3Specs.count { label.text = h3Specs[i] }
            }
        }
        
        // Stats
        if statItemsLabels.count >= 4 {
            statItemsLabels[0].title.text = t(.discoverStatHipaaTitle)
            statItemsLabels[0].subtitle.text = t(.discoverStatHipaaSubtitle)
            statItemsLabels[1].title.text = t(.discoverStatPatientsTitle)
            statItemsLabels[1].subtitle.text = t(.discoverStatPatientsSubtitle)
            statItemsLabels[2].title.text = t(.discoverStatHospitalsTitle)
            statItemsLabels[2].subtitle.text = t(.discoverStatHospitalsSubtitle)
            statItemsLabels[3].title.text = t(.discoverStatSupportTitle)
            statItemsLabels[3].subtitle.text = t(.discoverStatSupportSubtitle)
        }
    }

    private func setupStrikethrough(_ label: UILabel, text: String) {
        let strikeAttrs: [NSAttributedString.Key: Any] = [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: UIColor.tertiaryLabel,
            .font: UIFont.systemFont(ofSize: 14),
        ]
        label.attributedText = NSAttributedString(string: text, attributes: strikeAttrs)
    }

    private func applyNaturalAlignment() {
        let labels: [UILabel] = [
            headerTitleLabel,
            headerSubtitleLabel,
            emergencyTitleLabel,
            emergencyDetailLabel,
            activeOrdersSectionTitle,
            activeOrderNumberLabel,
            activeOrderStatusBadgeLabel,
            activeHospitalLabel,
            activeLocationLabel,
            activeProgressTitleLabel,
            activeStepLabel,
            serviceProcessSectionTitle,
            processStep1TitleLabel,
            processStep2TitleLabel,
            processStep3TitleLabel,
            aiTitleLabel,
            aiDescLabel,
            packagesSectionTitle,
            hospitalsSectionTitle,
        ]

        labels.forEach { $0.textAlignment = .natural }
        processStep1ItemsLabels.forEach { $0.textAlignment = .natural }
        processStep2ItemsLabels.forEach { $0.textAlignment = .natural }
        processStep3ItemsLabels.forEach { $0.textAlignment = .natural }
        statItemsLabels.forEach {
            $0.title.textAlignment = .natural
            $0.subtitle.textAlignment = .natural
        }

        packageCardViews.forEach { card in
            card.titleLabel.textAlignment = .natural
            card.badgeLabel?.textAlignment = .natural
            card.priceLabel.textAlignment = .natural
            card.originalPriceLabel.textAlignment = .natural
            card.subtitleLabel.textAlignment = .natural
            card.itemLabels.forEach { $0.textAlignment = .natural }
        }

        hospitalCardViews.forEach { card in
            card.nameLabel.textAlignment = .natural
            card.locationLabel.textAlignment = .natural
            card.accLabel?.textAlignment = .natural
            card.specialtyLabels.forEach { $0.textAlignment = .natural }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 语言切换

    private func setupLanguageSwitcher() {
        let switcher = UIStackView()
        switcher.axis = .horizontal
        switcher.spacing = 4
        switcher.translatesAutoresizingMaskIntoConstraints = false

        AppLanguage.allCases.forEach { lang in
            let btn = UIButton(type: .system)
            btn.setTitle(lang.displayName, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            btn.layer.cornerRadius = 8
            btn.layer.borderWidth = 1
            btn.layer.borderColor = AppDesign.Color.primaryGreen.cgColor
            btn.setTitleColor(AppDesign.Color.primaryGreen, for: .normal)
            btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
            btn.tag = AppLanguage.allCases.firstIndex(of: lang) ?? 0
            btn.addTarget(self, action: #selector(switchLanguage(_:)), for: .touchUpInside)
            btn.translatesAutoresizingMaskIntoConstraints = false
            switcher.addArrangedSubview(btn)
        }

        contentStack.insertArrangedSubview(switcher, at: 0)
    }

    @objc private func switchLanguage(_ sender: UIButton) {
        let lang = AppLanguage.allCases[sender.tag]
        LocaleManager.shared.setLanguage(lang)
    }
}
