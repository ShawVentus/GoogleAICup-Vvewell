import UIKit

extension HealthViewController {

    // MARK: - Localization & Refresh

    func updateTexts() {
        titleLabel.text = t(.healthRecordTitle)
        subtitleLabel.text = t(.healthRecordSubtitle)
        vitalsCardTitleLabel.text = t(.healthRecordLatestVitals)
        basicInfoTitleLabel.text = t(.healthProfileBasicInfo)
        configureTrailingChevronButton(
            newCheckButton,
            title: t(.healthRecordNewCheck),
            color: themeColor,
            font: .systemFont(ofSize: 14, weight: .medium)
        )
        newCheckButton.accessibilityLabel = t(.healthRecordNewCheck)
        editProfileButton.setTitle(t(.healthProfileEdit), for: .normal)
        editProfileButton.accessibilityLabel = t(.healthProfileEdit)
        checkHistoryTitleLabel.text = t(.healthProfileCheckHistory)
        checkHistoryTrendTitleLabel.text = historyMetricTitle(selectedHistoryMetric)
        HealthMetricType.allCases.enumerated().forEach { index, metric in
            checkHistoryMetricControl.setTitle(historyMetricShortTitle(metric), forSegmentAt: index)
        }
        checkHistoryRangeControl.setTitle(t(.healthCheckRange7d), forSegmentAt: 0)
        checkHistoryRangeControl.setTitle(t(.healthCheckRange30d), forSegmentAt: 1)
        ocrTitleLabel.text = t(.healthProfileOcrHistory)
        ocrViewAllButton.setTitle(t(.mainViewAll), for: .normal)
        ocrViewAllButton.accessibilityLabel = t(.mainViewAll)
        uploadReportButton.setTitle(nil, for: .normal)
        uploadReportButton.accessibilityLabel = t(.healthProfileUploadReport)
        ocrLoadingLabel.text = t(.healthProfileOcrUploading)
        refreshSyncStatus()

        nameKeyLabel.text = t(.healthProfileName)
        genderKeyLabel.text = t(.healthProfileGender)
        birthdayKeyLabel.text = t(.healthProfileBirthday)
        heightKeyLabel.text = t(.healthProfileHeight)
        weightKeyLabel.text = t(.healthProfileWeight)
        bloodTypeKeyLabel.text = t(.healthProfileBloodType)
        vitalTitleLabels[.heartRate]?.text = t(.healthRecordHeartRate)
        vitalTitleLabels[.spo2]?.text = t(.healthRecordSpO2)
        vitalTitleLabels[.respiratoryRate]?.text = t(.healthRecordRespRate)
        vitalTitleLabels[.stress]?.text = t(.healthRecordStressScore)
        vitalUnitLabels[.heartRate]?.text = t(.unitBpm)
        vitalUnitLabels[.spo2]?.text = t(.unitPercent)
        vitalUnitLabels[.respiratoryRate]?.text = t(.unitBreathPerMin)
        vitalUnitLabels[.stress]?.text = t(.unitOutOfHundred)
    }

    @objc func languageChanged() {
        updateTexts()
        refreshAll()
    }

    func refreshAll() {
        refreshProfileSwitcher()
        refreshBasicInfo()
        refreshVitals()
        refreshCheckHistory()
        refreshOcrHistory()
    }

    @objc func profileDidUpdate() { refreshBasicInfo() }
    @objc func recordsDidUpdate() { refreshVitals(); refreshCheckHistory() }
    @objc func ocrReportsDidUpdate() { refreshOcrHistory() }
    @objc func activeProfileDidChange() { refreshAll() }

    func refreshSyncStatus() {
        let summary = SyncEngine.shared.statusSummary()
        let canSyncNow = !isSyncActionInFlight && !summary.isSyncing && summary.uploadingCount == 0
        let buttonTitle = syncButtonTitle(for: summary)
        if isSyncActionInFlight || summary.isSyncing || summary.uploadingCount > 0 {
            if summary.uploadingCount > 0 {
                syncStatusLabel.text = String(format: t(.syncStatusCountFormat), t(.syncStatusSyncing), summary.uploadingCount)
            } else {
                syncStatusLabel.text = t(.syncStatusSyncing)
            }
        } else if summary.failedCount > 0 {
            let pendingAfterFailures = max(summary.unsyncedCount - summary.failedCount, 0)
            if pendingAfterFailures > 0 {
                syncStatusLabel.text = String(
                    format: t(.syncStatusFailedPendingFormat),
                    summary.failedCount,
                    pendingAfterFailures
                )
            } else {
                syncStatusLabel.text = String(format: t(.syncStatusCountFormat), t(.syncStatusFailed), summary.failedCount)
            }
        } else if let blockedReason = summary.blockedReason, summary.unsyncedCount > 0 {
            switch blockedReason {
            case .requiresLogin:
                let base = AuthManager.shared.isLoggedIn ? t(.syncStatusRequiresEmailLogin) : t(.syncStatusRequiresLogin)
                syncStatusLabel.text = String(format: t(.syncStatusCountFormat), base, summary.unsyncedCount)
            case .networkUnavailable:
                syncStatusLabel.text = String(format: t(.syncStatusCountFormat), t(.syncStatusWaitingForNetwork), summary.unsyncedCount)
            case .waitingForWiFi:
                syncStatusLabel.text = String(format: t(.syncStatusCountFormat), t(.syncStatusWaitingForWiFi), summary.unsyncedCount)
            }
        } else if summary.unsyncedCount > 0 {
            syncStatusLabel.text = String(format: t(.syncStatusCountFormat), t(.syncStatusPending), summary.unsyncedCount)
        } else if let lastSyncDate = summary.lastSyncDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            syncStatusLabel.text = String(format: t(.syncStatusLastSyncFormat), t(.syncStatusLastSyncPrefix), formatter.string(from: lastSyncDate))
        } else {
            syncStatusLabel.text = t(.syncStatusIdle)
        }

        syncNowButton.setTitle("  \(buttonTitle)", for: .normal)
        syncNowButton.accessibilityLabel = buttonTitle
        syncNowButton.isEnabled = canSyncNow
        syncNowButton.alpha = canSyncNow ? 1.0 : 0.6
        if summary.blockedReason != nil && summary.unsyncedCount > 0 {
            syncNowButton.backgroundColor = UIColor.secondarySystemBackground
            syncNowButton.tintColor = AppDesign.Color.primaryGreen
            syncNowButton.setTitleColor(AppDesign.Color.primaryGreen, for: .normal)
        } else {
            syncNowButton.backgroundColor = themeColor
            syncNowButton.tintColor = .white
            syncNowButton.setTitleColor(.white, for: .normal)
        }
        syncNowButton.accessibilityHint = syncStatusLabel.text
    }

    private func syncButtonTitle(for summary: SyncStatusSummary) -> String {
        if isSyncActionInFlight || summary.isSyncing || summary.uploadingCount > 0 {
            return t(.syncStatusSyncing)
        }
        if let blockedReason = summary.blockedReason, summary.unsyncedCount > 0 {
            switch blockedReason {
            case .requiresLogin:
                return AuthManager.shared.isLoggedIn ? t(.syncStatusRequiresEmailLogin) : t(.syncStatusRequiresLogin)
            case .networkUnavailable:
                return t(.syncStatusWaitingForNetwork)
            case .waitingForWiFi:
                return t(.syncStatusWaitingForWiFi)
            }
        }
        if summary.unsyncedCount > 0 {
            return t(.syncNow)
        }
        if Config.useRelay, AuthTokenManager.shared.isLoggedIn {
            return t(.syncRefreshCloud)
        }
        return t(.syncNow)
    }

    func refreshVitals() {
        let record = HealthRecordRepository.shared.fetchLatest(profileId: currentHealthProfileID())
        let fmt = { (v: Double?) -> String in self.localizedWholeNumberString(v) ?? "--" }
        hrValueLabel.text = fmt(record?.hr)
        spo2ValueLabel.text = fmt(record?.spo2)
        rrValueLabel.text = fmt(record?.rr)
        stressValueLabel.text = fmt(record?.stressScore)
    }

    func refreshBasicInfo() {
        let activeProfile = currentHealthProfile()
        let owner = try? ProfileManager.shared.ownerProfile()
        let profile = UserProfileRepository.shared.fetch()
        let none = t(.healthProfileNotFilled)
        let isOwnerContext = activeProfile?.relationship == .owner || activeProfile == nil
        let displayNameSource = activeProfile?.name ?? ""
        let displayName = (!displayNameSource.isEmpty ? displayNameSource : ((!profile.name.isEmpty && isOwnerContext) ? profile.name : (owner?.name ?? "")))
        nameValueLabel.text = displayName.isEmpty ? none : displayName

        let displayGender = activeProfile?.gender?.rawValue ?? ((!profile.gender.isEmpty && isOwnerContext) ? profile.gender : (owner?.gender?.rawValue ?? ""))
        genderValueLabel.text = genderDisplay(displayGender)

        let displayBirthday = activeProfile.flatMap { selected in
            selected.birthYear.flatMap { year in
                Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))
            }
        } ?? ((isOwnerContext ? profile.birthday : nil) ?? owner.flatMap { owner in
            owner.birthYear.flatMap { year in
                Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))
            }
        })
        birthdayValueLabel.text = displayBirthday.map { birthdayFormatter.string(from: $0) } ?? none
        let displayHeight = activeProfile?.heightCm ?? ((isOwnerContext ? profile.heightCm : nil) ?? owner?.heightCm)
        heightValueLabel.text = localizedWholeNumberString(displayHeight).map { "\($0) \(t(.unitCentimeters))" } ?? none
        let displayWeight = activeProfile?.weightKg ?? ((isOwnerContext ? profile.weightKg : nil) ?? owner?.weightKg)
        weightValueLabel.text = localizedWholeNumberString(displayWeight).map { "\($0) \(t(.unitKilograms))" } ?? none
        let activeBloodType = activeProfile?.bloodType ?? nil
        let displayBloodType = activeBloodType ?? ((isOwnerContext && !profile.bloodType.isEmpty) ? profile.bloodType : (owner?.bloodType ?? ""))
        bloodTypeValueLabel.text = displayBloodType.isEmpty ? none : displayBloodType
        let profileCount = (try? ProfileManager.shared.allProfiles().count) ?? 0
        let profileScope: String
        if Config.useRelay && AuthTokenManager.shared.isLoggedIn && AuthManager.shared.isLoggedIn {
            profileScope = t(.healthProfileHybridMode)
        } else if Config.useRelay && AuthTokenManager.shared.isLoggedIn {
            profileScope = t(.healthProfileCloudConnected)
        } else if AuthManager.shared.isLoggedIn {
            profileScope = t(.healthProfilePhoneLocalMode)
        } else {
            profileScope = t(.healthProfileLocalOnly)
        }
        familyProfilesStatusLabel.text = String(format: t(.healthProfileFamilyProfilesScopeFormat), t(.healthProfileFamilyProfiles), profileCount, profileScope)
    }

    func refreshProfileSwitcher() {
        profileSwitcherStack.arrangedSubviews.forEach {
            profileSwitcherStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let profiles = (try? ProfileManager.shared.allProfiles()) ?? []
        profileSwitcherScrollView.isHidden = profiles.count <= 1
        guard profiles.count > 1 else { return }

        let activeProfileID = currentHealthProfileID()
        profiles.forEach { profile in
            let button = UIButton(type: .system)
            let isActive = profile.id == activeProfileID
            button.setTitle(profile.name.isEmpty ? profile.relationship.displayName : profile.name, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            button.backgroundColor = isActive ? themeColor : UIColor.systemGray6
            button.setTitleColor(isActive ? .white : .label, for: .normal)
            button.layer.cornerRadius = 16
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
            button.accessibilityIdentifier = profile.id
            button.addTarget(self, action: #selector(profileSwitchTapped(_:)), for: .touchUpInside)
            profileSwitcherStack.addArrangedSubview(button)
        }
    }

    private func localizedWholeNumberString(_ value: Double?) -> String? {
        guard let value else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value))
    }

    private func genderDisplay(_ raw: String) -> String {
        switch raw {
        case "male": return t(.healthProfileGenderMale)
        case "female": return t(.healthProfileGenderFemale)
        case "other": return t(.healthProfileGenderOther)
        default: return t(.healthProfileNotFilled)
        }
    }

    private func makeOcrSourceStatusLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    func refreshCheckHistory() {
        checkHistoryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let records = HealthRecordRepository.shared.fetchAll(profileId: currentHealthProfileID())
        updateCheckHistoryTrend(records: records)

        let recentRecords = records.prefix(10)
        if recentRecords.isEmpty {
            checkHistoryStack.addArrangedSubview(makeEmptyLabel(t(.healthProfileEmptyChecks)))
        } else {
            recentRecords.forEach { checkHistoryStack.addArrangedSubview(makeCheckRow($0)) }
        }
    }

    func refreshOcrHistory() {
        let render: ([OcrReport]) -> Void = { reports in
            self.ocrHistoryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            if reports.isEmpty {
                self.ocrHistoryStack.addArrangedSubview(self.makeEmptyLabel(t(.healthProfileEmptyReports)))
            } else {
                reports.forEach { self.ocrHistoryStack.addArrangedSubview(self.makeOcrRow($0)) }
            }
        }

        render(OcrReportRepository.shared.fetchAll())
    }

    func currentHealthProfile() -> HealthProfile? {
        if let profile = try? ProfileManager.shared.activeProfile() {
            return profile
        }
        return nil
    }

    func currentHealthProfileID() -> String? {
        currentHealthProfile()?.id
    }

    func ocrDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func updateCheckHistoryTrend(records: [HealthRecord]) {
        let dataPoints = filteredTrendRecords(from: records).compactMap { metricValue(for: selectedHistoryMetric, in: $0) }
        checkHistoryTrendView.dataPoints = dataPoints
    }

    private func filteredTrendRecords(from records: [HealthRecord]) -> [HealthRecord] {
        let days = checkHistoryRangeControl.selectedSegmentIndex == 1 ? 30 : 7
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            return records.reversed()
        }

        return records
            .filter { $0.date >= startDate }
            .sorted { $0.date < $1.date }
    }
}
