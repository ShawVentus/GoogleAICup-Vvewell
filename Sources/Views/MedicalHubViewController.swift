import UIKit

/// Native counterpart of Android's MedicalHubPage (medical_hub_page.dart).
/// Mirrors the Android hub: member context, hub tabs, referral journey,
/// insurance planning and patient community with local demo state.
final class MedicalHubViewController: UIViewController {

    // MARK: - State (local demo state, mirrors Android _MedicalHubPageState)

    let scrollView = UIScrollView()
    let stack = UIStackView()
    var selectedSection = 0
    var selectedService = 0
    var referral: ReferralIntakeResult?
    var quoteConfirmed = false
    var insuranceNeeds: InsuranceNeedsResult?
    var claimDraft: ClaimDraftResult?
    var communityQuery = ""
    var communityTopic = "推荐"
    var joinedCommunities: Set<String> = ["diabetes", "mental-wellness"]
    var bookmarkedPosts: Set<String> = []
    var newPosts: [CommunityPostDraft] = []
    var eventRegistered = false
    var providerLocation = "北京"
    var providerDepartment = "心内科"
    weak var communitySearchField: UITextField?

    // MARK: - Fixtures
    // DIRTY HACK: Android parity demo data (mirrors _services/_plans/_communities fixtures).

    struct MedicalService {
        let title, subtitle, price, icon: String
        let includes: [String]
        let excludes: String
    }

    struct InsurancePlan {
        let name, provider: String
        let match: Int
        let price, coverage, p50, p90, p95, deductible, waiting, fit, limit: String
    }

    struct Community {
        let id, name, description, members, posts, topic: String
    }

    static let services: [MedicalService] = [
        MedicalService(title: "专家问诊", subtitle: "专科医师及全球医学专家意见，适用于复杂病症", price: "¥500 - ¥5,000", icon: "stethoscope", includes: ["全球专家匹配", "视频问诊协调", "多语言支持", "第二诊疗意见整理"], excludes: "医生或医院另收的挂号诊金、检查费和药品费"),
        MedicalService(title: "专项检查", subtitle: "精密诊断检测与专科医学检查的预约协调", price: "¥2,000 - ¥8,000", icon: "doc.viewfinder", includes: ["MRI / CT 协调", "基因检测协调", "专科化验协调", "结果归档"], excludes: "医院检查费、造影剂、麻醉、耗材和复诊诊金另付医院"),
        MedicalService(title: "全球转诊", subtitle: "跨境医疗转诊全流程协调与支持", price: "¥2,000 - ¥10,000", icon: "globe", includes: ["国际医院准入", "医疗签证材料", "行程协调", "专属个案经理"], excludes: "医院诊疗、签证规费、机票、酒店和交通不包含"),
    ]

    static let plans: [InsurancePlan] = [
        InsurancePlan(name: "Premium Health Shield", provider: "平安健康险", match: 95, price: "¥4,200 / 年", coverage: "¥1,000,000", p50: "¥4,800", p90: "¥12,000", p95: "¥18,000", deductible: "¥10,000", waiting: "90 天", fit: "住院医疗缺口覆盖较高，常用医院网络匹配", limit: "既往症和等待期以正式条款与核保结果为准"),
        InsurancePlan(name: "Family Care Plus", provider: "太平洋健康险", match: 87, price: "¥2,800 / 年", coverage: "¥500,000", p50: "¥3,200", p90: "¥8,000", p95: "¥14,000", deductible: "¥5,000", waiting: "30 天", fit: "门诊与意外保障均衡，年度预算压力较低", limit: "部分专科医院为网络外，预计自付区间更宽"),
        InsurancePlan(name: "Critical Illness Guard", provider: "中国人寿", match: 82, price: "¥1,800 / 年", coverage: "¥300,000", p50: "¥1,800", p90: "¥5,000", p95: "¥8,000", deductible: "无", waiting: "180 天", fit: "补充重大疾病一次性给付，降低家庭收入责任缺口", limit: "不替代医疗险；健康告知需由持牌机构正式审核"),
    ]

    static let communities: [Community] = [
        Community(id: "breast-cancer", name: "乳腺癌康友社区", description: "围绕治疗经验、康复随访、用药副作用和心理支持的私密交流空间", members: "2,340", posts: "892", topic: "肿瘤康复"),
        Community(id: "diabetes", name: "糖尿病管理", description: "分享饮食、运动、用药依从和日常管理经验", members: "5,120", posts: "3,201", topic: "慢病管理"),
        Community(id: "heart-health", name: "心脏健康", description: "心血管疾病预防、复诊和康复支持", members: "1,890", posts: "654", topic: "心血管"),
        Community(id: "mental-wellness", name: "心理与生活", description: "情绪支持、家庭沟通、工作与生活适应", members: "8,760", posts: "12,450", topic: "心理支持"),
        Community(id: "rare-disease", name: "罕见病互助网络", description: "与相似经历的人交流就医信息、资源和照护经验", members: "890", posts: "234", topic: "罕见病"),
    ]

    static let communityTopics = ["推荐", "最新", "治疗经验", "康复随访", "用药副作用", "心理生活", "问答", "活动"]

    var memberName: String {
        ((try? ProfileManager.shared.activeProfile()) ?? nil)?.name ?? (LocaleManager.shared.current == .zh ? "家庭成员" : "Test User")
    }

    var memberRelationship: String {
        ((try? ProfileManager.shared.activeProfile()) ?? nil)?.relationship.displayName ?? ""
    }

    // DIRTY HACK: Android parity demo data (mirrors _providerRecommendations fixture logic).
    var providerRecommendations: [(name: String, location: String, reason: String, evidence: String, score: Int)] {
        let hospitals: [String]
        let waits: [String]
        switch providerLocation {
        case "上海": hospitals = ["上海交通大学医学院附属瑞金医院", "复旦大学附属中山医院"]; waits = ["预计 5 天可约", "预计 8 天可约"]
        case "新加坡": hospitals = ["Singapore General Hospital", "Mount Elizabeth Hospital"]; waits = ["预计 9 天可约", "预计 7 天可约"]
        case "美国": hospitals = ["Mayo Clinic", "Cleveland Clinic"]; waits = ["预计 12 天可约", "预计 15 天可约"]
        default: hospitals = ["北京协和医院", "中国医学科学院阜外医院"]; waits = ["预计 6 天可约", "预计 4 天可约"]
        }
        let reasons: [String]
        switch providerDepartment {
        case "呼吸与睡眠": reasons = ["睡眠呼吸亚专科匹配；可承接睡眠监测与多学科评估", "呼吸睡眠联合门诊；便于从风险筛查进入专业诊断"]
        case "内分泌科": reasons = ["代谢与营养风险联合评估；可结合检验与连续监测", "糖脂代谢专科能力匹配；支持长期随访计划"]
        case "肿瘤科": reasons = ["复杂病例多学科讨论；支持病理与影像复核", "诊疗连续性较高；支持第二诊疗意见整理"]
        default: reasons = ["与年度心血管复查标签高度匹配；支持复杂心血管评估", "心血管专科能力突出；可承接进一步分层检查与长期随访"]
        }
        return (0..<2).map { index in
            (
                name: "\(hospitals[index]) · \(providerDepartment)",
                location: "\(providerLocation) · \(waits[index])",
                reason: reasons[index],
                evidence: index == 0 ? "档案标签匹配 96% · 报告闭环率 94% · 网络状态待核验" : "档案标签匹配 88% · 号源更新于 15 分钟前 · 预计自付待评估",
                score: index == 0 ? 96 : 88
            )
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = AppDesign.Surface.canvasBackground
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .onDrag
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        rebuild()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func languageChanged() { rebuild() }

    func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(makeMemberContextCard())
        stack.addArrangedSubview(makeHubTabs())
        switch selectedSection {
        case 1: buildInsurance()
        case 2: buildCommunity()
        default: buildReferral()
        }
    }

    // MARK: - Member context + hub tabs

    private func makeMemberContextCard() -> UIView {
        let card = MedicalHubCard(backgroundColor: AppDesign.Surface.highlightCard)
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        let avatar = UIView()
        avatar.backgroundColor = .white
        avatar.layer.cornerRadius = 20
        let avatarIcon = UIImageView(image: UIImage(systemName: "person"))
        avatarIcon.tintColor = AppDesign.Color.primaryGreen
        avatarIcon.translatesAutoresizingMaskIntoConstraints = false
        avatar.addSubview(avatarIcon)
        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: 40),
            avatar.heightAnchor.constraint(equalToConstant: 40),
            avatarIcon.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
            avatarIcon.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),
        ])
        let labels = UIStackView()
        labels.axis = .vertical
        labels.spacing = 2
        let caption = UILabel()
        caption.text = "当前服务档案"
        caption.font = .systemFont(ofSize: 11)
        caption.textColor = .secondaryLabel
        let name = UILabel()
        name.text = "\(memberName) · \(memberRelationship)"
        name.font = .systemFont(ofSize: 15, weight: .bold)
        labels.addArrangedSubview(caption)
        labels.addArrangedSubview(name)
        let action = UILabel()
        action.text = "查看档案"
        action.font = .systemFont(ofSize: 12, weight: .bold)
        action.textColor = AppDesign.Color.darkTeal
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppDesign.Color.darkTeal
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(avatar)
        row.addArrangedSubview(labels)
        row.addArrangedSubview(action)
        row.addArrangedSubview(chevron)
        card.addContent(row)
        card.onTap = { [weak self] in
            self?.navigationController?.pushViewController(FamilyProfilesViewController(), animated: true)
        }
        return card
    }

    private func makeHubTabs() -> UIView {
        let items = [("送诊服务", "cross.case"), ("保险服务", "shield"), ("康友社区", "person.3")]
        let container = UIView()
        container.backgroundColor = UIColor(red: 0xEA / 255, green: 0xF1 / 255, blue: 0xF0 / 255, alpha: 1)
        container.layer.cornerRadius = 12
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        for (index, item) in items.enumerated() {
            let selected = index == selectedSection
            let button = UIButton(type: .system)
            button.backgroundColor = selected ? .white : .clear
            button.layer.cornerRadius = 9
            button.tintColor = selected ? AppDesign.Color.darkTeal : .secondaryLabel
            button.setImage(UIImage(systemName: item.1), for: .normal)
            button.setTitle(" " + item.0, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: selected ? .bold : .medium)
            button.heightAnchor.constraint(equalToConstant: 48).isActive = true
            button.tag = index
            button.accessibilityIdentifier = "medical-hub-tab-\(index)"
            button.addTarget(self, action: #selector(hubTabTapped(_:)), for: .touchUpInside)
            row.addArrangedSubview(button)
        }
        return container
    }

    @objc private func hubTabTapped(_ sender: UIButton) {
        selectedSection = sender.tag
        rebuild()
    }

    // MARK: - Shared helpers

    func showNotice(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    func makeSectionHeading(title: String, subtitle: String) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(subtitleLabel)
        return container
    }

    func makeStatusLabel(_ text: String, color: UIColor = AppDesign.Color.darkTeal) -> UILabel {
        let label = PaddingLabel()
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = color
        label.backgroundColor = color.withAlphaComponent(0.1)
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.contentInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        return label
    }

    func makeIconBox(systemName: String, color: UIColor) -> UIView {
        let box = UIView()
        box.backgroundColor = color.withAlphaComponent(0.1)
        box.layer.cornerRadius = 11
        let icon = UIImageView(image: UIImage(systemName: systemName))
        icon.tintColor = color
        icon.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(icon)
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: 42),
            box.heightAnchor.constraint(equalToConstant: 42),
            icon.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        return box
    }

    func makeTaskRow(icon: String, title: String, detail: String, status: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 10
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = AppDesign.Color.primaryGreen
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        let labels = UIStackView()
        labels.axis = .vertical
        labels.spacing = 3
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        labels.addArrangedSubview(titleLabel)
        labels.addArrangedSubview(detailLabel)
        let statusLabel = makeStatusLabel(status)
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(iconView)
        row.addArrangedSubview(labels)
        row.addArrangedSubview(statusLabel)
        return row
    }

    func makePrimaryButton(title: String, selector: Selector, enabled: Bool = true) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.backgroundColor = enabled ? AppDesign.Color.primaryGreen : .systemGray3
        button.layer.cornerRadius = AppDesign.CornerRadius.button
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.isEnabled = enabled
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }

    func makeSecondaryButton(title: String, selector: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(AppDesign.Color.darkTeal, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.layer.borderColor = AppDesign.Color.primaryGreen.cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = AppDesign.CornerRadius.button
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }

    func makeNoticeBox(text: String, color: UIColor) -> UIView {
        let label = PaddingLabel()
        label.text = text
        label.font = .systemFont(ofSize: 13)
        label.numberOfLines = 0
        label.backgroundColor = color.withAlphaComponent(0.1)
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.contentInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return label
    }

    func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = AppDesign.Surface.border
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return divider
    }

    // MARK: - Referral tab

    private func buildReferral() {
        stack.addArrangedSubview(makeActionGrid())
        stack.addArrangedSubview(makeSectionHeading(
            title: "推荐服务",
            subtitle: "基于当前档案给出方向性建议，临床安全与资质硬门不会因价格或偏好放宽。"
        ))
        stack.addArrangedSubview(makeRecommendationCard())
        stack.addArrangedSubview(makeSectionHeading(
            title: "选择一个主服务",
            subtitle: "每个服务单只能选择一个主服务。医院与第三方费用始终独立。"
        ))
        for (index, service) in MedicalHubViewController.services.enumerated() {
            stack.addArrangedSubview(makeServiceCard(service: service, index: index))
        }
        stack.addArrangedSubview(makeJourneyCard())
        stack.addArrangedSubview(makeSectionHeading(
            title: "候选医疗资源",
            subtitle: "已根据健康标签预选地点与科室，可修改后重新排序。候选卡展示适配理由、时限、证据和未知项。"
        ))
        stack.addArrangedSubview(makeProviderFilters())
        for (index, provider) in providerRecommendations.enumerated() {
            stack.addArrangedSubview(makeProviderCard(provider: provider, recommended: index == 0))
        }
        stack.addArrangedSubview(makeNativeExtras())
        stack.addArrangedSubview(makeNoticeBox(
            text: "安全提示：任何候选都不能替代紧急医疗判断。若症状加重或出现危险信号，请立即联系当地急救或前往适当急诊。",
            color: .systemRed
        ))
    }

    private func makeActionGrid() -> UIView {
        // Mirrors Android _ActionGrid: 紧急帮助 / 在线客服 / 发起送诊 / 跨境医疗.
        let actions: [(String, String, UIColor, Selector)] = [
            ("紧急帮助", "exclamationmark.triangle.fill", .systemRed, #selector(emergencyTapped)),
            ("在线客服", "headset", UIColor(red: 0.23, green: 0.55, blue: 0.85, alpha: 1), #selector(supportTapped)),
            ("发起送诊", "doc.text", AppDesign.Color.primaryGreen, #selector(startReferralTapped)),
            ("跨境医疗", "globe", .systemGreen, #selector(globalReferralTapped)),
        ]
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10
        var currentRow: UIStackView?
        for (index, action) in actions.enumerated() {
            if index % 2 == 0 {
                currentRow = UIStackView()
                currentRow?.axis = .horizontal
                currentRow?.spacing = 10
                currentRow?.distribution = .fillEqually
                grid.addArrangedSubview(currentRow!)
            }
            let button = UIButton(type: .system)
            button.backgroundColor = action.2.withAlphaComponent(0.1)
            button.layer.cornerRadius = 12
            button.layer.borderColor = action.2.withAlphaComponent(0.2).cgColor
            button.layer.borderWidth = 1
            button.tintColor = action.2
            button.setImage(UIImage(systemName: action.1), for: .normal)
            button.setTitle(" " + action.0, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
            button.heightAnchor.constraint(equalToConstant: 56).isActive = true
            button.addTarget(self, action: action.3, for: .touchUpInside)
            if action.0 == "发起送诊" { button.accessibilityIdentifier = "start-referral" }
            currentRow?.addArrangedSubview(button)
        }
        return grid
    }

    private func makeRecommendationCard() -> UIView {
        let card = MedicalHubCard(backgroundColor: AppDesign.Surface.highlightCard)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 10
        let topRow = UIStackView()
        topRow.axis = .horizontal
        let badge = makeStatusLabel("档案建议", color: AppDesign.Color.primaryGreen)
        let spacer = UIView()
        let icon = UIImageView(image: UIImage(systemName: "cross.case"))
        icon.tintColor = AppDesign.Color.primaryGreen
        topRow.addArrangedSubview(badge)
        topRow.addArrangedSubview(spacer)
        topRow.addArrangedSubview(icon)
        let title = UILabel()
        title.text = "先完成计划性专科评估"
        title.font = .systemFont(ofSize: 17, weight: .bold)
        let detail = UILabel()
        detail.text = "\(memberName) 的健康档案显示年度心血管复查即将到期。建议 30 天内评估；若出现胸痛、严重呼吸困难或意识改变，请立即升级处理。"
        detail.font = .systemFont(ofSize: 13)
        detail.textColor = .secondaryLabel
        detail.numberOfLines = 0
        let tags = UIStackView()
        tags.axis = .horizontal
        tags.spacing = 8
        ["A3 计划就诊", "有效期 30 天", "可人工复核"].forEach { tags.addArrangedSubview(makeStatusLabel($0)) }
        tags.addArrangedSubview(UIView())
        content.addArrangedSubview(topRow)
        content.addArrangedSubview(title)
        content.addArrangedSubview(detail)
        content.addArrangedSubview(tags)
        card.addContent(content)
        card.onTap = { [weak self] in self?.startReferral(channel: "线下门诊") }
        return card
    }

    private func makeServiceCard(service: MedicalService, index: Int) -> UIView {
        let selected = index == selectedService
        let card = MedicalHubCard(backgroundColor: selected ? AppDesign.Surface.highlightCard : AppDesign.Surface.elevatedCard)
        if selected {
            card.layer.borderColor = AppDesign.Color.primaryGreen.cgColor
            card.layer.borderWidth = 1.5
        }
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 10
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.alignment = .top
        headerRow.spacing = 12
        headerRow.addArrangedSubview(makeIconBox(systemName: service.icon, color: AppDesign.Color.primaryGreen))
        let labels = UIStackView()
        labels.axis = .vertical
        labels.spacing = 4
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.spacing = 8
        let title = UILabel()
        title.text = service.title
        title.font = .systemFont(ofSize: 16, weight: .bold)
        titleRow.addArrangedSubview(title)
        titleRow.addArrangedSubview(UIView())
        if selected { titleRow.addArrangedSubview(makeStatusLabel("已选择", color: AppDesign.Color.primaryGreen)) }
        let subtitle = UILabel()
        subtitle.text = service.subtitle
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0
        let price = UILabel()
        price.text = service.price
        price.font = .systemFont(ofSize: 14, weight: .bold)
        price.textColor = AppDesign.Color.darkTeal
        labels.addArrangedSubview(titleRow)
        labels.addArrangedSubview(subtitle)
        labels.addArrangedSubview(price)
        headerRow.addArrangedSubview(labels)
        let includes = UIStackView()
        includes.axis = .horizontal
        includes.spacing = 6
        service.includes.forEach { includes.addArrangedSubview(makeStatusLabel($0)) }
        includes.addArrangedSubview(UIView())
        let includesScroll = UIScrollView()
        includesScroll.showsHorizontalScrollIndicator = false
        includes.translatesAutoresizingMaskIntoConstraints = false
        includesScroll.addSubview(includes)
        NSLayoutConstraint.activate([
            includes.topAnchor.constraint(equalTo: includesScroll.topAnchor),
            includes.leadingAnchor.constraint(equalTo: includesScroll.leadingAnchor),
            includes.trailingAnchor.constraint(equalTo: includesScroll.trailingAnchor),
            includes.bottomAnchor.constraint(equalTo: includesScroll.bottomAnchor),
            includes.heightAnchor.constraint(equalTo: includesScroll.heightAnchor),
        ])
        let excludesRow = UIStackView()
        excludesRow.axis = .horizontal
        excludesRow.alignment = .top
        excludesRow.spacing = 6
        let infoIcon = UIImageView(image: UIImage(systemName: "info.circle"))
        infoIcon.tintColor = .systemOrange
        let excludesLabel = UILabel()
        excludesLabel.text = service.excludes
        excludesLabel.font = .systemFont(ofSize: 12)
        excludesLabel.textColor = .secondaryLabel
        excludesLabel.numberOfLines = 0
        excludesRow.addArrangedSubview(infoIcon)
        excludesRow.addArrangedSubview(excludesLabel)
        let buttonsRow = UIStackView()
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 8
        buttonsRow.distribution = .fillEqually
        let selectButton = makeSecondaryButton(title: selected ? "当前选择" : "选择服务", selector: #selector(serviceSelectTapped(_:)))
        selectButton.tag = index
        let startButton = makePrimaryButton(title: "开始评估", selector: #selector(serviceStartTapped(_:)))
        startButton.tag = index
        buttonsRow.addArrangedSubview(selectButton)
        buttonsRow.addArrangedSubview(startButton)
        content.addArrangedSubview(headerRow)
        content.addArrangedSubview(includesScroll)
        content.addArrangedSubview(excludesRow)
        content.addArrangedSubview(buttonsRow)
        card.addContent(content)
        card.onTap = { [weak self] in
            self?.selectedService = index
            self?.rebuild()
        }
        return card
    }

    @objc private func serviceSelectTapped(_ sender: UIButton) {
        selectedService = sender.tag
        rebuild()
    }

    @objc private func serviceStartTapped(_ sender: UIButton) {
        startReferral(channel: sender.tag == 2 ? "跨境医疗" : "线下门诊")
    }

    private func makeJourneyCard() -> UIView {
        guard let referral else {
            return makeEmptyActionCard(
                icon: "map",
                title: "我的就诊进度",
                description: "完成建档与初筛后，可在这里查看平台、医院直付和资料三类待办。",
                actionLabel: "发起送诊",
                selector: #selector(startReferralTapped)
            )
        }
        let service = MedicalHubViewController.services[selectedService]
        let card = MedicalHubCard(backgroundColor: AppDesign.Surface.elevatedCard)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 12
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        let title = UILabel()
        title.text = "我的就诊进度"
        title.font = .systemFont(ofSize: 17, weight: .bold)
        headerRow.addArrangedSubview(title)
        headerRow.addArrangedSubview(UIView())
        headerRow.addArrangedSubview(makeStatusLabel(quoteConfirmed ? "待签协议" : "资料初审", color: AppDesign.Color.primaryGreen))
        let progress = UIProgressView(progressViewStyle: .bar)
        progress.progress = quoteConfirmed ? 0.35 : 0.18
        progress.progressTintColor = AppDesign.Color.primaryGreen
        progress.trackTintColor = AppDesign.Surface.border
        progress.layer.cornerRadius = 4
        progress.clipsToBounds = true
        let progressText = UILabel()
        progressText.text = quoteConfirmed
            ? "费用边界已确认 · 等待协议签署"
            : "\(referral.urgency) · \(referral.channel) · 顾问将在 1 个工作日内初审"
        progressText.font = .systemFont(ofSize: 12)
        progressText.textColor = .secondaryLabel
        content.addArrangedSubview(headerRow)
        content.addArrangedSubview(progress)
        content.addArrangedSubview(progressText)
        content.addArrangedSubview(makeTaskRow(
            icon: "doc.text",
            title: "资料待办",
            detail: referral.hasRecords ? "上传病历资料包" : "补充既往诊疗资料（如有）",
            status: "待完成"
        ))
        content.addArrangedSubview(makeDivider())
        content.addArrangedSubview(makeTaskRow(
            icon: "headset",
            title: "平台服务待办",
            detail: quoteConfirmed ? "专属顾问：林顾问 · 预计今天 18:00 前" : "确认 \(service.title) 服务方案与单笔报价",
            status: quoteConfirmed ? "处理中" : "待确认"
        ))
        content.addArrangedSubview(makeDivider())
        content.addArrangedSubview(makeTaskRow(
            icon: "building.columns",
            title: "医院直付待办",
            detail: "医院尚未回传预算或正式付款指引",
            status: "暂无预算"
        ))
        let buttonsRow = UIStackView()
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 8
        buttonsRow.distribution = .fillEqually
        buttonsRow.addArrangedSubview(makeSecondaryButton(title: "医院费用中心", selector: #selector(hospitalCostsTapped)))
        buttonsRow.addArrangedSubview(makePrimaryButton(
            title: quoteConfirmed ? "已确认费用边界" : "查看服务方案",
            selector: #selector(quoteTapped),
            enabled: !quoteConfirmed
        ))
        content.addArrangedSubview(buttonsRow)
        card.addContent(content)
        return card
    }

    private func makeProviderFilters() -> UIView {
        let card = MedicalHubCard(backgroundColor: AppDesign.Surface.highlightCard)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 12
        let hintRow = UIStackView()
        hintRow.axis = .horizontal
        hintRow.alignment = .top
        hintRow.spacing = 8
        let sparkIcon = UIImageView(image: UIImage(systemName: "sparkles"))
        sparkIcon.tintColor = AppDesign.Color.primaryGreen
        let hint = UILabel()
        hint.text = "已根据“血压趋势稳定”和“30 天内心血管复查”自动预选"
        hint.font = .systemFont(ofSize: 12)
        hint.numberOfLines = 0
        hintRow.addArrangedSubview(sparkIcon)
        hintRow.addArrangedSubview(hint)
        let fieldsRow = UIStackView()
        fieldsRow.axis = .horizontal
        fieldsRow.spacing = 10
        fieldsRow.distribution = .fillEqually
        let locationButton = makeFilterButton(title: "地点", value: providerLocation, selector: #selector(locationFilterTapped(_:)))
        locationButton.accessibilityIdentifier = "provider-location-filter"
        let departmentButton = makeFilterButton(title: "科室", value: providerDepartment, selector: #selector(departmentFilterTapped(_:)))
        departmentButton.accessibilityIdentifier = "provider-department-filter"
        fieldsRow.addArrangedSubview(locationButton)
        fieldsRow.addArrangedSubview(departmentButton)
        content.addArrangedSubview(hintRow)
        content.addArrangedSubview(fieldsRow)
        card.addContent(content)
        return card
    }

    private func makeFilterButton(title: String, value: String, selector: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 10
        button.layer.borderColor = AppDesign.Surface.border.cgColor
        button.layer.borderWidth = 1
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        let attributed = NSMutableAttributedString(
            string: title + "  ",
            attributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.secondaryLabel]
        )
        attributed.append(NSAttributedString(
            string: value,
            attributes: [.font: UIFont.systemFont(ofSize: 14, weight: .semibold), .foregroundColor: UIColor.label]
        ))
        button.setAttributedTitle(attributed, for: .normal)
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }

    @objc private func locationFilterTapped(_ sender: UIButton) {
        presentOptions(title: "地点", options: ["北京", "上海", "新加坡", "美国"], current: providerLocation, sourceView: sender) { [weak self] value in
            self?.providerLocation = value
            self?.rebuild()
        }
    }

    @objc private func departmentFilterTapped(_ sender: UIButton) {
        presentOptions(title: "科室", options: ["心内科", "呼吸与睡眠", "内分泌科", "肿瘤科"], current: providerDepartment, sourceView: sender) { [weak self] value in
            self?.providerDepartment = value
            self?.rebuild()
        }
    }

    private func presentOptions(title: String, options: [String], current: String, sourceView: UIView, onSelect: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for option in options {
            let title = option == current ? "\(option) ✓" : option
            alert.addAction(UIAlertAction(title: title, style: .default) { _ in onSelect(option) })
        }
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(alert, animated: true)
    }

    private func makeProviderCard(provider: (name: String, location: String, reason: String, evidence: String, score: Int), recommended: Bool) -> UIView {
        let card = MedicalHubCard(backgroundColor: AppDesign.Surface.elevatedCard)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 10
        if recommended {
            let badgeRow = UIStackView()
            badgeRow.axis = .horizontal
            let badge = PaddingLabel()
            badge.text = "最优推荐"
            badge.font = .systemFont(ofSize: 11, weight: .bold)
            badge.textColor = .systemGreen
            badge.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.12)
            badge.layer.cornerRadius = 8
            badge.layer.masksToBounds = true
            badge.contentInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
            let score = UILabel()
            score.text = "标签匹配 \(provider.score)%"
            score.font = .systemFont(ofSize: 12, weight: .bold)
            score.textColor = AppDesign.Color.darkTeal
            badgeRow.addArrangedSubview(badge)
            badgeRow.addArrangedSubview(UIView())
            badgeRow.addArrangedSubview(score)
            content.addArrangedSubview(badgeRow)
        }
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 10
        headerRow.alignment = .center
        headerRow.addArrangedSubview(makeIconBox(systemName: "cross.case", color: AppDesign.Color.primaryGreen))
        let labels = UIStackView()
        labels.axis = .vertical
        labels.spacing = 3
        let name = UILabel()
        name.text = provider.name
        name.font = .systemFont(ofSize: 15, weight: .bold)
        name.numberOfLines = 0
        let location = UILabel()
        location.text = provider.location
        location.font = .systemFont(ofSize: 12)
        location.textColor = .secondaryLabel
        labels.addArrangedSubview(name)
        labels.addArrangedSubview(location)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        headerRow.addArrangedSubview(labels)
        headerRow.addArrangedSubview(chevron)
        let reason = UILabel()
        reason.text = "为什么适合：\(provider.reason)"
        reason.font = .systemFont(ofSize: 13)
        reason.numberOfLines = 0
        let evidence = UILabel()
        evidence.text = provider.evidence
        evidence.font = .systemFont(ofSize: 12)
        evidence.textColor = .secondaryLabel
        evidence.numberOfLines = 0
        content.addArrangedSubview(headerRow)
        content.addArrangedSubview(reason)
        content.addArrangedSubview(evidence)
        card.addContent(content)
        card.onTap = { [weak self] in self?.showProviderDetails(name: provider.name) }
        return card
    }

    /// Keeps the pre-existing native Global Care entries reachable alongside the
    /// Android-parity sections (parity doc: retain extra native functionality).
    private func makeNativeExtras() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 10
        container.addArrangedSubview(makeSectionHeading(title: "平台原生服务", subtitle: "iOS 端已有的 Global Care 流程入口。"))
        let extras: [(String, String, String, Selector)] = [
            ("Global Care 服务申请", "提交跨境医疗服务申请与订单", "cross.case.fill", #selector(globalCareTapped)),
            ("AI 智能预评估", "AI 初筛症状、检查资料与匹配医院", "wand.and.stars", #selector(aiAssessmentTapped)),
        ]
        for extra in extras {
            let card = MedicalHubCard(backgroundColor: AppDesign.Surface.elevatedCard)
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 14
            row.alignment = .center
            let icon = UIImageView(image: UIImage(systemName: extra.2))
            icon.tintColor = AppDesign.Color.primaryGreen
            icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
            let labels = UIStackView()
            labels.axis = .vertical
            labels.spacing = 4
            let title = UILabel()
            title.text = extra.0
            title.font = .systemFont(ofSize: 16, weight: .semibold)
            let detail = UILabel()
            detail.text = extra.1
            detail.font = .systemFont(ofSize: 13)
            detail.textColor = .secondaryLabel
            detail.numberOfLines = 2
            labels.addArrangedSubview(title)
            labels.addArrangedSubview(detail)
            row.addArrangedSubview(icon)
            row.addArrangedSubview(labels)
            card.addContent(row)
            let action = extra.3
            card.onTap = { [weak self] in self?.perform(action) }
            container.addArrangedSubview(card)
        }
        return container
    }

    private func makeEmptyActionCard(icon: String, title: String, description: String, actionLabel: String, selector: Selector) -> UIView {
        let card = MedicalHubCard(backgroundColor: AppDesign.Surface.elevatedCard)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 10
        content.alignment = .center
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .secondaryLabel
        iconView.widthAnchor.constraint(equalToConstant: 36).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 36).isActive = true
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        let detailLabel = UILabel()
        detailLabel.text = description
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .center
        let button = makePrimaryButton(title: actionLabel, selector: selector)
        button.widthAnchor.constraint(equalToConstant: 160).isActive = true
        content.addArrangedSubview(iconView)
        content.addArrangedSubview(titleLabel)
        content.addArrangedSubview(detailLabel)
        content.addArrangedSubview(button)
        card.addContent(content)
        return card
    }

    // MARK: - Referral actions

    @objc private func emergencyTapped() {
        let alert = UIAlertController(
            title: "紧急情况请立即求助",
            message: "如有持续胸痛、严重呼吸困难、意识改变、大出血或其他危及生命的情况，请立即联系当地急救服务或前往最近的适当急诊。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "我知道了", style: .cancel))
        alert.addAction(UIAlertAction(title: "联系当地急救", style: .default))
        present(alert, animated: true)
    }

    @objc private func supportTapped() {
        showNotice("专属顾问将在服务时段内联系你")
    }

    @objc private func startReferralTapped() { startReferral(channel: "线下门诊") }

    @objc private func globalReferralTapped() { startReferral(channel: "跨境医疗") }

    @objc private func globalCareTapped() {
        navigationController?.pushViewController(CareApplicationViewController(), animated: true)
    }

    @objc private func aiAssessmentTapped() {
        navigationController?.pushViewController(AIAssessmentViewController(), animated: true)
    }

    func startReferral(channel: String) {
        let sheet = MedicalFormSheetViewController(
            title: "送诊建档与初筛",
            subtitle: "为 \(memberName) 建立送诊资料，平台顾问将在 1 个工作日内完成初审。",
            fields: [
                .multiline(id: "complaint", title: "主要诉求", placeholder: "描述症状、诊断或希望获得的医疗支持", required: true),
                .choice(id: "urgency", title: "紧急程度", options: ["计划就诊", "尽快安排", "紧急"], selected: 0),
                .choice(id: "channel", title: "就诊渠道", options: ["线下门诊", "跨境医疗", "远程问诊"], selected: channel == "跨境医疗" ? 1 : 0),
                .toggle(id: "hasRecords", title: "已有病历或检查资料", isOn: false),
            ],
            submitTitle: "提交送诊资料"
        ) { [weak self] values in
            guard let self else { return }
            self.referral = ReferralIntakeResult(
                complaint: values["complaint"] as? String ?? "",
                urgency: values["urgency"] as? String ?? "计划就诊",
                channel: values["channel"] as? String ?? "线下门诊",
                hasRecords: values["hasRecords"] as? Bool ?? false
            )
            self.quoteConfirmed = false
            self.rebuild()
            self.showNotice("送诊资料已提交，将在 1 个工作日内完成初审")
        }
        present(sheet, animated: true)
    }

    @objc private func quoteTapped() {
        let service = MedicalHubViewController.services[selectedService]
        let sheet = MedicalDetailSheetViewController(
            title: "\(service.title) 服务方案",
            subtitle: "平台服务费：\(service.price)（医院与第三方费用始终独立）",
            lines: [
                ("服务包含", service.includes.joined(separator: "、")),
                ("不包含", service.excludes),
                ("费用边界", "确认后进入协议签署；当前不会发起真实支付"),
            ],
            notice: "平台结果为服务协调报价，不构成医疗建议或支付承诺。",
            actionTitle: "确认费用边界"
        ) { [weak self] in
            self?.quoteConfirmed = true
            self?.rebuild()
            self?.showNotice("费用边界已确认，下一步为协议签署；当前未发起真实支付")
        }
        present(sheet, animated: true)
    }

    @objc private func hospitalCostsTapped() {
        let sheet = MedicalDetailSheetViewController(
            title: "医院费用中心",
            subtitle: "医院预算、正式账单和直付凭证与平台服务订单完全分开。",
            lines: [
                ("接收医院", "待确认 · 暂无医院预算 · 正式付款指引待回传"),
            ],
            notice: "医院费用由医院收取，退款请按医院政策办理。平台不提供“立即支付医院费”按钮；官方外链会进行域名白名单校验。",
            actionTitle: "上传医院付款凭证"
        )
        present(sheet, animated: true)
    }

    private func showProviderDetails(name: String) {
        let sheet = MedicalDetailSheetViewController(
            title: name,
            subtitle: nil,
            lines: [
                ("最早可约", "6-12 天，号源更新于 15 分钟前"),
                ("适配理由", "专科能力、适用人群、设备和连续性符合当前需求"),
                ("费用与权益", "网络状态待核验；预计自付区间将在预评估后更新"),
                ("质量证据", "显示风险调整结果、样本量与区间；证据不足时不会隐藏"),
                ("替代方案", "可优先更近、更快或更低预计自付的合格候选"),
            ],
            notice: "安全提示：任何候选都不能替代紧急医疗判断。若症状加重或出现危险信号，请立即联系当地急救或前往适当急诊。"
        )
        present(sheet, animated: true)
    }
}
