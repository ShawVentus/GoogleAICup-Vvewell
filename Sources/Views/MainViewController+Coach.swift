import ImageIO
import UIKit

extension MainViewController {

    // MARK: - Android avatar coach parity
    // DIRTY HACK: the Android coach intentionally uses fixture scenarios. Keep
    // this switchable demo behavior visible until a production coach service
    // replaces it; it must never be mistaken for a clinical recommendation.

    private struct CoachScenario {
        let state: CoachAvatarState
        let label: String
        let message: String
        let task: String
        let score: Int
        let indices: [Int]
        let status: String
        let severity: UIColor
    }

    private enum CoachAvatarState: String, CaseIterable {
        case normal, happy, sleepy, stressed, inactive, recovery, warning, completedBoost = "completed_boost"

        var gifName: String { rawValue }
        var accessibilityName: String {
            switch self {
            case .normal: return "normal"
            case .happy: return "happy"
            case .sleepy: return "sleepy"
            case .stressed: return "stressed"
            case .inactive: return "inactive"
            case .recovery: return "recovery"
            case .warning: return "warning"
            case .completedBoost: return "completed boost"
            }
        }
    }

    var coachSectionView: UIView {
        get { coachSectionStorage }
        set { coachSectionStorage = newValue }
    }

    private var coachSectionStorage: UIView {
        get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.coachSection) as? UIView { return value }
            let value = UIView()
            objc_setAssociatedObject(self, &AssociatedKeys.coachSection, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return value
        }
        set { objc_setAssociatedObject(self, &AssociatedKeys.coachSection, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var coachPandaView: UIImageView? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.panda) as? UIImageView }
        set { objc_setAssociatedObject(self, &AssociatedKeys.panda, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var coachBubbleView: UIView? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.bubble) as? UIView }
        set { objc_setAssociatedObject(self, &AssociatedKeys.bubble, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var coachMessageLabel: UILabel? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.message) as? UILabel }
        set { objc_setAssociatedObject(self, &AssociatedKeys.message, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var coachSeverityLabel: UILabel? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.severity) as? UILabel }
        set { objc_setAssociatedObject(self, &AssociatedKeys.severity, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var coachTaskLabel: UILabel? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.task) as? UILabel }
        set { objc_setAssociatedObject(self, &AssociatedKeys.task, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var coachScoreRing: CoachHealthRingsView? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.rings) as? CoachHealthRingsView }
        set { objc_setAssociatedObject(self, &AssociatedKeys.rings, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var coachStatusLabel: UILabel? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.status) as? UILabel }
        set { objc_setAssociatedObject(self, &AssociatedKeys.status, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var coachCurrentScenario: Int {
        get { (objc_getAssociatedObject(self, &AssociatedKeys.scenario) as? NSNumber)?.intValue ?? 0 }
        set { objc_setAssociatedObject(self, &AssociatedKeys.scenario, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var coachScenarioManuallyChanged: Bool {
        get { (objc_getAssociatedObject(self, &AssociatedKeys.manual) as? NSNumber)?.boolValue ?? false }
        set { objc_setAssociatedObject(self, &AssociatedKeys.manual, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private enum AssociatedKeys {
        static var coachSection: UInt8 = 0
        static var panda: UInt8 = 0
        static var bubble: UInt8 = 0
        static var message: UInt8 = 0
        static var severity: UInt8 = 0
        static var task: UInt8 = 0
        static var rings: UInt8 = 0
        static var status: UInt8 = 0
        static var scenario: UInt8 = 0
        static var manual: UInt8 = 0
    }

    private var coachScenarios: [CoachScenario] {
        [
            CoachScenario(state: .normal, label: "日常建议", message: "今天状态平稳，可以做一点轻量活动或补充水分。", task: "轻量活动或补水", score: 82, indices: [82, 80, 78], status: "系统状态 · 正常", severity: .systemGreen),
            CoachScenario(state: .happy, label: "状态良好", message: "今天整体状态不错，保持现在舒适的节奏就好。", task: "保持当前节奏", score: 94, indices: [94, 92, 90], status: "系统状态 · 正常", severity: .systemGreen),
            CoachScenario(state: .sleepy, label: "需要关注", message: "你看小熊猫好像睡眠有点不足，休息个二十分钟吧。", task: "休息二十分钟", score: 68, indices: [68, 52, 72], status: "系统状态 · 需要关注", severity: .systemOrange),
            CoachScenario(state: .stressed, label: "需要关注", message: "现在可能有些紧绷，可以尝试三分钟呼吸放松。", task: "呼吸放松三分钟", score: 66, indices: [66, 70, 48], status: "系统状态 · 需要关注", severity: .systemOrange),
            CoachScenario(state: .inactive, label: "需要活动", message: "坐得有些久了，可以用五分钟做一组轻柔拉伸。", task: "拉伸活动五分钟", score: 70, indices: [70, 50, 70], status: "系统状态 · 需要活动", severity: .systemOrange),
            CoachScenario(state: .warning, label: "风险提示", message: "体温信号与平时不同，建议使用可靠设备进行人工测量。", task: "人工复测", score: 42, indices: [42, 48, 58], status: "系统状态 · 风险提示", severity: .systemRed),
            CoachScenario(state: .recovery, label: "数据恢复中", message: "正在恢复最近一次已确认的健康趋势，暂不推断缺失数据。", task: "等待数据同步", score: 76, indices: [76, 72, 80], status: "系统状态 · 恢复本地数据", severity: .systemBlue),
            CoachScenario(state: .completedBoost, label: "复测完成", message: "任务已完成，三个状态指标已按 DIRTY HACK Mock 场景更新。", task: "继续保持舒适节奏", score: 91, indices: [91, 88, 90], status: "系统状态 · 任务已记录", severity: AppDesign.Color.primaryGreen),
        ]
    }

    func setupCoachSection() {
        coachSectionView.backgroundColor = AppDesign.Surface.elevatedCard
        coachSectionView.layer.cornerRadius = 20
        coachSectionView.layer.borderWidth = 1
        coachSectionView.layer.borderColor = AppDesign.Surface.border.cgColor
        coachSectionView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(coachSectionView)

        let coachTitle = UILabel()
        coachTitle.text = "健康教练"
        coachTitle.font = .systemFont(ofSize: 18, weight: .bold)
        coachTitle.textColor = .label
        coachTitle.translatesAutoresizingMaskIntoConstraints = false
        let coachSubtitle = UILabel()
        coachSubtitle.text = "数字健康双生 · 点击熊猫切换状态"
        coachSubtitle.font = .systemFont(ofSize: 12, weight: .medium)
        coachSubtitle.textColor = .secondaryLabel
        coachSubtitle.translatesAutoresizingMaskIntoConstraints = false

        let panda = UIImageView()
        panda.contentMode = .scaleAspectFit
        panda.isUserInteractionEnabled = true
        panda.accessibilityLabel = "健康教练熊猫，点击查看 DIRTY HACK 演示状态"
        panda.translatesAutoresizingMaskIntoConstraints = false
        panda.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(coachPandaTapped)))
        coachPandaView = panda

        let bubble = UIView()
        bubble.backgroundColor = AppDesign.Surface.elevatedCard
        bubble.layer.cornerRadius = 8
        bubble.layer.borderWidth = 1
        bubble.layer.borderColor = AppDesign.Surface.border.cgColor
        bubble.layer.shadowColor = UIColor.black.cgColor
        bubble.layer.shadowOpacity = 0.08
        bubble.layer.shadowRadius = 8
        bubble.layer.shadowOffset = CGSize(width: 0, height: 3)
        bubble.translatesAutoresizingMaskIntoConstraints = false
        coachBubbleView = bubble

        let severity = UILabel()
        severity.font = .systemFont(ofSize: 13, weight: .bold)
        severity.translatesAutoresizingMaskIntoConstraints = false
        coachSeverityLabel = severity
        let message = UILabel()
        message.font = .systemFont(ofSize: 14, weight: .semibold)
        message.textColor = .label
        message.numberOfLines = 3
        message.translatesAutoresizingMaskIntoConstraints = false
        coachMessageLabel = message
        let task = UILabel()
        task.font = .systemFont(ofSize: 12, weight: .medium)
        task.textColor = .secondaryLabel
        task.translatesAutoresizingMaskIntoConstraints = false
        coachTaskLabel = task

        let complete = coachActionButton(title: "已完成", icon: "checkmark.circle.fill", action: #selector(coachCompleteTapped))
        let snooze = coachActionButton(title: "过一会", icon: "clock", action: #selector(coachSnoozeTapped))
        let decline = coachActionButton(title: "退下", icon: "xmark.circle", action: #selector(coachDeclineTapped))
        let actions = UIStackView(arrangedSubviews: [complete, snooze, decline])
        actions.axis = .horizontal
        actions.spacing = 4
        actions.distribution = .fillEqually
        actions.translatesAutoresizingMaskIntoConstraints = false

        bubble.addSubview(severity)
        bubble.addSubview(message)
        bubble.addSubview(task)
        bubble.addSubview(actions)

        let rings = CoachHealthRingsView()
        rings.translatesAutoresizingMaskIntoConstraints = false
        rings.accessibilityLabel = "健康、活力、心理三项健康指数"
        coachScoreRing = rings

        let statusDot = UIView()
        statusDot.backgroundColor = .systemGreen
        statusDot.layer.cornerRadius = 4
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        let status = UILabel()
        status.font = .systemFont(ofSize: 12, weight: .medium)
        status.textColor = .secondaryLabel
        status.translatesAutoresizingMaskIntoConstraints = false
        coachStatusLabel = status
        let statusRow = UIStackView(arrangedSubviews: [statusDot, status])
        statusRow.axis = .horizontal
        statusRow.spacing = 6
        statusRow.alignment = .center
        statusRow.translatesAutoresizingMaskIntoConstraints = false

        coachSectionView.addSubview(coachTitle)
        coachSectionView.addSubview(coachSubtitle)
        coachSectionView.addSubview(panda)
        coachSectionView.addSubview(bubble)
        coachSectionView.addSubview(rings)
        coachSectionView.addSubview(statusRow)

        NSLayoutConstraint.activate([
            coachSectionView.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 14),
            coachSectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            coachSectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            coachSectionView.heightAnchor.constraint(equalToConstant: 474),

            coachTitle.topAnchor.constraint(equalTo: coachSectionView.topAnchor, constant: 18),
            coachTitle.leadingAnchor.constraint(equalTo: coachSectionView.leadingAnchor, constant: 16),
            coachSubtitle.topAnchor.constraint(equalTo: coachTitle.bottomAnchor, constant: 3),
            coachSubtitle.leadingAnchor.constraint(equalTo: coachTitle.leadingAnchor),

            bubble.topAnchor.constraint(equalTo: coachSubtitle.bottomAnchor, constant: 12),
            bubble.leadingAnchor.constraint(equalTo: coachSectionView.leadingAnchor, constant: 16),
            bubble.trailingAnchor.constraint(equalTo: coachSectionView.trailingAnchor, constant: -16),
            bubble.heightAnchor.constraint(equalToConstant: 132),
            severity.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 12),
            severity.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
            message.topAnchor.constraint(equalTo: severity.bottomAnchor, constant: 7),
            message.leadingAnchor.constraint(equalTo: severity.leadingAnchor),
            message.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14),
            task.topAnchor.constraint(equalTo: message.bottomAnchor, constant: 6),
            task.leadingAnchor.constraint(equalTo: severity.leadingAnchor),
            actions.topAnchor.constraint(equalTo: task.bottomAnchor, constant: 7),
            actions.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 10),
            actions.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -10),
            actions.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -9),

            panda.leadingAnchor.constraint(equalTo: coachSectionView.leadingAnchor, constant: 14),
            panda.topAnchor.constraint(equalTo: bubble.bottomAnchor, constant: 5),
            panda.widthAnchor.constraint(equalTo: coachSectionView.widthAnchor, multiplier: 0.56),
            panda.heightAnchor.constraint(equalToConstant: 250),
            rings.trailingAnchor.constraint(equalTo: coachSectionView.trailingAnchor, constant: -22),
            rings.centerYAnchor.constraint(equalTo: panda.centerYAnchor),
            rings.widthAnchor.constraint(equalToConstant: 150),
            rings.heightAnchor.constraint(equalToConstant: 150),
            statusRow.leadingAnchor.constraint(equalTo: coachSectionView.leadingAnchor, constant: 18),
            statusRow.trailingAnchor.constraint(lessThanOrEqualTo: coachSectionView.trailingAnchor, constant: -18),
            statusRow.bottomAnchor.constraint(equalTo: coachSectionView.bottomAnchor, constant: -17),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),
        ])

        applyCoachScenario(coachScenarios[0])
    }

    private func coachActionButton(title: String, icon: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        button.tintColor = AppDesign.Color.primaryGreen
        button.setTitleColor(AppDesign.Color.primaryGreen, for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -3, bottom: 0, right: 3)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityTraits = .button
        return button
    }

    @objc private func coachPandaTapped() {
        coachScenarioManuallyChanged = true
        coachCurrentScenario = (coachCurrentScenario + 1) % coachScenarios.count
        applyCoachScenario(coachScenarios[coachCurrentScenario])
    }

    @objc func coachCompleteTapped() {
        let current = coachScenarios[coachCurrentScenario]
        coachPandaView?.image = animatedCoachImage(for: .completedBoost)
        coachMessageLabel?.text = "任务已完成。DIRTY HACK Mock 复测已记录。"
        coachSeverityLabel?.text = "任务完成"
        coachSeverityLabel?.textColor = AppDesign.Color.primaryGreen
        coachTaskLabel?.text = current.task
        coachScoreRing?.setValues(score: min(100, current.score + 6), indices: current.indices.map { min(100, $0 + 6) })
        coachStatusLabel?.text = "系统状态 · 任务已记录"
    }

    @objc private func coachSnoozeTapped() {
        coachMessageLabel?.text = "好的，我会稍后再提醒你。"
        coachSeverityLabel?.text = "已稍后提醒"
        coachSeverityLabel?.textColor = AppDesign.Color.primaryGreen
        coachStatusLabel?.text = "系统状态 · 已安排提醒"
    }

    @objc private func coachDeclineTapped() {
        coachMessageLabel?.text = "今天先跳过这个任务，仍然可以从设备中心查看健康数据。"
        coachSeverityLabel?.text = "已跳过"
        coachSeverityLabel?.textColor = .secondaryLabel
        coachStatusLabel?.text = "系统状态 · 等待下一次建议"
    }

    private func applyCoachScenario(_ scenario: CoachScenario) {
        coachPandaView?.image = animatedCoachImage(for: scenario.state)
        coachPandaView?.accessibilityValue = "当前 DIRTY HACK 演示状态：\(scenario.state.accessibilityName)"
        coachSeverityLabel?.text = scenario.label
        coachSeverityLabel?.textColor = scenario.severity
        coachMessageLabel?.text = scenario.message
        coachTaskLabel?.text = "建议任务 · \(scenario.task)"
        coachScoreRing?.setValues(score: scenario.score, indices: scenario.indices)
        coachStatusLabel?.text = scenario.status
        coachBubbleView?.accessibilityValue = "\(scenario.label)，\(scenario.message)"
    }

    func refreshCoachSummary(record: HealthRecord?) {
        guard coachPandaView != nil else { return }
        if !coachScenarioManuallyChanged, let record {
            if (record.spo2 ?? 97) < 94 {
                coachCurrentScenario = 6
            } else if (record.stressScore ?? 18) > 70 {
                coachCurrentScenario = 3
            } else {
                coachCurrentScenario = 0
            }
        }
        let scenario = coachScenarios[coachCurrentScenario]
        let oxygen = record?.spo2 ?? Double(scenario.score)
        let stress = record?.stressScore ?? Double(100 - scenario.indices[2])
        let score = max(0, min(100, Int((oxygen * 0.65) + ((100 - stress) * 0.35))))
        coachScoreRing?.setValues(score: score, indices: [score, scenario.indices[1], scenario.indices[2]])
        if !coachScenarioManuallyChanged { applyCoachScenario(scenario) }
    }

    private func animatedCoachImage(for state: CoachAvatarState) -> UIImage? {
        let name = state.gifName
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif", subdirectory: "AvatarCoach"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return UIImage(named: "PandaNormal")
        }
        var frames: [UIImage] = []
        var duration: TimeInterval = 0
        for index in 0..<CGImageSourceGetCount(source) {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue
                ?? 0.1
            duration += max(0.05, delay)
            frames.append(UIImage(cgImage: cgImage))
        }
        return frames.isEmpty ? UIImage(named: "PandaNormal") : UIImage.animatedImage(with: frames, duration: duration)
    }
}

private final class CoachHealthRingsView: UIView {
    private var score = 0
    private var indices = [0, 0, 0]

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 12
        updateBackgroundColor()
        accessibilityLabel = "健康指数与分项图例"
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.cornerRadius = 12
        updateBackgroundColor()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            updateBackgroundColor()
        }
    }

    private func updateBackgroundColor() {
        backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.72) : UIColor.white.withAlphaComponent(0.92)
        }
    }

    func setValues(score: Int, indices: [Int]) {
        self.score = score
        self.indices = indices
        setNeedsDisplay()
        accessibilityValue = "健康分数 \(score)，健康 \(indices.first ?? 0)，活力 \(indices.dropFirst().first ?? 0)，心理 \(indices.last ?? 0)"
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let center = CGPoint(x: 47, y: rect.midY - 4)
        let rings: [(CGFloat, UIColor, Int)] = [
            (74, AppDesign.Color.primaryGreen, indices.first ?? 0),
            (56, AppDesign.Color.bloodOxygen, indices.dropFirst().first ?? 0),
            (38, AppDesign.Color.sleep, indices.last ?? 0),
        ]
        for (radius, color, value) in rings {
            context.setStrokeColor(color.withAlphaComponent(0.16).cgColor)
            context.setLineWidth(6)
            context.addArc(center: center, radius: radius / 2, startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: false)
            context.strokePath()
            context.setStrokeColor(color.cgColor)
            context.addArc(center: center, radius: radius / 2, startAngle: -.pi / 2, endAngle: -.pi / 2 + 2 * .pi * CGFloat(value) / 100, clockwise: false)
            context.strokePath()
        }
        let scoreText = "\(score)"
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 20, weight: .bold), .foregroundColor: UIColor.label]
        let size = scoreText.size(withAttributes: attributes)
        scoreText.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attributes)

        let legend: [(String, UIColor)] = [("健康", AppDesign.Color.primaryGreen), ("活力", AppDesign.Color.bloodOxygen), ("心理", AppDesign.Color.sleep)]
        let legendFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
        for (index, item) in legend.enumerated() {
            let y = 42 + CGFloat(index * 26)
            context.setFillColor(item.1.cgColor)
            context.fillEllipse(in: CGRect(x: 91, y: y + 3, width: 7, height: 7))
            zhEn(item.0).draw(at: CGPoint(x: 103, y: y), withAttributes: [.font: legendFont, .foregroundColor: UIColor.label])
        }
    }
}
