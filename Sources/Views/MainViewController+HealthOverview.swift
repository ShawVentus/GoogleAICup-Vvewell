import UIKit

extension MainViewController {

    // MARK: - Health Overview

    @objc func activeProfileDidChange() {
        refreshHealthOverview()
    }

    func refreshHealthOverview() {
        let activeProfileID = (try? ProfileManager.shared.resolveActiveProfileID()) ?? nil
        let latest = HealthRecordRepository.shared.fetchLatest(profileId: activeProfileID)
        homeMetricDateFormatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        if let latest {
            let timeText = homeMetricDateFormatter.string(from: latest.date)
            lastCheckLabel?.text = String(format: t(.mainLastCheckedFormat), timeText)
        } else {
            lastCheckLabel?.text = t(.mainLastToday0830)
        }

        updateMetricCard(.heartRate, record: latest)
        updateMetricCard(.spo2, record: latest)
        updateMetricCard(.stress, record: latest)
        updateMetricCard(.bloodPressure, record: latest)
        refreshCoachSummary(record: latest)
    }

    private func updateMetricCard(_ type: HomeMetricType, record: HealthRecord?) {
        guard let card = homeMetricCards[type] else { return }
        card.titleLabel.text = metricTitle(type)
        card.unitLabel.text = metricUnit(type, record: record)
        card.valueLabel.text = metricValue(type, record: record)
        card.statusLabel.text = metricStatus(type, record: record)
        card.statusDot.backgroundColor = metricStatusColor(type, record: record)
    }

    private func metricTitle(_ type: HomeMetricType) -> String {
        switch type {
        case .heartRate: return t(.mainMetricHR)
        case .spo2: return t(.mainMetricSpO2)
        case .stress: return t(.mainMetricStress)
        case .bloodPressure: return t(.mainMetricBP)
        }
    }

    private func metricValue(_ type: HomeMetricType, record: HealthRecord?) -> String {
        switch type {
        case .heartRate:
            return record?.hr.map { String(format: "%.0f", $0) } ?? "--"
        case .spo2:
            return record?.spo2.map { String(format: "%.0f", $0) } ?? "--"
        case .stress:
            return record?.stressScore.map { String(format: "%.0f", $0) } ?? "--"
        case .bloodPressure:
            return "128/82"
        }
    }

    private func metricUnit(_ type: HomeMetricType, record: HealthRecord?) -> String {
        switch type {
        case .heartRate:
            return t(.unitBpm)
        case .spo2:
            return record?.spo2 == nil ? "" : "%"
        case .stress:
            return record?.stressScore == nil ? "" : "/100"
        case .bloodPressure:
            return ""
        }
    }

    private func metricStatus(_ type: HomeMetricType, record: HealthRecord?) -> String {
        switch type {
        case .heartRate:
            return localizedHomeStatus(record?.hrStatus) ?? t(.mainStatusNormal)
        case .spo2:
            return localizedHomeStatus(record?.spo2Status) ?? t(.mainStatusExcellent)
        case .stress:
            return localizedHomeStatus(record?.stressLevel) ?? t(.mainStatusElevated)
        case .bloodPressure:
            return t(.mainStatusBorderline)
        }
    }

    private func metricStatusColor(_ type: HomeMetricType, record: HealthRecord?) -> UIColor {
        switch type {
        case .bloodPressure:
            return .systemOrange
        case .stress:
            return statusColorFor(record?.stressLevel)
        case .heartRate:
            return statusColorFor(record?.hrStatus)
        case .spo2:
            return statusColorFor(record?.spo2Status)
        }
    }

    private func localizedHomeStatus(_ status: String?) -> String? {
        guard let status else { return nil }
        switch status.lowercased() {
        case "normal", "正常":
            return t(.mainStatusNormal)
        case "excellent", "优秀":
            return t(.mainStatusExcellent)
        case "elevated", "偏高", "high":
            return t(.mainStatusElevated)
        case "borderline", "临界":
            return t(.mainStatusBorderline)
        default:
            return status
        }
    }

    private func statusColorFor(_ status: String?) -> UIColor {
        switch status?.lowercased() {
        case "normal", "正常", "excellent", "优秀":
            return .systemGreen
        case "elevated", "偏高", "high":
            return .systemOrange
        case "low", "偏低":
            return .systemBlue
        default:
            return .systemOrange
        }
    }
}
