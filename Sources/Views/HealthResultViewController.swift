import UIKit

/// 健康检测结果页，展示单次 rPPG 分析的详细指标
final class HealthResultViewController: UIViewController {

    // MARK: - 属性

    private let record: HealthRecord
    private let themeColor = AppDesign.Color.primaryGreen

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return df
    }()

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - 初始化

    /// - Parameter record: 本次检测结果
    init(record: HealthRecord) {
        self.record = record
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("不支持 Storyboard") }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground
        setupScrollView()
        buildContent()
        updateTexts()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func updateTexts() {
        title = t(.healthResultTitle)
    }

    @objc private func languageChanged() {
        updateTexts()
    }

    // MARK: - 布局

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
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

    private func buildContent() {
        // 顶部时间卡片
        let headerCard = makeHeaderCard()
        // 主要生命体征卡片
        let vitalsCard = makeSection(title: t(.healthResultVitalsSectionTitle), items: [
            MetricItem(icon: "heart.fill", color: .systemRed,
                       title: t(.healthResultHR), value: format(record.hr), unit: t(.unitBpm), status: record.hrStatus),
            MetricItem(icon: "waveform.path.ecg", color: themeColor,
                       title: t(.healthResultRR), value: format(record.rr), unit: t(.unitBreathPerMin), status: record.rrStatus),
            MetricItem(icon: "lungs.fill", color: .systemBlue,
                       title: t(.healthResultSpO2), value: format(record.spo2), unit: "%", status: record.spo2Status),
        ])
        // 压力与信号质量卡片
        let stressCard = makeSection(title: t(.healthResultStressSectionTitle), items: [
            MetricItem(icon: "bolt.heart.fill", color: .systemOrange,
                       title: t(.healthResultStress), value: format(record.stressScore), unit: t(.unitScore), status: record.stressLevel),
            MetricItem(icon: "chart.bar.fill", color: .systemPurple,
                       title: t(.healthResultSQI), value: format(record.sqi), unit: "", status: record.confidence),
        ])
        // 皮肤检测卡片（可选）
        let skinCard = makeSkinCard()

        let stack = UIStackView(arrangedSubviews: [headerCard, vitalsCard, stressCard, skinCard].compactMap { $0 })
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
        ])
    }

    // MARK: - 子视图构建

    private func makeHeaderCard() -> UIView {
        let card = makeCard()
        let iconIV = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))
        iconIV.tintColor = themeColor
        iconIV.contentMode = .scaleAspectFit
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = t(.healthResultCompleted)
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let dateLabel = UILabel()
        dateLabel.text = dateFormatter.string(from: record.date)
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .secondaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconIV)
        card.addSubview(titleLabel)
        card.addSubview(dateLabel)
        NSLayoutConstraint.activate([
            iconIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconIV.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconIV.widthAnchor.constraint(equalToConstant: 36),
            iconIV.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.leadingAnchor.constraint(equalTo: iconIV.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),

            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dateLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private struct MetricItem {
        let icon: String
        let color: UIColor
        let title: String
        let value: String
        let unit: String
        let status: String?
    }

    private func makeSection(title: String, items: [MetricItem]) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let sectionTitle = UILabel()
        sectionTitle.text = title
        sectionTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        sectionTitle.textColor = .secondaryLabel
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sectionTitle)

        let card = makeCard()
        container.addSubview(card)

        NSLayoutConstraint.activate([
            sectionTitle.topAnchor.constraint(equalTo: container.topAnchor),
            sectionTitle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),

            card.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let itemStack = UIStackView()
        itemStack.axis = .vertical
        itemStack.spacing = 0
        itemStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(itemStack)
        NSLayoutConstraint.activate([
            itemStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            itemStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            itemStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            itemStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
        ])

        for (i, item) in items.enumerated() {
            let row = makeMetricRow(item: item)
            itemStack.addArrangedSubview(row)
            if i < items.count - 1 {
                let sep = makeSeparator()
                itemStack.addArrangedSubview(sep)
            }
        }
        return container
    }

    private func makeMetricRow(item: MetricItem) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconIV = UIImageView(image: UIImage(systemName: item.icon, withConfiguration: config))
        iconIV.tintColor = item.color
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        let valueText = item.unit.isEmpty ? item.value : "\(item.value) \(item.unit)"
        valueLabel.text = valueText
        valueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        valueLabel.textAlignment = .natural
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(iconIV)
        row.addSubview(titleLabel)
        row.addSubview(valueLabel)

        var constraints: [NSLayoutConstraint] = [
            row.heightAnchor.constraint(equalToConstant: 52),

            iconIV.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconIV.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconIV.widthAnchor.constraint(equalToConstant: 22),
            iconIV.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: iconIV.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            valueLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
        ]

        // 状态标签（若有）
        if let status = item.status, !status.isEmpty {
            let badge = UILabel()
            badge.text = status
            badge.font = .systemFont(ofSize: 11, weight: .medium)
            badge.textColor = .white
            badge.backgroundColor = statusColor(for: status)
            badge.textAlignment = .center
            badge.layer.cornerRadius = 9
            badge.clipsToBounds = true
            badge.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(badge)
            constraints += [
                badge.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
                badge.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                badge.heightAnchor.constraint(equalToConstant: 18),
                badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            ]
            // 有 badge 时 valueLabel 在 badge 左侧
            constraints.removeAll { $0.firstAnchor === valueLabel.trailingAnchor }
            constraints.append(valueLabel.trailingAnchor.constraint(equalTo: badge.leadingAnchor, constant: -8))
        }

        NSLayoutConstraint.activate(constraints)
        return row
    }

    private func makeSkinCard() -> UIView? {
        guard let skinLabel = record.skinLabel else { return nil }
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let sectionTitle = UILabel()
        sectionTitle.text = t(.healthResultSkinSectionTitle)
        sectionTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        sectionTitle.textColor = .secondaryLabel
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sectionTitle)

        let card = makeCard()
        container.addSubview(card)

        let iconIV = UIImageView(image: UIImage(systemName: "face.smiling"))
        iconIV.tintColor = themeColor
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        // 优先使用本地化文本，回退到 skinLabel
        let lang = Locale.current.languageCode ?? "en"
        label.text = record.skinI18n?[lang] ?? record.skinI18n?["en"] ?? skinLabel
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconIV)
        card.addSubview(label)
        NSLayoutConstraint.activate([
            sectionTitle.topAnchor.constraint(equalTo: container.topAnchor),
            sectionTitle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),

            card.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            card.heightAnchor.constraint(equalToConstant: 60),

            iconIV.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconIV.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconIV.widthAnchor.constraint(equalToConstant: 24),
            iconIV.heightAnchor.constraint(equalToConstant: 24),

            label.leadingAnchor.constraint(equalTo: iconIV.trailingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
        return container
    }

    // MARK: - 辅助

    private func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 16
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.04
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.layer.shadowRadius = 8
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 50),
            sep.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            sep.topAnchor.constraint(equalTo: wrapper.topAnchor),
            sep.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
        ])
        return wrapper
    }

    /// 将可选 Double 格式化为字符串，nil 显示 "--"
    private func format(_ value: Double?) -> String {
        guard let v = value else { return "--" }
        return String(format: "%.0f", v)
    }

    /// 根据状态文本返回对应颜色
    private func statusColor(for status: String) -> UIColor {
        switch status.lowercased() {
        case "normal", "正常": return .systemGreen
        case "high", "偏高": return .systemOrange
        case "low", "偏低": return .systemBlue
        case "critical", "危险": return .systemRed
        default: return AppDesign.Color.primaryGreen
        }
    }
}
