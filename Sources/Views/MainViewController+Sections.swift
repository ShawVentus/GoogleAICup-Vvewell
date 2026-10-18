import UIKit

extension MainViewController {

    // MARK: - Setup ScrollView

    func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        let topBarBackground = UIView()
        topBarBackground.backgroundColor = AppDesign.Surface.canvasBackground
        topBarBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBarBackground)

        NSLayoutConstraint.activate([
            topBarBackground.topAnchor.constraint(equalTo: view.topAnchor),
            topBarBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarBackground.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Header

    func setupHeader() {
        let brandImage: UIImage? = {
            guard let url = Bundle.main.url(forResource: "vvewell-mark", withExtension: "png", subdirectory: "AvatarCoach") else { return nil }
            return UIImage(contentsOfFile: url.path)
        }()
        let brand = UIImageView(image: brandImage)
        brand.contentMode = .scaleAspectFit
        brand.tintColor = AppDesign.Color.primaryGreen
        brand.translatesAutoresizingMaskIntoConstraints = false
        brand.accessibilityLabel = "vvewell"
        contentView.addSubview(brand)
        contentView.addSubview(greetingLabel)
        contentView.addSubview(welcomeLabel)
        welcomeLabelRef = welcomeLabel
        contentView.addSubview(notificationButton)
        contentView.addSubview(languageButton)
        contentView.addSubview(syncButton)
        contentView.addSubview(badgeView)
        notificationButton.addTarget(self, action: #selector(homeNotificationsTapped), for: .touchUpInside)
        languageButton.addTarget(self, action: #selector(homeLanguageTapped), for: .touchUpInside)
        syncButton.addTarget(self, action: #selector(homeSyncTapped), for: .touchUpInside)
        greetingLabel.isUserInteractionEnabled = true
        greetingLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(homeProfileTapped)))

        NSLayoutConstraint.activate([
            brand.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            brand.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            brand.widthAnchor.constraint(equalToConstant: 76),
            brand.heightAnchor.constraint(equalToConstant: 24),

            greetingLabel.topAnchor.constraint(equalTo: brand.bottomAnchor, constant: 9),
            greetingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            greetingLabel.trailingAnchor.constraint(lessThanOrEqualTo: syncButton.leadingAnchor, constant: -8),

            welcomeLabel.topAnchor.constraint(equalTo: greetingLabel.bottomAnchor, constant: 4),
            welcomeLabel.leadingAnchor.constraint(equalTo: greetingLabel.leadingAnchor),
            welcomeLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),

            notificationButton.centerYAnchor.constraint(equalTo: greetingLabel.centerYAnchor),
            notificationButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            notificationButton.widthAnchor.constraint(equalToConstant: 44),
            notificationButton.heightAnchor.constraint(equalToConstant: 44),

            syncButton.trailingAnchor.constraint(equalTo: notificationButton.leadingAnchor, constant: -2),
            syncButton.centerYAnchor.constraint(equalTo: notificationButton.centerYAnchor),
            languageButton.trailingAnchor.constraint(equalTo: syncButton.leadingAnchor, constant: -2),
            languageButton.centerYAnchor.constraint(equalTo: notificationButton.centerYAnchor),

            badgeView.topAnchor.constraint(equalTo: notificationButton.topAnchor, constant: 2),
            badgeView.trailingAnchor.constraint(equalTo: notificationButton.trailingAnchor, constant: -2),
        ])
    }

    // MARK: - Health Overview Card

    func setupHealthCard() {
        contentView.addSubview(healthCardView)
        healthCardView.layer.cornerRadius = AppDesign.CornerRadius.heroCard
        healthCardView.layer.shadowColor = UIColor.black.cgColor
        healthCardView.layer.shadowOpacity = 0.08
        healthCardView.layer.shadowOffset = CGSize(width: 0, height: 8)
        healthCardView.layer.shadowRadius = 20

        let pulseIcon = makeIconImageView(systemName: "waveform.path.ecg", color: .white, size: 18)
        let titleLabel = UILabel()
        healthOverviewLabel = titleLabel
        titleLabel.text = t(.mainHealthOverview)
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let lastLabel = UILabel()
        lastLabel.text = t(.mainLastToday0830)
        lastLabel.font = .systemFont(ofSize: 12, weight: .medium)
        lastLabel.textColor = .white
        lastLabel.textAlignment = .natural
        lastLabel.translatesAutoresizingMaskIntoConstraints = false
        lastCheckLabel = lastLabel

        let lastPill = UIView()
        lastPill.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        lastPill.layer.cornerRadius = 12
        lastPill.translatesAutoresizingMaskIntoConstraints = false
        lastPill.addSubview(lastLabel)

        healthCardView.addSubview(pulseIcon)
        healthCardView.addSubview(titleLabel)
        healthCardView.addSubview(lastPill)

        NSLayoutConstraint.activate([
            healthCardView.topAnchor.constraint(equalTo: coachSectionView.bottomAnchor, constant: 16),
            healthCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            healthCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            pulseIcon.topAnchor.constraint(equalTo: healthCardView.topAnchor, constant: 20),
            pulseIcon.leadingAnchor.constraint(equalTo: healthCardView.leadingAnchor, constant: 20),

            titleLabel.centerYAnchor.constraint(equalTo: pulseIcon.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: pulseIcon.trailingAnchor, constant: 8),

            lastPill.centerYAnchor.constraint(equalTo: pulseIcon.centerYAnchor),
            lastPill.trailingAnchor.constraint(equalTo: healthCardView.trailingAnchor, constant: -20),
            lastPill.heightAnchor.constraint(equalToConstant: 24),

            lastLabel.leadingAnchor.constraint(equalTo: lastPill.leadingAnchor, constant: 10),
            lastLabel.trailingAnchor.constraint(equalTo: lastPill.trailingAnchor, constant: -10),
            lastLabel.centerYAnchor.constraint(equalTo: lastPill.centerYAnchor),
        ])

        let heartRate = makeHomeMetricCard(icon: "heart", type: .heartRate)
        let spo2 = makeHomeMetricCard(icon: "waveform.path.ecg", type: .spo2)
        let stress = makeHomeMetricCard(icon: "exclamationmark.circle", type: .stress)
        let bp = makeHomeMetricCard(icon: "waveform.path.ecg", type: .bloodPressure)

        let topRow = UIStackView(arrangedSubviews: [heartRate.view, spo2.view])
        topRow.axis = .horizontal
        topRow.spacing = 12
        topRow.distribution = .fillEqually
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let bottomRow = UIStackView(arrangedSubviews: [stress.view, bp.view])
        bottomRow.axis = .horizontal
        bottomRow.spacing = 12
        bottomRow.distribution = .fillEqually
        bottomRow.translatesAutoresizingMaskIntoConstraints = false

        healthCardView.addSubview(topRow)
        healthCardView.addSubview(bottomRow)
        healthCardView.addSubview(startCheckButton)

        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: pulseIcon.bottomAnchor, constant: 16),
            topRow.leadingAnchor.constraint(equalTo: healthCardView.leadingAnchor, constant: 16),
            topRow.trailingAnchor.constraint(equalTo: healthCardView.trailingAnchor, constant: -16),
            topRow.heightAnchor.constraint(equalToConstant: 100),

            bottomRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 12),
            bottomRow.leadingAnchor.constraint(equalTo: healthCardView.leadingAnchor, constant: 16),
            bottomRow.trailingAnchor.constraint(equalTo: healthCardView.trailingAnchor, constant: -16),
            bottomRow.heightAnchor.constraint(equalToConstant: 100),

            startCheckButton.topAnchor.constraint(equalTo: bottomRow.bottomAnchor, constant: 16),
            startCheckButton.leadingAnchor.constraint(equalTo: healthCardView.leadingAnchor, constant: 16),
            startCheckButton.trailingAnchor.constraint(equalTo: healthCardView.trailingAnchor, constant: -16),
            startCheckButton.heightAnchor.constraint(equalToConstant: 48),
            startCheckButton.bottomAnchor.constraint(equalTo: healthCardView.bottomAnchor, constant: -20),
        ])

        homeMetricCards[.heartRate] = heartRate.views
        homeMetricCards[.spo2] = spo2.views
        homeMetricCards[.stress] = stress.views
        homeMetricCards[.bloodPressure] = bp.views
        refreshHealthOverview()
    }

    // MARK: - Symptom Checker Card

    func setupSymptomCard() {
        contentView.addSubview(symptomCardView)
        symptomCardView.backgroundColor = AppDesign.Surface.elevatedCard
        symptomCardView.layer.cornerRadius = AppDesign.CornerRadius.heroCard
        symptomCardView.layer.shadowColor = UIColor.black.cgColor
        symptomCardView.layer.shadowOpacity = 0.04
        symptomCardView.layer.shadowOffset = CGSize(width: 0, height: 6)
        symptomCardView.layer.shadowRadius = 16
        symptomCardView.layer.borderWidth = 1
        symptomCardView.layer.borderColor = AppDesign.Surface.border.cgColor
        symptomInputContainer.backgroundColor = AppDesign.Surface.secondaryCard
        symptomInputContainer.layer.cornerRadius = AppDesign.CornerRadius.composer
        analyzeButton.backgroundColor = themeColor
        analyzeButton.layer.cornerRadius = AppDesign.CornerRadius.button

        let stethIcon = makeIconImageView(systemName: "stethoscope", color: themeColor, size: 20)
        let titleLabel = UILabel()
        aiCheckerLabel = titleLabel
        titleLabel.text = t(.mainAIChecker)
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        symptomCardView.addSubview(stethIcon)
        symptomCardView.addSubview(titleLabel)
        symptomCardView.addSubview(symptomInputContainer)
        symptomInputContainer.addSubview(symptomInputIcon)
        symptomInputContainer.addSubview(symptomTextField)
        symptomCardView.addSubview(analyzeButton)

        NSLayoutConstraint.activate([
            symptomCardView.topAnchor.constraint(equalTo: healthCardView.bottomAnchor, constant: 16),
            symptomCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            symptomCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            stethIcon.topAnchor.constraint(equalTo: symptomCardView.topAnchor, constant: 20),
            stethIcon.leadingAnchor.constraint(equalTo: symptomCardView.leadingAnchor, constant: 20),

            titleLabel.centerYAnchor.constraint(equalTo: stethIcon.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: stethIcon.trailingAnchor, constant: 8),

            symptomInputContainer.topAnchor.constraint(equalTo: stethIcon.bottomAnchor, constant: 16),
            symptomInputContainer.leadingAnchor.constraint(equalTo: symptomCardView.leadingAnchor, constant: 16),
            symptomInputContainer.trailingAnchor.constraint(equalTo: symptomCardView.trailingAnchor, constant: -16),
            symptomInputContainer.heightAnchor.constraint(equalToConstant: AppDesign.ControlSize.minimumTapTarget),

            symptomInputIcon.leadingAnchor.constraint(equalTo: symptomInputContainer.leadingAnchor, constant: 14),
            symptomInputIcon.centerYAnchor.constraint(equalTo: symptomInputContainer.centerYAnchor),
            symptomInputIcon.widthAnchor.constraint(equalToConstant: 18),
            symptomInputIcon.heightAnchor.constraint(equalToConstant: 18),

            symptomTextField.leadingAnchor.constraint(equalTo: symptomInputIcon.trailingAnchor, constant: 10),
            symptomTextField.trailingAnchor.constraint(equalTo: symptomInputContainer.trailingAnchor, constant: -12),
            symptomTextField.topAnchor.constraint(equalTo: symptomInputContainer.topAnchor),
            symptomTextField.bottomAnchor.constraint(equalTo: symptomInputContainer.bottomAnchor),

            analyzeButton.topAnchor.constraint(equalTo: symptomInputContainer.bottomAnchor, constant: 12),
            analyzeButton.leadingAnchor.constraint(equalTo: symptomCardView.leadingAnchor, constant: 16),
            analyzeButton.trailingAnchor.constraint(equalTo: symptomCardView.trailingAnchor, constant: -16),
            analyzeButton.heightAnchor.constraint(equalToConstant: AppDesign.ControlSize.minimumTapTarget),
            analyzeButton.bottomAnchor.constraint(equalTo: symptomCardView.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - Quick Access

    func setupQuickAccess() {
        let iconView = makeIconImageView(systemName: "viewfinder", color: themeColor, size: 18)
        let quickAccessLabel = UILabel()
        self.quickAccessLabel = quickAccessLabel
        quickAccessLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        contentView.addSubview(quickAccessLabel)

        quickAccessLabel.text = t(.mainQuickAccess)
        quickAccessLabel.font = .systemFont(ofSize: 18, weight: .bold)
        quickAccessLabel.textColor = .label

        let row1Items: [(icon: String, title: String, color: UIColor, tag: Int)] = [
            ("viewfinder", t(.mainQuickAccessAICheck), themeColor, 101),
            ("stethoscope", t(.mainQuickAccessConsult), .systemOrange, 102),
            ("airplane", t(.mainQuickAccessMedicalTourism), cardGreenColor, 103),
            ("doc.text", t(.mainQuickAccessRecords), .systemBlue, 104),
        ]

        let row2Items: [(icon: String, title: String, color: UIColor, tag: Int)] = [
            ("book", t(.mainQuickAccessHealthContent), themeColor, 105),
            ("lock.shield", t(.mainQuickAccessDevices), .systemTeal, 106),
            ("leaf", t(.mainQuickAccessNutrition), .systemOrange, 107),
            ("heart.circle", t(.mainQuickAccessCharity), .systemPink, 108),
        ]

        for item in row1Items {
            quickAccessRow1.addArrangedSubview(makeQuickAccessItem(icon: item.icon, title: item.title, color: item.color, tag: item.tag))
        }
        for item in row2Items {
            quickAccessRow2.addArrangedSubview(makeQuickAccessItem(icon: item.icon, title: item.title, color: item.color, tag: item.tag))
        }

        contentView.addSubview(quickAccessRow1)
        contentView.addSubview(quickAccessRow2)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: healthCardView.bottomAnchor, constant: 24),
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            quickAccessLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            quickAccessLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),

            quickAccessRow1.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            quickAccessRow1.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            quickAccessRow1.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            quickAccessRow1.heightAnchor.constraint(equalToConstant: 96),

            quickAccessRow2.topAnchor.constraint(equalTo: quickAccessRow1.bottomAnchor, constant: 8),
            quickAccessRow2.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            quickAccessRow2.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            quickAccessRow2.heightAnchor.constraint(equalToConstant: 96),
        ])
    }

    // MARK: - Connected Device

    func setupConnectedDeviceBanner() {
        connectedDeviceBanner.backgroundColor = AppDesign.Color.primaryGreen.withAlphaComponent(0.10)
        connectedDeviceBanner.layer.cornerRadius = 12
        connectedDeviceBanner.layer.borderWidth = 1
        connectedDeviceBanner.layer.borderColor = AppDesign.Color.primaryGreen.withAlphaComponent(0.18).cgColor
        connectedDeviceBanner.addTarget(self, action: #selector(connectedDeviceBannerTapped), for: .touchUpInside)
        contentView.addSubview(connectedDeviceBanner)

        let icon = makeIconImageView(systemName: "dot.radiowaves.left.and.right", color: themeColor, size: 18)
        let title = UILabel()
        title.text = "已连接设备"
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .label
        title.translatesAutoresizingMaskIntoConstraints = false
        connectedDeviceTitleLabel = title

        let subtitle = UILabel()
        subtitle.text = "查看健康设备与同步状态"
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabel
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        connectedDeviceSubtitleLabel = subtitle

        let chevron = makeIconImageView(systemName: "chevron.right", color: themeColor, size: 14)

        connectedDeviceBanner.addSubview(icon)
        connectedDeviceBanner.addSubview(title)
        connectedDeviceBanner.addSubview(subtitle)
        connectedDeviceBanner.addSubview(chevron)

        NSLayoutConstraint.activate([
            connectedDeviceBanner.topAnchor.constraint(equalTo: quickAccessRow2.bottomAnchor, constant: 20),
            connectedDeviceBanner.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            connectedDeviceBanner.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            connectedDeviceBanner.heightAnchor.constraint(equalToConstant: 64),

            icon.leadingAnchor.constraint(equalTo: connectedDeviceBanner.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: connectedDeviceBanner.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            title.topAnchor.constraint(equalTo: connectedDeviceBanner.topAnchor, constant: 13),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3),
            chevron.trailingAnchor.constraint(equalTo: connectedDeviceBanner.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: connectedDeviceBanner.centerYAnchor),
        ])
    }

    // MARK: - Today's Reminders

    func setupReminders() {
        let clockIcon = makeIconImageView(systemName: "clock", color: themeColor, size: 18)
        let titleLabel = UILabel()
        titleLabel.text = t(.mainRemindersTitle)
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        remindersTitleLabel = titleLabel

        let viewAllButton = UIButton(type: .system)
        self.viewAllButton = viewAllButton
        configureTrailingChevronButton(
            viewAllButton,
            title: t(.mainViewAll),
            color: themeColor,
            font: .systemFont(ofSize: 14, weight: .medium)
        )
        viewAllButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(clockIcon)
        contentView.addSubview(titleLabel)
        contentView.addSubview(viewAllButton)

        let reminder1 = makeReminderCard(
            icon: "pill", iconColor: themeColor,
            title: t(.mainReminderTakeMetformin), time: t(.mainReminderTime0800AM), isDone: false
        )
        let reminder2 = makeReminderCard(
            icon: "calendar", iconColor: .systemBlue,
            title: t(.mainReminderDrChenFollowup), time: t(.mainReminderTime0200PM), isDone: false
        )
        let reminder3 = makeReminderCard(
            icon: "waveform.path.ecg", iconColor: .systemPurple,
            title: t(.mainReminderWeeklyHealthCheck), time: t(.mainReminderAnytimeToday), isDone: true
        )

        contentView.addSubview(reminder1)
        contentView.addSubview(reminder2)
        contentView.addSubview(reminder3)

        NSLayoutConstraint.activate([
            clockIcon.topAnchor.constraint(equalTo: connectedDeviceBanner.bottomAnchor, constant: 24),
            clockIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            titleLabel.centerYAnchor.constraint(equalTo: clockIcon.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: clockIcon.trailingAnchor, constant: 8),

            viewAllButton.centerYAnchor.constraint(equalTo: clockIcon.centerYAnchor),
            viewAllButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            reminder1.topAnchor.constraint(equalTo: clockIcon.bottomAnchor, constant: 12),
            reminder1.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            reminder1.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            reminder2.topAnchor.constraint(equalTo: reminder1.bottomAnchor, constant: 10),
            reminder2.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            reminder2.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            reminder3.topAnchor.constraint(equalTo: reminder2.bottomAnchor, constant: 10),
            reminder3.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            reminder3.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])

        reminder3.tag = 9001
    }

    // MARK: - Recommended For You

    func setupRecommended() {
        guard let reminder3 = contentView.viewWithTag(9001) else { return }

        let bookIcon = makeIconImageView(systemName: "book", color: themeColor, size: 18)
        let titleLabel = UILabel()
        titleLabel.text = t(.mainRecommendedTitle)
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        recommendedTitleLabel = titleLabel

        let seeAllButton = UIButton(type: .system)
        configureTrailingChevronButton(
            seeAllButton,
            title: t(.mainSeeAll),
            color: themeColor,
            font: .systemFont(ofSize: 14, weight: .medium)
        )
        seeAllButton.translatesAutoresizingMaskIntoConstraints = false
        recommendedSeeAllButton = seeAllButton
        seeAllButton.addTarget(self, action: #selector(recommendedSeeAllTapped), for: .touchUpInside)

        contentView.addSubview(bookIcon)
        contentView.addSubview(titleLabel)
        contentView.addSubview(seeAllButton)

        let scrollContainer = UIScrollView()
        scrollContainer.showsHorizontalScrollIndicator = false
        scrollContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollContainer)

        let card1 = makeArticleCard(
            tag: t(.mainTagChronicCare),
            title: t(.mainArticleDiabetesWeather),
            readTime: t(.mainReadTime5Min),
            bgColor: cardGreenColor,
            icon: "book"
        )
        let card2 = makeArticleCard(
            tag: t(.mainTagMedicalTourism),
            title: t(.mainArticleCrossBorderGuide),
            readTime: t(.mainReadTime8Min),
            bgColor: UIColor(red: 0.25, green: 0.52, blue: 0.60, alpha: 1.0),
            icon: "airplane"
        )
        card1.accessibilityIdentifier = "chronic-care"
        card2.accessibilityIdentifier = "medical-tourism"
        [card1, card2].forEach {
            $0.isUserInteractionEnabled = true
            $0.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(recommendedArticleTapped(_:))))
        }

        scrollContainer.addSubview(card1)
        scrollContainer.addSubview(card2)

        let cardWidth: CGFloat = 200

        NSLayoutConstraint.activate([
            bookIcon.topAnchor.constraint(equalTo: reminder3.bottomAnchor, constant: 24),
            bookIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            titleLabel.centerYAnchor.constraint(equalTo: bookIcon.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: bookIcon.trailingAnchor, constant: 8),

            seeAllButton.centerYAnchor.constraint(equalTo: bookIcon.centerYAnchor),
            seeAllButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            scrollContainer.topAnchor.constraint(equalTo: bookIcon.bottomAnchor, constant: 12),
            scrollContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollContainer.heightAnchor.constraint(equalToConstant: 220),
            scrollContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            card1.topAnchor.constraint(equalTo: scrollContainer.topAnchor),
            card1.leadingAnchor.constraint(equalTo: scrollContainer.leadingAnchor, constant: 20),
            card1.bottomAnchor.constraint(equalTo: scrollContainer.bottomAnchor),
            card1.widthAnchor.constraint(equalToConstant: cardWidth),
            card1.heightAnchor.constraint(equalToConstant: 220),

            card2.topAnchor.constraint(equalTo: scrollContainer.topAnchor),
            card2.leadingAnchor.constraint(equalTo: card1.trailingAnchor, constant: 12),
            card2.bottomAnchor.constraint(equalTo: scrollContainer.bottomAnchor),
            card2.widthAnchor.constraint(equalToConstant: cardWidth),
            card2.heightAnchor.constraint(equalToConstant: 220),
            card2.trailingAnchor.constraint(equalTo: scrollContainer.trailingAnchor, constant: -20),
        ])
    }

    @objc private func recommendedArticleTapped(_ gesture: UITapGestureRecognizer) {
        switch gesture.view?.accessibilityIdentifier {
        case "medical-tourism":
            navigationController?.pushViewController(MedicalHubViewController(), animated: true)
        default:
            if let tabController = tabBarController as? MainTabBarController {
                tabController.openChatTab(prefillText: "请解释这篇健康建议，并区分趋势数据与医疗诊断。")
            }
        }
    }

    // MARK: - View Factories

    private func makeIconImageView(systemName: String, color: UIColor, size: CGFloat) -> UIImageView {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        let iv = UIImageView(image: UIImage(systemName: systemName, withConfiguration: config))
        iv.tintColor = color
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: size + 8),
            iv.heightAnchor.constraint(equalToConstant: size + 8),
        ])
        return iv
    }

    private func makeHomeMetricCard(icon: String, type: HomeMetricType) -> (view: UIView, views: HomeMetricCardViews) {
        let card = UIView()
        card.backgroundColor = metricCardColor
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconIV.tintColor = .white
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.font = .systemFont(ofSize: 13, weight: .medium)
        titleLbl.textColor = UIColor.white.withAlphaComponent(0.9)
        titleLbl.textAlignment = .natural
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        let valueLbl = UILabel()
        valueLbl.font = .systemFont(ofSize: 28, weight: .bold)
        valueLbl.textColor = .white
        valueLbl.textAlignment = .natural
        valueLbl.translatesAutoresizingMaskIntoConstraints = false

        let unitLbl = UILabel()
        unitLbl.font = .systemFont(ofSize: 14, weight: .medium)
        unitLbl.textColor = UIColor.white.withAlphaComponent(0.8)
        unitLbl.textAlignment = .natural
        unitLbl.translatesAutoresizingMaskIntoConstraints = false

        let valueStack = UIStackView(arrangedSubviews: [valueLbl, unitLbl])
        valueStack.axis = .horizontal
        valueStack.spacing = 4
        valueStack.alignment = .lastBaseline
        valueStack.translatesAutoresizingMaskIntoConstraints = false

        let dot = UIView()
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false

        let statusLbl = UILabel()
        statusLbl.font = .systemFont(ofSize: 12, weight: .medium)
        statusLbl.textColor = UIColor.white.withAlphaComponent(0.9)
        statusLbl.textAlignment = .natural
        statusLbl.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconIV)
        card.addSubview(titleLbl)
        card.addSubview(valueStack)
        card.addSubview(dot)
        card.addSubview(statusLbl)

        NSLayoutConstraint.activate([
            iconIV.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            iconIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),

            titleLbl.centerYAnchor.constraint(equalTo: iconIV.centerYAnchor),
            titleLbl.leadingAnchor.constraint(equalTo: iconIV.trailingAnchor, constant: 6),

            valueStack.topAnchor.constraint(equalTo: iconIV.bottomAnchor, constant: 8),
            valueStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),

            dot.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            dot.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            statusLbl.centerYAnchor.constraint(equalTo: dot.centerYAnchor),
            statusLbl.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
        ])

        return (
            card,
            HomeMetricCardViews(
                titleLabel: titleLbl,
                valueLabel: valueLbl,
                unitLabel: unitLbl,
                statusLabel: statusLbl,
                statusDot: dot
            )
        )
    }

    private func makeReminderCard(icon: String, iconColor: UIColor, title: String, time: String, isDone: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
        card.translatesAutoresizingMaskIntoConstraints = false

        let circle = UIView()
        circle.backgroundColor = iconColor.withAlphaComponent(0.1)
        circle.layer.cornerRadius = 20
        circle.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconIV.tintColor = iconColor
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        circle.addSubview(iconIV)
        card.addSubview(circle)

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLbl.textColor = isDone ? .tertiaryLabel : .label
        titleLbl.textAlignment = .natural
        if isDone {
            let attr = NSAttributedString(string: title, attributes: [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: UIColor.tertiaryLabel,
            ])
            titleLbl.attributedText = attr
        }
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLbl)

        let timeContainer = UIView()
        timeContainer.translatesAutoresizingMaskIntoConstraints = false

        let clockConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        let clockIV = UIImageView(image: UIImage(systemName: "clock", withConfiguration: clockConfig))
        clockIV.tintColor = .tertiaryLabel
        clockIV.translatesAutoresizingMaskIntoConstraints = false

        let timeLbl = UILabel()
        timeLbl.text = time
        timeLbl.font = .systemFont(ofSize: 12)
        timeLbl.textColor = .tertiaryLabel
        timeLbl.textAlignment = .natural
        timeLbl.translatesAutoresizingMaskIntoConstraints = false

        timeContainer.addSubview(clockIV)
        timeContainer.addSubview(timeLbl)
        card.addSubview(timeContainer)

        if isDone {
            let doneBadge = UILabel()
            doneBadge.text = t(.mainReminderDone)
            doneBadge.font = .systemFont(ofSize: 13, weight: .semibold)
            doneBadge.textColor = .white
            doneBadge.backgroundColor = themeColor
            doneBadge.textAlignment = .center
            doneBadge.layer.cornerRadius = 14
            doneBadge.clipsToBounds = true
            doneBadge.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(doneBadge)
            reminderEntries.append((title: titleLbl, time: timeLbl, actionView: doneBadge))

            NSLayoutConstraint.activate([
                doneBadge.centerYAnchor.constraint(equalTo: card.centerYAnchor),
                doneBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                doneBadge.widthAnchor.constraint(equalToConstant: 60),
                doneBadge.heightAnchor.constraint(equalToConstant: 28),
            ])
        } else {
            let markButton = UIButton(type: .system)
            markButton.setTitle(t(.mainReminderMarkDone), for: .normal)
            markButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            markButton.setTitleColor(.label, for: .normal)
            markButton.backgroundColor = UIColor.secondarySystemBackground
            markButton.layer.cornerRadius = 14
            markButton.translatesAutoresizingMaskIntoConstraints = false
            markButton.addTarget(self, action: #selector(reminderMarkDoneTapped(_:)), for: .touchUpInside)
            card.addSubview(markButton)
            reminderEntries.append((title: titleLbl, time: timeLbl, actionView: markButton))

            NSLayoutConstraint.activate([
                markButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
                markButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                markButton.widthAnchor.constraint(equalToConstant: 90),
                markButton.heightAnchor.constraint(equalToConstant: 28),
            ])
        }

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 68),

            circle.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            circle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            circle.widthAnchor.constraint(equalToConstant: 40),
            circle.heightAnchor.constraint(equalToConstant: 40),

            iconIV.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: circle.centerYAnchor),

            titleLbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            titleLbl.leadingAnchor.constraint(equalTo: circle.trailingAnchor, constant: 12),

            timeContainer.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 4),
            timeContainer.leadingAnchor.constraint(equalTo: circle.trailingAnchor, constant: 12),

            clockIV.leadingAnchor.constraint(equalTo: timeContainer.leadingAnchor),
            clockIV.centerYAnchor.constraint(equalTo: timeContainer.centerYAnchor),

            timeLbl.leadingAnchor.constraint(equalTo: clockIV.trailingAnchor, constant: 4),
            timeLbl.centerYAnchor.constraint(equalTo: timeContainer.centerYAnchor),
            timeLbl.trailingAnchor.constraint(equalTo: timeContainer.trailingAnchor),

            timeContainer.heightAnchor.constraint(equalToConstant: 16),
        ])

        return card
    }

    @objc private func reminderMarkDoneTapped(_ sender: UIButton) {
        sender.setTitle(t(.mainReminderDone), for: .normal)
        sender.setTitleColor(.white, for: .normal)
        sender.backgroundColor = themeColor
        sender.isEnabled = false
        coachCompleteTapped()
    }

    private func makeArticleCard(tag: String, title: String, readTime: String, bgColor: UIColor, icon: String) -> UIView {
        let card = UIView()
        card.backgroundColor = bgColor
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconIV.tintColor = UIColor.white.withAlphaComponent(0.3)
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconIV)

        let tagLabel = UILabel()
        tagLabel.text = tag
        tagLabel.font = .systemFont(ofSize: 11, weight: .medium)
        tagLabel.textColor = .white
        tagLabel.textAlignment = .natural
        tagLabel.translatesAutoresizingMaskIntoConstraints = false

        let tagPill = UIView()
        tagPill.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        tagPill.layer.cornerRadius = 10
        tagPill.translatesAutoresizingMaskIntoConstraints = false
        tagPill.addSubview(tagLabel)
        card.addSubview(tagPill)

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 15, weight: .bold)
        titleLbl.textColor = .white
        titleLbl.numberOfLines = 2
        titleLbl.textAlignment = .natural
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLbl)

        let clockConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        let clockIV = UIImageView(image: UIImage(systemName: "clock", withConfiguration: clockConfig))
        clockIV.tintColor = UIColor.white.withAlphaComponent(0.7)
        clockIV.translatesAutoresizingMaskIntoConstraints = false

        let timeLbl = UILabel()
        timeLbl.text = readTime
        timeLbl.font = .systemFont(ofSize: 12)
        timeLbl.textColor = UIColor.white.withAlphaComponent(0.7)
        timeLbl.textAlignment = .natural
        timeLbl.translatesAutoresizingMaskIntoConstraints = false
        articleEntries.append((tag: tagLabel, title: titleLbl, time: timeLbl))

        card.addSubview(clockIV)
        card.addSubview(timeLbl)

        NSLayoutConstraint.activate([
            iconIV.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            iconIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            tagPill.topAnchor.constraint(equalTo: iconIV.bottomAnchor, constant: 30),
            tagPill.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            tagPill.heightAnchor.constraint(equalToConstant: 20),

            tagLabel.leadingAnchor.constraint(equalTo: tagPill.leadingAnchor, constant: 8),
            tagLabel.trailingAnchor.constraint(equalTo: tagPill.trailingAnchor, constant: -8),
            tagLabel.centerYAnchor.constraint(equalTo: tagPill.centerYAnchor),

            titleLbl.topAnchor.constraint(equalTo: tagPill.bottomAnchor, constant: 10),
            titleLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            titleLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            clockIV.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            clockIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            timeLbl.centerYAnchor.constraint(equalTo: clockIV.centerYAnchor),
            timeLbl.leadingAnchor.constraint(equalTo: clockIV.trailingAnchor, constant: 4),
        ])

        return card
    }

    private func makeQuickAccessItem(icon: String, title: String, color: UIColor, tag: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = AppDesign.Surface.elevatedCard
        container.layer.cornerRadius = AppDesign.CornerRadius.card
        container.layer.borderWidth = 1
        container.layer.borderColor = AppDesign.Surface.border.cgColor

        let circle = UIView()
        circle.isUserInteractionEnabled = false
        circle.backgroundColor = color.withAlphaComponent(0.14)
        circle.layer.cornerRadius = 24
        circle.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: config))
        iconIV.tintColor = color
        iconIV.contentMode = .scaleAspectFit
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.isUserInteractionEnabled = false
        label.text = title
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        quickAccessTitleLabels.append(label)

        container.addSubview(circle)
        circle.addSubview(iconIV)
        container.addSubview(label)

        let button = UIButton(type: .system)
        button.tag = tag
        button.accessibilityLabel = title
        button.addTarget(self, action: #selector(quickAccessItemTapped(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)

        NSLayoutConstraint.activate([
            circle.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            circle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            circle.widthAnchor.constraint(equalToConstant: 48),
            circle.heightAnchor.constraint(equalToConstant: 48),

            iconIV.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: circle.centerYAnchor),

            label.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -10),

            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }
}
