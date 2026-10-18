import UIKit

extension MainViewController {

    // MARK: - Localization / Notifications

    @objc func languageChanged() {
        updateTexts()
        updateGreeting()
        refreshHealthOverview()
    }

    @objc func recordsDidUpdate() {
        refreshHealthOverview()
    }

    func updateTexts() {
        healthOverviewLabel?.text = t(.mainHealthOverview)
        aiCheckerLabel?.text = t(.mainAIChecker)
        quickAccessLabel?.text = t(.mainQuickAccess)
        welcomeLabelRef?.text = t(.mainWelcomeBack)
        startCheckButton.setTitle("  \(t(.mainStartAIHealthCheck))", for: .normal)
        startCheckButton.accessibilityLabel = t(.mainStartAIHealthCheck)
        symptomTextField.placeholder = t(.mainSymptomPlaceholder)
        symptomTextField.accessibilityLabel = t(.mainSymptomPlaceholder)
        analyzeButton.setTitle(t(.mainAnalyzeSymptoms), for: .normal)
        analyzeButton.accessibilityLabel = t(.mainAnalyzeSymptoms)
        if let viewAllButton {
            configureTrailingChevronButton(
                viewAllButton,
                title: t(.mainViewAll),
                color: themeColor,
                font: .systemFont(ofSize: 14, weight: .medium)
            )
        }
        remindersTitleLabel?.text = t(.mainRemindersTitle)
        recommendedTitleLabel?.text = t(.mainRecommendedTitle)
        if let recommendedSeeAllButton {
            configureTrailingChevronButton(
                recommendedSeeAllButton,
                title: t(.mainSeeAll),
                color: themeColor,
                font: .systemFont(ofSize: 14, weight: .medium)
            )
        }
        updateQuickAccessTexts()
        updateReminderTexts()
        updateArticleTexts()
    }

    func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            greetingLabel.text = t(.mainGreetingMorning)
        case 12..<18:
            greetingLabel.text = t(.mainGreetingAfternoon)
        default:
            greetingLabel.text = t(.mainGreetingEvening)
        }
    }

    private func updateQuickAccessTexts() {
        let titles = [
            t(.mainQuickAccessAICheck),
            t(.mainQuickAccessConsult),
            t(.mainQuickAccessMedicalTourism),
            t(.mainQuickAccessRecords),
            t(.mainQuickAccessHealthContent),
            t(.mainQuickAccessDevices),
            t(.mainQuickAccessNutrition),
            t(.mainQuickAccessCharity),
        ]
        for (index, label) in quickAccessTitleLabels.enumerated() where index < titles.count {
            label.text = titles[index]
        }
    }

    private func updateReminderTexts() {
        let titles = [
            t(.mainReminderTakeMetformin),
            t(.mainReminderDrChenFollowup),
            t(.mainReminderWeeklyHealthCheck),
        ]
        let times = [t(.mainReminderTime0800AM), t(.mainReminderTime0200PM), t(.mainReminderAnytimeToday)]
        for (index, entry) in reminderEntries.enumerated() where index < titles.count {
            entry.title.text = titles[index]
            entry.time.text = times[index]
            if let badge = entry.actionView as? UILabel {
                badge.text = t(.mainReminderDone)
            } else if let button = entry.actionView as? UIButton {
                button.setTitle(t(.mainReminderMarkDone), for: .normal)
            }
        }
    }

    private func updateArticleTexts() {
        let tags = [t(.mainTagChronicCare), t(.mainTagMedicalTourism)]
        let titles = [t(.mainArticleDiabetesWeather), t(.mainArticleCrossBorderGuide)]
        let times = [t(.mainReadTime5Min), t(.mainReadTime8Min)]
        for (index, entry) in articleEntries.enumerated() where index < tags.count {
            entry.tag.text = tags[index]
            entry.title.text = titles[index]
            entry.time.text = times[index]
        }
    }
}
