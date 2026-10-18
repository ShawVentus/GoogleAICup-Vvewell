import UIKit

private final class ParityClosureButton: UIButton {
    private let handler: () -> Void
    init(title: String, icon: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        setTitle("  \(title)", for: .normal)
        setImage(UIImage(systemName: icon), for: .normal)
        addTarget(self, action: #selector(fire), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func fire() { handler() }
}

private final class ParityClosureSegment: UISegmentedControl {
    private let handler: (UISegmentedControl) -> Void
    init(items: [Any], handler: @escaping (UISegmentedControl) -> Void) {
        self.handler = handler
        super.init(items: items)
        addTarget(self, action: #selector(fire), for: .valueChanged)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func fire() { handler(self) }
}

private final class ParityClosureSwitch: UISwitch {
    private let handler: (Bool) -> Void
    init(handler: @escaping (Bool) -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        addTarget(self, action: #selector(fire), for: .valueChanged)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func fire() { handler(isOn) }
}

// MARK: - Android profile parity pages

/// Shared native page primitives for the Android profile/nutrition routes.
/// Fixture records are intentionally kept local and labeled below.
private enum AndroidParityCopy {
    static var isEnglish: Bool { LocaleManager.shared.current == .en }
    static func text(_ zh: String, _ en: String) -> String { isEnglish ? en : zh }
}

class ParityPage: UIViewController {
    let scroll = UIScrollView()
    let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppDesign.Surface.canvasBackground
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -28),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32),
        ])
    }

    func titleLabel(_ text: String, size: CGFloat = 18, color: UIColor = .label) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: size >= 18 ? .bold : .semibold)
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    func bodyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    func surface(_ body: UIView, tint: UIColor = AppDesign.Surface.elevatedCard) -> UIView {
        let view = UIView()
        view.backgroundColor = tint
        view.layer.cornerRadius = 10
        view.layer.borderWidth = 1
        view.layer.borderColor = AppDesign.Surface.border.cgColor
        body.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(body)
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            body.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            body.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            body.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
        ])
        return view
    }

    func action(_ title: String, icon: String = "chevron.right", handler: @escaping () -> Void) -> UIButton {
        let button = ParityClosureButton(title: title, icon: icon, handler: handler)
        button.tintColor = AppDesign.Color.primaryGreen
        button.setTitleColor(AppDesign.Color.primaryGreen, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.contentHorizontalAlignment = .left
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.layer.cornerRadius = 9
        button.backgroundColor = AppDesign.Surface.secondaryCard
        return button
    }

    func header(title: String, subtitle: String) -> UIView {
        let body = UIStackView(arrangedSubviews: [titleLabel(title, size: 27), bodyLabel(subtitle)])
        body.axis = .vertical
        body.spacing = 5
        return body
    }
}

final class AndroidOrdersViewController: ParityPage {
    private var filter = 0
    private let statuses = ["全部", "待付款", "进行中", "已完成"]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = AndroidParityCopy.text("我的订单", "My Orders")
        rebuild()
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(header(title: AndroidParityCopy.text("我的订单", "My Orders"), subtitle: AndroidParityCopy.text("硬件、医疗服务与营养评估的状态统一在这里查看。", "Track hardware, care services, and nutrition assessments in one place.")))
        let segmented = ParityClosureSegment(items: statuses.map { AndroidParityCopy.text($0, ["All", "Awaiting payment", "In progress", "Completed"][statuses.firstIndex(of: $0)!]) }) { [weak self] segment in
            self?.filter = segment.selectedSegmentIndex
            self?.rebuild()
        }
        segmented.selectedSegmentIndex = filter
        stack.addArrangedSubview(segmented)
        // DIRTY HACK: Android parity demo order fixtures; no real payment is initiated.
        let orders = [
            ("VV202608040018", "Alloop Ring 健康套装", "月光银 · 尺寸 9", "¥1,299", "待付款", "circle.circle"),
            ("VV202608020076", "跨境医疗专家会诊", "心血管内科 · 资料复核中", "¥3,500", "进行中", "cross.case.fill"),
            ("VV202607280143", "家庭营养深度评估", "Athena 沐瑶 · 已生成报告", "¥299", "已完成", "fork.knife"),
            ("VV202607190052", "红外健康检测仪", "标准版 · 已签收", "¥399", "已完成", "camera.thermometer"),
        ].filter { filter == 0 || $0.4 == statuses[filter] }
        orders.forEach { order in
            let body = UIStackView()
            body.axis = .vertical
            body.spacing = 8
            let top = UIStackView(arrangedSubviews: [titleLabel(order.0, size: 11, color: .secondaryLabel), UIView()])
            top.axis = .horizontal
            top.addArrangedSubview(titleLabel(order.4, size: 12, color: order.4 == "待付款" ? .systemOrange : .systemGreen))
            body.addArrangedSubview(top)
            let item = UIStackView()
            item.axis = .horizontal
            item.spacing = 12
            let icon = UIImageView(image: UIImage(systemName: order.5))
            icon.tintColor = AppDesign.Color.primaryGreen
            icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 48).isActive = true
            let detail = UIStackView(arrangedSubviews: [titleLabel(order.1, size: 15), bodyLabel(order.2)])
            detail.axis = .vertical
            detail.spacing = 3
            item.addArrangedSubview(icon)
            item.addArrangedSubview(detail)
            item.addArrangedSubview(titleLabel(order.3, size: 14, color: .label))
            body.addArrangedSubview(item)
            let actions = UIStackView(arrangedSubviews: [
                action(AndroidParityCopy.text("查看详情", "Details")) { [weak self] in self?.showNotice(AndroidParityCopy.text("订单详情已加载", "Order details loaded")) },
                action(order.4 == "待付款" ? AndroidParityCopy.text("去付款", "Pay") : AndroidParityCopy.text("查看进度", "Track")) { [weak self] in self?.showNotice(AndroidParityCopy.text("演示订单不会发起真实支付。", "Demo orders never initiate real payment.")) },
            ])
            actions.axis = .horizontal
            actions.distribution = .fillEqually
            actions.spacing = 8
            body.addArrangedSubview(actions)
            stack.addArrangedSubview(surface(body))
        }
    }

    private func showNotice(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AndroidParityCopy.text("知道了", "OK"), style: .default))
        present(alert, animated: true)
    }
}

final class AndroidBenefitsViewController: ParityPage {
    private var completed: Set<Int> = [0, 1]
    private let tasks = [("每日签到", 10), ("佩戴戒指", 20), ("完成健康评估", 30), ("阅读文章", 5)]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = AndroidParityCopy.text("我的权益", "Benefits")
        rebuild()
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let heroBody = UIStackView()
        heroBody.axis = .vertical
        heroBody.spacing = 10
        heroBody.addArrangedSubview(titleLabel(AndroidParityCopy.text("高级会员 · Lv.5", "Premium · Lv.5"), size: 20, color: .white))
        heroBody.addArrangedSubview(titleLabel("2,380  \(AndroidParityCopy.text("会员积分", "points"))", size: 32, color: .white))
        heroBody.addArrangedSubview(bodyLabel(AndroidParityCopy.text("距离下一等级 620 积分 · 已连续签到 7 天", "620 points to next level · 7-day streak")))
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progress = 0.72
        heroBody.addArrangedSubview(progress)
        stack.addArrangedSubview(surface(heroBody, tint: AppDesign.Color.darkTeal))

        let benefits = UIStackView()
        benefits.axis = .vertical
        benefits.spacing = 8
        benefits.addArrangedSubview(titleLabel(AndroidParityCopy.text("我的权益 · 5 / 6 已解锁", "Benefits · 5 / 6 unlocked"), size: 17))
        [("AI 健康咨询", "24 小时 AI 健康顾问"), ("营养顾问", "个性化营养建议"), ("深度报告", "每月健康深度分析"), ("优先预约", "专家问诊优先通道"), ("生日礼遇", "专属生日福利"), ("家庭共享+", "升级后支持家人共享")].forEach { item in
            benefits.addArrangedSubview(bodyLabel("✓  \(item.0)  ·  \(item.1)"))
        }
        stack.addArrangedSubview(surface(benefits))

        let daily = UIStackView()
        daily.axis = .vertical
        daily.spacing = 4
        daily.addArrangedSubview(titleLabel(AndroidParityCopy.text("每日任务 · \(completed.count)/\(tasks.count)", "Daily tasks · \(completed.count)/\(tasks.count)"), size: 17))
        tasks.enumerated().forEach { index, task in
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            let check = ParityClosureSwitch { [weak self] isOn in
                guard let self else { return }
                if isOn { completed.insert(index) } else { completed.remove(index) }
                rebuild()
            }
            check.isOn = completed.contains(index)
            row.addArrangedSubview(check)
            row.addArrangedSubview(bodyLabel("\(task.0)  +\(task.1)"))
            daily.addArrangedSubview(row)
        }
        stack.addArrangedSubview(surface(daily))
        let history = UIStackView(arrangedSubviews: [titleLabel(AndroidParityCopy.text("积分记录", "Point history"), size: 17), bodyLabel("每日签到  2026-08-04  +10"), bodyLabel("佩戴戒指  2026-08-03  +20"), bodyLabel("营养评估  2026-08-02  +30"), bodyLabel("兑换礼品  2026-07-30  -200")])
        history.axis = .vertical
        history.spacing = 8
        stack.addArrangedSubview(surface(history))
    }
}

final class AndroidNotificationSettingsViewController: ParityPage {
    private let keys = ["all", "health", "device", "family", "orders", "community", "quiet"]
    private var values: [String: Bool] = ["all": true, "health": true, "device": true, "family": true, "orders": true, "community": false, "quiet": true]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = AndroidParityCopy.text("通知设置", "Notifications")
        keys.forEach { values[$0] = UserDefaults.standard.object(forKey: "vvewell.notify.\($0)") as? Bool ?? values[$0] ?? false }
        rebuild()
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(header(title: AndroidParityCopy.text("通知设置", "Notifications"), subtitle: AndroidParityCopy.text("健康、设备、家庭、订单和社区通知分开管理。", "Manage health, device, family, order, and community notifications separately.")))
        let group = UIStackView()
        group.axis = .vertical
        group.spacing = 2
        let labels = [("all", "通知总开关", "控制所有推送、提醒与服务进度通知"), ("health", "健康提醒", "异常趋势、用药和复查提醒"), ("device", "设备与测量", "电量、佩戴、同步和检测结果"), ("family", "家庭成员动态", "共享成员的授权健康动态"), ("orders", "订单与服务", "物流、预约与保险服务进度"), ("community", "社区互动", "回复、关注和社区活动"), ("quiet", "免打扰时间", "22:00 - 07:00")]
        labels.forEach { key, title, subtitle in
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 10
            let text = UIStackView(arrangedSubviews: [titleLabel(AndroidParityCopy.text(title, title), size: 14), bodyLabel(AndroidParityCopy.text(subtitle, subtitle))])
            text.axis = .vertical
            text.spacing = 2
            let toggle = ParityClosureSwitch { [weak self] isOn in
                guard let self else { return }
                values[key] = isOn
                UserDefaults.standard.set(isOn, forKey: "vvewell.notify.\(key)")
                rebuild()
            }
            toggle.isOn = values[key] ?? false
            toggle.isEnabled = key == "all" || values["all"] == true
            row.addArrangedSubview(text)
            row.addArrangedSubview(toggle)
            group.addArrangedSubview(row)
        }
        stack.addArrangedSubview(surface(group))
    }
}

final class AndroidLanguageSettingsViewController: ParityPage {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = AndroidParityCopy.text("应用语言", "Language")
        let body = UIStackView()
        body.axis = .vertical
        body.spacing = 12
        body.addArrangedSubview(titleLabel(AndroidParityCopy.text("应用语言", "App language"), size: 17))
        let segment = ParityClosureSegment(items: ["简体中文", "English"]) { segment in
            LocaleManager.shared.setLanguage(segment.selectedSegmentIndex == 1 ? .en : .zh)
        }
        segment.selectedSegmentIndex = LocaleManager.shared.current == .en ? 1 : 0
        body.addArrangedSubview(segment)
        body.addArrangedSubview(bodyLabel(AndroidParityCopy.text("完整语言列表仍可从个人资料页使用。", "The full language list remains available from Profile.")))
        stack.addArrangedSubview(surface(body))
    }
}

final class AndroidNutritionCenterViewController: ParityPage {
    private var nutritionTab = 0
    private var checked = Set<String>()
    private var mealCount = 0
    private var cartCount = 0
    private let tabs = ["评估", "AI 顾问", "补剂打卡", "补剂商城"]
    private let supplements = [("magnesium", "镁 · 睡眠支持"), ("theanine", "茶氨酸 · 睡眠规律"), ("d3", "维生素 D3 · 骨骼与免疫"), ("omega3", "鱼油 · Omega-3")]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = AndroidParityCopy.text("营养中心", "Nutrition center")
        rebuild()
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(header(title: AndroidParityCopy.text("营养中心", "Nutrition center"), subtitle: AndroidParityCopy.text("个性化营养评估与补剂追踪", "Personalized nutrition assessment and supplement tracking")))
        let segmented = ParityClosureSegment(items: tabs.map { AndroidParityCopy.text($0, ["Assessment", "AI adviser", "Check-in", "Shop"][tabs.firstIndex(of: $0)!]) }) { [weak self] segment in
            self?.nutritionTab = segment.selectedSegmentIndex
            self?.rebuild()
        }
        segmented.selectedSegmentIndex = nutritionTab
        stack.addArrangedSubview(segmented)
        switch nutritionTab {
        case 0: buildAssessment()
        case 1: buildAI()
        case 2: buildTracking()
        default: buildShop()
        }
    }

    private func buildAssessment() {
        let body = UIStackView()
        body.axis = .vertical
        body.alignment = .center
        body.spacing = 10
        body.addArrangedSubview(titleLabel("72", size: 38, color: AppDesign.Color.primaryGreen))
        body.addArrangedSubview(titleLabel(AndroidParityCopy.text("营养完成度", "Nutrition progress"), size: 16))
        body.addArrangedSubview(bodyLabel(AndroidParityCopy.text("今日已记录 \(mealCount) 餐 · 尚未记录内容不会被推断", "\(mealCount) meals logged today · unrecorded foods are not inferred")))
        let capture = action(AndroidParityCopy.text("记录一餐", "Log a meal"), icon: "camera") { [weak self] in self?.mealCount += 1; self?.rebuild() }
        body.addArrangedSubview(capture)
        stack.addArrangedSubview(surface(body, tint: AppDesign.Surface.highlightCard))
        let suggestion = UIStackView(arrangedSubviews: [titleLabel(AndroidParityCopy.text("针对睡眠风险的补剂候选", "Candidates for sleep risk"), size: 17), bodyLabel(AndroidParityCopy.text("须结合用药及禁忌复核；补剂候选不用于诊断或治疗。", "Review medication and contraindications; candidates are not diagnosis or treatment."))])
        suggestion.axis = .vertical
        suggestion.spacing = 5
        stack.addArrangedSubview(surface(suggestion))
    }

    private func buildAI() {
        let body = UIStackView()
        body.axis = .vertical
        body.spacing = 10
        body.addArrangedSubview(titleLabel(AndroidParityCopy.text("AI 营养顾问", "AI nutrition adviser"), size: 18))
        body.addArrangedSubview(bodyLabel(AndroidParityCopy.text("结合已确认的餐食、过敏与用药信息回答；涉及相互作用时请让医生或药师复核。", "Answers use confirmed meals, allergies, and medication; ask a clinician or pharmacist about interactions.")))
        ["根据今天已记录的餐食，我还缺哪些营养？", "鱼油、镁和维生素 D 应该怎样安排时间？", "有哪些食物可以替代当前候选补剂？"].forEach { question in
            body.addArrangedSubview(action(AndroidParityCopy.text(question, question), icon: "text.bubble") { [weak self] in self?.showNutritionNotice(AndroidParityCopy.text("已加入顾问对话。", "Added to adviser conversation.")) })
        }
        stack.addArrangedSubview(surface(body))
    }

    private func buildTracking() {
        let body = UIStackView()
        body.axis = .vertical
        body.spacing = 8
        body.addArrangedSubview(titleLabel(AndroidParityCopy.text("今日补剂概览", "Today’s supplements"), size: 18))
        body.addArrangedSubview(UIProgressView(progressViewStyle: .default))
        supplements.forEach { id, name in
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            let check = ParityClosureSwitch { [weak self] isOn in
                guard let self else { return }
                if isOn { checked.insert(id) } else { checked.remove(id) }
                rebuild()
            }
            check.isOn = checked.contains(id)
            row.addArrangedSubview(check)
            row.addArrangedSubview(bodyLabel(name))
            body.addArrangedSubview(row)
        }
        body.addArrangedSubview(action(AndroidParityCopy.text("全部打卡", "Check all"), icon: "checkmark.circle") { [weak self] in self?.checked = Set(self?.supplements.map(\.0) ?? []); self?.rebuild() })
        stack.addArrangedSubview(surface(body))
    }

    private func buildShop() {
        let body = UIStackView()
        body.axis = .vertical
        body.spacing = 8
        body.addArrangedSubview(titleLabel(AndroidParityCopy.text("补剂商城", "Supplement shop"), size: 18))
        body.addArrangedSubview(bodyLabel(AndroidParityCopy.text("Mock 商品不产生真实订单；购买前核对成分、剂量、用药和禁忌。", "Mock products never create real orders; review ingredients, dosage, medication, and contraindications.")))
        supplements.forEach { id, name in
            let row = UIStackView(arrangedSubviews: [bodyLabel(name), UIView()])
            row.axis = .horizontal
            let add = action(AndroidParityCopy.text("加入候选", "Add"), icon: "cart.badge.plus") { [weak self] in self?.cartCount += 1; self?.showNutritionNotice(AndroidParityCopy.text("已加入候选购物车 · \(self?.cartCount ?? 0)", "Added to candidate cart · \(self?.cartCount ?? 0)")) }
            row.addArrangedSubview(add)
            body.addArrangedSubview(row)
        }
        stack.addArrangedSubview(surface(body, tint: AppDesign.Surface.highlightCard))
    }

    private func showNutritionNotice(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AndroidParityCopy.text("知道了", "OK"), style: .default))
        present(alert, animated: true)
    }
}
