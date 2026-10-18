import UIKit

extension HealthViewController {

    // MARK: - Setup ScrollView

    func setupScrollView() {
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

    // MARK: - Header Section

    func setupHeaderSection() {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)
        header.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 64),
            titleLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor),
        ])
        contentStack.addArrangedSubview(header)
    }

    // MARK: - Section Builders

    func setupVitalsCard() {
        let card = makeCardView()

        let sectionIcon = makeSymbolIV("waveform.path.ecg", color: themeColor)
        card.addSubview(sectionIcon)
        card.addSubview(vitalsCardTitleLabel)
        card.addSubview(newCheckButton)
        newCheckButton.addTarget(self, action: #selector(newCheckTapped), for: .touchUpInside)

        let grid = UIView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(grid)

        let hrView = makeVitalCell(icon: "heart.fill", iconColor: .systemRed, type: .heartRate, valueLabel: hrValueLabel)
        let spo2View = makeVitalCell(icon: "lungs.fill", iconColor: .systemBlue, type: .spo2, valueLabel: spo2ValueLabel)
        let rrView = makeVitalCell(icon: "wind", iconColor: .systemPurple, type: .respiratoryRate, valueLabel: rrValueLabel)
        let stressView = makeVitalCell(icon: "brain.head.profile", iconColor: .systemOrange, type: .stress, valueLabel: stressValueLabel)

        grid.addSubview(hrView.view)
        grid.addSubview(spo2View.view)
        grid.addSubview(rrView.view)
        grid.addSubview(stressView.view)

        let vSep = makeThinLine()
        let hSep = makeThinLine()
        grid.addSubview(vSep)
        grid.addSubview(hSep)

        NSLayoutConstraint.activate([
            sectionIcon.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            sectionIcon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            vitalsCardTitleLabel.centerYAnchor.constraint(equalTo: sectionIcon.centerYAnchor),
            vitalsCardTitleLabel.leadingAnchor.constraint(equalTo: sectionIcon.trailingAnchor, constant: 8),
            newCheckButton.centerYAnchor.constraint(equalTo: sectionIcon.centerYAnchor),
            newCheckButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            grid.topAnchor.constraint(equalTo: vitalsCardTitleLabel.bottomAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            grid.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            grid.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            grid.heightAnchor.constraint(equalToConstant: 160),

            hrView.view.topAnchor.constraint(equalTo: grid.topAnchor),
            hrView.view.leadingAnchor.constraint(equalTo: grid.leadingAnchor),
            hrView.view.trailingAnchor.constraint(equalTo: grid.centerXAnchor),
            hrView.view.heightAnchor.constraint(equalTo: grid.heightAnchor, multiplier: 0.5),

            spo2View.view.topAnchor.constraint(equalTo: grid.topAnchor),
            spo2View.view.leadingAnchor.constraint(equalTo: grid.centerXAnchor),
            spo2View.view.trailingAnchor.constraint(equalTo: grid.trailingAnchor),
            spo2View.view.heightAnchor.constraint(equalTo: grid.heightAnchor, multiplier: 0.5),

            rrView.view.bottomAnchor.constraint(equalTo: grid.bottomAnchor),
            rrView.view.leadingAnchor.constraint(equalTo: grid.leadingAnchor),
            rrView.view.trailingAnchor.constraint(equalTo: grid.centerXAnchor),
            rrView.view.heightAnchor.constraint(equalTo: grid.heightAnchor, multiplier: 0.5),

            stressView.view.bottomAnchor.constraint(equalTo: grid.bottomAnchor),
            stressView.view.leadingAnchor.constraint(equalTo: grid.centerXAnchor),
            stressView.view.trailingAnchor.constraint(equalTo: grid.trailingAnchor),
            stressView.view.heightAnchor.constraint(equalTo: grid.heightAnchor, multiplier: 0.5),

            vSep.centerXAnchor.constraint(equalTo: grid.centerXAnchor),
            vSep.topAnchor.constraint(equalTo: grid.topAnchor, constant: 8),
            vSep.bottomAnchor.constraint(equalTo: grid.bottomAnchor, constant: -8),
            vSep.widthAnchor.constraint(equalToConstant: 0.5),

            hSep.centerYAnchor.constraint(equalTo: grid.centerYAnchor),
            hSep.leadingAnchor.constraint(equalTo: grid.leadingAnchor, constant: 8),
            hSep.trailingAnchor.constraint(equalTo: grid.trailingAnchor, constant: -8),
            hSep.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        vitalTitleLabels[.heartRate] = hrView.titleLabel
        vitalTitleLabels[.spo2] = spo2View.titleLabel
        vitalTitleLabels[.respiratoryRate] = rrView.titleLabel
        vitalTitleLabels[.stress] = stressView.titleLabel
        vitalUnitLabels[.heartRate] = hrView.unitLabel
        vitalUnitLabels[.spo2] = spo2View.unitLabel
        vitalUnitLabels[.respiratoryRate] = rrView.unitLabel
        vitalUnitLabels[.stress] = stressView.unitLabel

        contentStack.addArrangedSubview(card)
    }

    func setupBasicInfoCard() {
        let card = makeCardView()
        let sectionIcon = makeSymbolIV("person.text.rectangle", color: themeColor)
        card.addSubview(sectionIcon)
        card.addSubview(basicInfoTitleLabel)
        card.addSubview(editProfileButton)
        card.addSubview(familyProfilesStatusLabel)
        card.addSubview(profileSwitcherScrollView)
        profileSwitcherScrollView.addSubview(profileSwitcherStack)
        editProfileButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)
        familyProfilesStatusLabel.isUserInteractionEnabled = true
        familyProfilesStatusLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(familyProfilesTapped)))

        let pairs: [(UILabel, UILabel)] = [
            (nameKeyLabel, nameValueLabel),
            (genderKeyLabel, genderValueLabel),
            (birthdayKeyLabel, birthdayValueLabel),
            (heightKeyLabel, heightValueLabel),
            (weightKeyLabel, weightValueLabel),
            (bloodTypeKeyLabel, bloodTypeValueLabel),
        ]
        let pairViews = pairs.map { makeInfoCell(key: $0.0, value: $0.1) }

        let row1 = makeHRow([pairViews[0], pairViews[1], pairViews[2]])
        let row2 = makeHRow([pairViews[3], pairViews[4], pairViews[5]])
        let infoStack = UIStackView(arrangedSubviews: [row1, row2])
        infoStack.axis = .vertical
        infoStack.spacing = 12
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(infoStack)

        NSLayoutConstraint.activate([
            sectionIcon.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            sectionIcon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            basicInfoTitleLabel.centerYAnchor.constraint(equalTo: sectionIcon.centerYAnchor),
            basicInfoTitleLabel.leadingAnchor.constraint(equalTo: sectionIcon.trailingAnchor, constant: 8),
            editProfileButton.centerYAnchor.constraint(equalTo: sectionIcon.centerYAnchor),
            editProfileButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            familyProfilesStatusLabel.topAnchor.constraint(equalTo: sectionIcon.bottomAnchor, constant: 14),
            familyProfilesStatusLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            familyProfilesStatusLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            profileSwitcherScrollView.topAnchor.constraint(equalTo: familyProfilesStatusLabel.bottomAnchor, constant: 12),
            profileSwitcherScrollView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            profileSwitcherScrollView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            profileSwitcherScrollView.heightAnchor.constraint(equalToConstant: 36),
            profileSwitcherStack.topAnchor.constraint(equalTo: profileSwitcherScrollView.contentLayoutGuide.topAnchor),
            profileSwitcherStack.leadingAnchor.constraint(equalTo: profileSwitcherScrollView.contentLayoutGuide.leadingAnchor),
            profileSwitcherStack.trailingAnchor.constraint(equalTo: profileSwitcherScrollView.contentLayoutGuide.trailingAnchor),
            profileSwitcherStack.bottomAnchor.constraint(equalTo: profileSwitcherScrollView.contentLayoutGuide.bottomAnchor),
            profileSwitcherStack.heightAnchor.constraint(equalTo: profileSwitcherScrollView.frameLayoutGuide.heightAnchor),
            infoStack.topAnchor.constraint(equalTo: profileSwitcherScrollView.bottomAnchor, constant: 12),
            infoStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            infoStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            infoStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        contentStack.addArrangedSubview(card)
    }

    func setupCheckHistoryCard() {
        let card = makeCardView()
        let sectionIcon = makeSymbolIV("clock", color: themeColor)
        card.addSubview(sectionIcon)
        card.addSubview(checkHistoryTitleLabel)
        checkHistoryTrendStack.addArrangedSubview(checkHistoryMetricControl)
        checkHistoryTrendStack.addArrangedSubview(checkHistoryTrendTitleLabel)
        checkHistoryTrendStack.addArrangedSubview(checkHistoryRangeControl)
        checkHistoryTrendStack.addArrangedSubview(checkHistoryTrendView)
        card.addSubview(checkHistoryTrendStack)
        card.addSubview(checkHistoryStack)
        NSLayoutConstraint.activate([
            sectionIcon.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            sectionIcon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            checkHistoryTitleLabel.centerYAnchor.constraint(equalTo: sectionIcon.centerYAnchor),
            checkHistoryTitleLabel.leadingAnchor.constraint(equalTo: sectionIcon.trailingAnchor, constant: 8),
            checkHistoryTrendView.heightAnchor.constraint(equalToConstant: 100),
            checkHistoryTrendStack.topAnchor.constraint(equalTo: sectionIcon.bottomAnchor, constant: 16),
            checkHistoryTrendStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            checkHistoryTrendStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            checkHistoryStack.topAnchor.constraint(equalTo: checkHistoryTrendStack.bottomAnchor, constant: 16),
            checkHistoryStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            checkHistoryStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            checkHistoryStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        contentStack.addArrangedSubview(card)
    }

    func setupOcrCard() {
        let card = makeCardView()
        let sectionIcon = makeSymbolIV("doc.text.magnifyingglass", color: themeColor)
        let actionRow = UIStackView(arrangedSubviews: [ocrViewAllButton, uploadReportButton])
        actionRow.axis = .horizontal
        actionRow.alignment = .center
        actionRow.spacing = 12
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(sectionIcon)
        card.addSubview(ocrTitleLabel)
        card.addSubview(actionRow)
        ocrViewAllButton.addTarget(self, action: #selector(viewAllOcrTapped), for: .touchUpInside)
        uploadReportButton.addTarget(self, action: #selector(uploadReportTapped), for: .touchUpInside)
        card.addSubview(ocrLoadingLabel)
        card.addSubview(ocrHistoryStack)
        NSLayoutConstraint.activate([
            sectionIcon.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            sectionIcon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            ocrTitleLabel.centerYAnchor.constraint(equalTo: sectionIcon.centerYAnchor),
            ocrTitleLabel.leadingAnchor.constraint(equalTo: sectionIcon.trailingAnchor, constant: 8),
            ocrTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionRow.leadingAnchor, constant: -12),
            actionRow.centerYAnchor.constraint(equalTo: sectionIcon.centerYAnchor),
            actionRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            ocrLoadingLabel.topAnchor.constraint(equalTo: sectionIcon.bottomAnchor, constant: 16),
            ocrLoadingLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            ocrHistoryStack.topAnchor.constraint(equalTo: sectionIcon.bottomAnchor, constant: 16),
            ocrHistoryStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            ocrHistoryStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            ocrHistoryStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        contentStack.addArrangedSubview(card)
    }

    func setupSyncCard() {
        let card = makeCardView()
        let sectionIcon = makeSymbolIV("arrow.triangle.2.circlepath", color: themeColor)
        card.addSubview(sectionIcon)
        card.addSubview(syncNowButton)
        card.addSubview(syncStatusLabel)
        NSLayoutConstraint.activate([
            sectionIcon.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            sectionIcon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            syncNowButton.centerYAnchor.constraint(equalTo: sectionIcon.centerYAnchor),
            syncNowButton.leadingAnchor.constraint(equalTo: sectionIcon.trailingAnchor, constant: 12),
            syncNowButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            syncNowButton.heightAnchor.constraint(equalToConstant: 40),

            syncStatusLabel.topAnchor.constraint(equalTo: syncNowButton.bottomAnchor, constant: 8),
            syncStatusLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            syncStatusLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            syncStatusLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        contentStack.addArrangedSubview(card)
    }

    func setupWomenHealthCard() {
        let card = makeCardView()
        let icon = makeSymbolIV("heart.text.square", color: .systemPink)
        let title = UILabel(); title.text = "女性健康"; title.font = .systemFont(ofSize: 17, weight: .semibold)
        let detail = UILabel(); detail.text = "周期、备孕与孕期记录（本地教育性估算）"; detail.textColor = .secondaryLabel; detail.font = .systemFont(ofSize: 13); detail.numberOfLines = 2
        let button = UIButton(type: .system); button.setTitle("查看", for: .normal); button.addTarget(self, action: #selector(womenHealthTapped), for: .touchUpInside)
        [icon, title, detail, button].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; card.addSubview($0) }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16), icon.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10), title.centerYAnchor.constraint(equalTo: icon.centerYAnchor), button.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16), button.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor), detail.trailingAnchor.constraint(equalTo: button.leadingAnchor, constant: -8), detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 7), detail.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        contentStack.addArrangedSubview(card)
    }

    @objc func womenHealthTapped() { navigationController?.pushViewController(WomenHealthViewController(), animated: true) }

    func addBottomSpacer() {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        contentStack.addArrangedSubview(spacer)
    }

    // MARK: - Row / Cell Builders

    func makeCheckRow(_ record: HealthRecord) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let metricStatus = metricStatusText(for: selectedHistoryMetric, record: record)
        let hasMetricValue = metricValue(for: selectedHistoryMetric, in: record) != nil

        let dateLabel = UILabel()
        dateLabel.text = dateFormatter.string(from: record.date)
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .secondaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        let metricLabel = UILabel()
        metricLabel.text = displayMetricText(for: selectedHistoryMetric, record: record)
        metricLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        metricLabel.textColor = .label
        metricLabel.translatesAutoresizingMaskIntoConstraints = false

        let statusLabel = UILabel()
        statusLabel.text = metricStatus
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.backgroundColor = statusColor(metricStatus)
        statusLabel.layer.cornerRadius = 9
        statusLabel.clipsToBounds = true
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.isHidden = !hasMetricValue || metricStatus == nil

        row.addSubview(dateLabel)
        row.addSubview(metricLabel)
        row.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 36),
            dateLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            dateLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            metricLabel.centerXAnchor.constraint(equalTo: row.centerXAnchor),
            metricLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
            statusLabel.heightAnchor.constraint(equalToConstant: 18),
        ])
        return row
    }

    func makeOcrRow(_ report: OcrReport) -> UIView {
        let row = OcrRowView(report: report)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.backgroundColor = UIColor.systemGray6
        row.layer.cornerRadius = 12
        row.addTarget(self, action: #selector(ocrRowTapped(_:)), for: .touchUpInside)

        let dateLabel = UILabel()
        dateLabel.text = ocrDateText(for: report.date)
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .secondaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        let countLabel = UILabel()
        let abnormalCount = report.items.filter { $0.isAbnormal }.count
        countLabel.text = abnormalCount > 0
            ? String(format: t(.ocrReportMetricsAbnormalFormat), report.items.count, abnormalCount)
            : String(format: t(.ocrReportMetricsNormalFormat), report.items.count)
        countLabel.font = .systemFont(ofSize: 13, weight: .medium)
        countLabel.textColor = .label
        countLabel.numberOfLines = 2
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        let sourceLabel = HealthPagePaddingLabel()
        sourceLabel.text = report.source == .cloud ? t(.ocrReportSourceCloud) : t(.ocrReportSourceDevice)
        sourceLabel.font = .systemFont(ofSize: 11, weight: .medium)
        sourceLabel.textColor = report.source == .cloud ? .systemBlue : .secondaryLabel
        sourceLabel.backgroundColor = report.source == .cloud ? UIColor.systemBlue.withAlphaComponent(0.12) : UIColor.systemGray5
        sourceLabel.layer.cornerRadius = 9
        sourceLabel.clipsToBounds = true
        sourceLabel.insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false

        let badgeLabel = HealthPagePaddingLabel()
        badgeLabel.text = abnormalCount > 0
            ? String(format: t(.ocrReportAbnormalCountFormat), abnormalCount)
            : t(.ocrReportAllNormal)
        badgeLabel.font = .systemFont(ofSize: 11, weight: .medium)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = abnormalCount > 0 ? .systemOrange : .systemGreen
        badgeLabel.layer.cornerRadius = 9
        badgeLabel.clipsToBounds = true
        badgeLabel.insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)))
        chevron.tintColor = .tertiaryLabel
        chevron.translatesAutoresizingMaskIntoConstraints = false

        let metaRow = UIStackView(arrangedSubviews: [sourceLabel, badgeLabel])
        metaRow.axis = .horizontal
        metaRow.spacing = 8
        metaRow.alignment = .leading
        metaRow.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [dateLabel, countLabel, metaRow])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.alignment = .fill
        textStack.translatesAutoresizingMaskIntoConstraints = false

        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 86).isActive = true
        row.contentHorizontalAlignment = .fill
        row.contentVerticalAlignment = .fill

        row.addSubview(textStack)
        row.addSubview(chevron)
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12),
            textStack.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -12),
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 10),
            chevron.heightAnchor.constraint(equalToConstant: 14),
        ])
        return row
    }

    func makeEmptyLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    // MARK: - Generic Builders

    private func makeCardView() -> UIView {
        let v = UIView()
        v.backgroundColor = AppDesign.Surface.elevatedCard
        v.layer.cornerRadius = AppDesign.CornerRadius.heroCard
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.04
        v.layer.shadowOffset = CGSize(width: 0, height: 6)
        v.layer.shadowRadius = 16
        v.layer.borderWidth = 1
        v.layer.borderColor = AppDesign.Surface.border.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func makeSymbolIV(_ name: String, color: UIColor) -> UIImageView {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iv = UIImageView(image: UIImage(systemName: name, withConfiguration: config))
        iv.tintColor = color
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.setContentHuggingPriority(.required, for: .horizontal)
        return iv
    }

    private func makeVitalCell(icon: String, iconColor: UIColor, type: HealthMetricType, valueLabel: UILabel) -> (view: UIView, titleLabel: UILabel, unitLabel: UILabel) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: icon, withConfiguration: config))
        iconIV.tintColor = iconColor
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        let titleLbl = UILabel()
        titleLbl.text = historyMetricTitle(type)
        titleLbl.font = .systemFont(ofSize: 12)
        titleLbl.textColor = .secondaryLabel
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        let unitLbl = UILabel()
        unitLbl.text = defaultUnit(for: type)
        unitLbl.font = .systemFont(ofSize: 12)
        unitLbl.textColor = .secondaryLabel
        unitLbl.translatesAutoresizingMaskIntoConstraints = false
        let topRow = UIStackView(arrangedSubviews: [iconIV, titleLbl])
        topRow.axis = .horizontal
        topRow.spacing = 4
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false
        let bottomRow = UIStackView(arrangedSubviews: [valueLabel, unitLbl])
        bottomRow.axis = .horizontal
        bottomRow.spacing = 2
        bottomRow.alignment = .firstBaseline
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(topRow)
        container.addSubview(bottomRow)
        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            topRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            bottomRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 6),
            bottomRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
        ])
        return (container, titleLbl, unitLbl)
    }

    private func makeInfoCell(key: UILabel, value: UILabel) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(key)
        v.addSubview(value)
        NSLayoutConstraint.activate([
            key.topAnchor.constraint(equalTo: v.topAnchor),
            key.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            value.topAnchor.constraint(equalTo: key.bottomAnchor, constant: 4),
            value.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            value.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor),
            value.bottomAnchor.constraint(equalTo: v.bottomAnchor),
        ])
        return v
    }

    private func makeHRow(_ views: [UIView]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func makeThinLine() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    static func makeBigValueLabel() -> UILabel {
        let l = UILabel()
        l.text = "--"
        l.font = .systemFont(ofSize: 26, weight: .bold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    static func makeInfoValueLabel() -> UILabel {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor = .label
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    static func makeInfoKeyLabel() -> UILabel {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    func historyMetricTitle(_ metric: HealthMetricType) -> String {
        switch metric {
        case .heartRate: return t(.healthRecordHeartRate)
        case .spo2: return t(.healthRecordSpO2)
        case .respiratoryRate: return t(.healthRecordRespRate)
        case .stress: return t(.healthRecordStressScore)
        }
    }

    func historyMetricShortTitle(_ metric: HealthMetricType) -> String {
        switch metric {
        case .heartRate: return t(.healthResultHR)
        case .spo2: return t(.healthResultSpO2)
        case .respiratoryRate: return t(.healthResultRR)
        case .stress: return t(.healthResultStress)
        }
    }

    func defaultUnit(for metric: HealthMetricType) -> String {
        switch metric {
        case .heartRate: return t(.unitBpm)
        case .spo2: return "%"
        case .respiratoryRate: return t(.unitBreathPerMin)
        case .stress: return "/100"
        }
    }

    func metricValue(for metric: HealthMetricType, in record: HealthRecord) -> Double? {
        switch metric {
        case .heartRate: return record.hr
        case .spo2: return record.spo2
        case .respiratoryRate: return record.rr
        case .stress: return record.stressScore
        }
    }

    func metricStatusText(for metric: HealthMetricType, record: HealthRecord) -> String? {
        switch metric {
        case .heartRate: return record.hrStatus
        case .spo2: return record.spo2Status
        case .respiratoryRate: return record.rrStatus
        case .stress: return record.stressLevel
        }
    }

    private func displayMetricText(for metric: HealthMetricType, record: HealthRecord) -> String {
        guard let value = metricValue(for: metric, in: record) else { return "--" }
        let formattedValue = String(format: "%.0f", value)
        return "\(formattedValue) \(defaultUnit(for: metric))"
    }

    private func statusColor(_ status: String?) -> UIColor {
        switch status?.lowercased() {
        case "normal", "正常": return .systemGreen
        case "high", "偏高": return .systemOrange
        case "low", "偏低": return .systemBlue
        default: return AppDesign.Color.primaryGreen
        }
    }
}
