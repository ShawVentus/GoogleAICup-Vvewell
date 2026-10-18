import UIKit

/// Tappable card container used across the medical hub.
final class MedicalHubCard: UIView {
    var onTap: (() -> Void)? {
        didSet {
            if onTap != nil && gestureRecognizers?.isEmpty != false {
                addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
            }
        }
    }

    init(backgroundColor: UIColor = AppDesign.Surface.elevatedCard) {
        super.init(frame: .zero)
        self.backgroundColor = backgroundColor
        layer.cornerRadius = 14
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.04
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func addContent(_ content: UIView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])
    }

    @objc private func tapped() { onTap?() }
}

// MARK: - Insurance tab

extension MedicalHubViewController {

    func buildInsurance() {
        stack.addArrangedSubview(makeInsuranceHero())
        stack.addArrangedSubview(makeSectionHeading(
            title: "保障缺口分析",
            subtitle: "基于家庭结构、年龄与收入责任的快速分析，不构成保险销售建议。"
        ))
        for (index, gap) in [("住院医疗", 65, UIColor.systemOrange), ("重大疾病", 40, UIColor.systemRed), ("意外保障", 85, UIColor.systemGreen)].enumerated() {
            stack.addArrangedSubview(makeGapCard(name: gap.0, coverage: gap.1, color: gap.2, index: index))
        }
        stack.addArrangedSubview(makeSectionHeading(
            title: "推荐保障方案",
            subtitle: "推荐按家庭收入责任、预算上限与现有保单缺口排序，不构成保险销售建议。"
        ))
        if let insuranceNeeds {
            stack.addArrangedSubview(makeNoticeBox(
                text: "当前需求：年度预算上限 ¥\(insuranceNeeds.annualBudget) · 优先保障：\(insuranceNeeds.priority)\(insuranceNeeds.hasExistingPolicy ? " · 已有保单需避免重复投保" : "")",
                color: AppDesign.Color.primaryGreen
            ))
        }
        for plan in MedicalHubViewController.plans {
            stack.addArrangedSubview(makePlanCard(plan: plan))
        }
        stack.addArrangedSubview(makePolicyServiceCard())
        stack.addArrangedSubview(makeNoticeBox(
            text: "边界说明：平台推荐基于家庭收入责任与现有保单缺口，不构成保险销售建议；正式投保、健康告知与理赔决定以持牌机构的书面确认为准。",
            color: .systemOrange
        ))
    }

    private func makeInsuranceHero() -> UIView {
        let card = MedicalHubCard(backgroundColor: AppDesign.Surface.highlightCard)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 12
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.alignment = .center
        let title = UILabel()
        title.text = "\(memberName) 的保险方案"
        title.font = .systemFont(ofSize: 20, weight: .bold)
        let icon = UIImageView(image: UIImage(systemName: "shield"))
        icon.tintColor = AppDesign.Color.primaryGreen
        icon.setContentHuggingPriority(.required, for: .horizontal)
        topRow.addArrangedSubview(title)
        topRow.addArrangedSubview(UIView())
        topRow.addArrangedSubview(icon)
        let subtitle = UILabel()
        subtitle.text = "基于家庭收入责任与现有保单缺口，将长期保障规划与理赔进度放在同一条工作流中。"
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0
        let buttonsRow = UIStackView()
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 8
        buttonsRow.distribution = .fillEqually
        buttonsRow.addArrangedSubview(makeSecondaryButton(title: "更新保障需求", selector: #selector(insuranceNeedsTapped)))
        buttonsRow.addArrangedSubview(makePrimaryButton(title: "新建理赔申请", selector: #selector(claimTapped)))
        content.addArrangedSubview(topRow)
        content.addArrangedSubview(subtitle)
        content.addArrangedSubview(buttonsRow)
        card.addContent(content)
        return card
    }

    private func makeGapCard(name: String, coverage: Int, color: UIColor, index: Int) -> UIView {
        // Mirrors Android _GapCard with exposure notes and 补充建议 action.
        let exposureNotes = ["住院医疗缺口影响大额住院费用，优先级高", "重大疾病给付不足会影响家庭收入责任", "意外保障覆盖相对充分，可维持"]
        let card = MedicalHubCard(backgroundColor: AppDesign.Surface.elevatedCard)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 8
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        let title = UILabel()
        title.text = name
        title.font = .systemFont(ofSize: 15, weight: .bold)
        headerRow.addArrangedSubview(title)
        headerRow.addArrangedSubview(UIView())
        headerRow.addArrangedSubview(makeStatusLabel("覆盖 \(coverage)%", color: color))
        let progress = UIProgressView(progressViewStyle: .bar)
        progress.progress = Float(coverage) / 100
        progress.progressTintColor = color
        progress.trackTintColor = AppDesign.Surface.border
        progress.layer.cornerRadius = 4
        progress.clipsToBounds = true
        let note = UILabel()
        note.text = exposureNotes[index]
        note.font = .systemFont(ofSize: 12)
        note.textColor = .secondaryLabel
        note.numberOfLines = 0
        let advisorButton = UIButton(type: .system)
        advisorButton.setTitle("补充建议", for: .normal)
        advisorButton.tintColor = AppDesign.Color.darkTeal
        advisorButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        advisorButton.contentHorizontalAlignment = .left
        advisorButton.tag = index
        advisorButton.addTarget(self, action: #selector(gapAdvisorTapped(_:)), for: .touchUpInside)
        content.addArrangedSubview(headerRow)
        content.addArrangedSubview(progress)
        content.addArrangedSubview(note)
        content.addArrangedSubview(advisorButton)
        card.addContent(content)
        return card
    }

    private func makePlanCard(plan: InsurancePlan) -> UIView {
        let card = MedicalHubCard(backgroundColor: AppDesign.Surface.elevatedCard)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 10
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.alignment = .top
        headerRow.spacing = 12
        headerRow.addArrangedSubview(makeIconBox(systemName: "shield", color: AppDesign.Color.primaryGreen))
        let labels = UIStackView()
        labels.axis = .vertical
        labels.spacing = 3
        let name = UILabel()
        name.text = plan.name
        name.font = .systemFont(ofSize: 15, weight: .bold)
        name.numberOfLines = 0
        let provider = UILabel()
        provider.text = plan.provider
        provider.font = .systemFont(ofSize: 12)
        provider.textColor = .secondaryLabel
        labels.addArrangedSubview(name)
        labels.addArrangedSubview(provider)
        let price = UILabel()
        price.text = plan.price
        price.font = .systemFont(ofSize: 14, weight: .bold)
        price.textColor = AppDesign.Color.darkTeal
        price.setContentHuggingPriority(.required, for: .horizontal)
        headerRow.addArrangedSubview(labels)
        headerRow.addArrangedSubview(price)
        let match = UILabel()
        match.text = "推荐理由：匹配度 \(plan.match)%，\(plan.fit)"
        match.font = .systemFont(ofSize: 13)
        match.numberOfLines = 0
        let limit = UILabel()
        limit.text = "限制条件：\(plan.limit)"
        limit.font = .systemFont(ofSize: 12)
        limit.textColor = .secondaryLabel
        limit.numberOfLines = 0
        let buttonsRow = UIStackView()
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 8
        buttonsRow.distribution = .fillEqually
        let detailsButton = makeSecondaryButton(title: "查看计划详情", selector: #selector(planDetailsTapped(_:)))
        detailsButton.accessibilityIdentifier = "plan-\(plan.name)"
        let advisorButton = makePrimaryButton(title: "咨询顾问", selector: #selector(planAdvisorTapped(_:)))
        advisorButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        advisorButton.accessibilityValue = plan.name
        buttonsRow.addArrangedSubview(detailsButton)
        buttonsRow.addArrangedSubview(advisorButton)
        content.addArrangedSubview(headerRow)
        content.addArrangedSubview(match)
        content.addArrangedSubview(limit)
        content.addArrangedSubview(buttonsRow)
        card.addContent(content)
        card.accessibilityValue = plan.name
        return card
    }

    private func makePolicyServiceCard() -> UIView {
        let card = MedicalHubCard(backgroundColor: AppDesign.Surface.elevatedCard)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 12
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        let title = UILabel()
        title.text = "保单与理赔服务"
        title.font = .systemFont(ofSize: 17, weight: .bold)
        headerRow.addArrangedSubview(title)
        headerRow.addArrangedSubview(UIView())
        headerRow.addArrangedSubview(makeStatusLabel(claimDraft != nil ? "材料初审" : "资料完整", color: AppDesign.Color.primaryGreen))
        content.addArrangedSubview(headerRow)
        content.addArrangedSubview(makeTaskRow(icon: "shield", title: "保单任务", detail: "保障需求 \(insuranceNeeds != nil ? "已更新" : "待更新")", status: insuranceNeeds != nil ? "已更新" : "待更新"))
        content.addArrangedSubview(makeDivider())
        content.addArrangedSubview(makeTaskRow(
            icon: "doc.text",
            title: "理赔服务",
            detail: claimDraft != nil ? "\(claimDraft!.type)申请已创建" : "暂无进行中理赔",
            status: claimDraft != nil ? "材料初审" : "暂无"
        ))
        let buttonsRow = UIStackView()
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 8
        buttonsRow.distribution = .fillEqually
        buttonsRow.addArrangedSubview(makeSecondaryButton(title: "预授权 / 直付咨询", selector: #selector(preAuthTapped)))
        buttonsRow.addArrangedSubview(makePrimaryButton(title: "新建理赔申请", selector: #selector(claimTapped)))
        content.addArrangedSubview(buttonsRow)
        card.addContent(content)
        return card
    }

    @objc private func insuranceNeedsTapped() {
        let sheet = MedicalFormSheetViewController(
            title: "更新保障需求",
            subtitle: "用于优化推荐排序，不构成保险销售建议。",
            fields: [
                .text(id: "budget", title: "年度预算上限", placeholder: "例如 5000", keyboard: .numberPad, required: true),
                .choice(id: "priority", title: "优先保障", options: ["住院医疗", "重大疾病", "意外保障"], selected: 0),
                .toggle(id: "hasPolicy", title: "已有商业保险保单", isOn: false),
            ],
            submitTitle: "保存保障需求"
        ) { [weak self] values in
            guard let self else { return }
            let budget = Int(values["budget"] as? String ?? "") ?? 5000
            self.insuranceNeeds = InsuranceNeedsResult(
                annualBudget: budget,
                priority: values["priority"] as? String ?? "住院医疗",
                hasExistingPolicy: values["hasPolicy"] as? Bool ?? false
            )
            self.rebuild()
            self.showNotice("保障需求已更新")
        }
        present(sheet, animated: true)
    }

    @objc private func claimTapped() {
        let sheet = MedicalFormSheetViewController(
            title: "新建理赔申请",
            subtitle: "为 \(memberName) 创建理赔申请草稿，案件经理将在 1 个工作日内联系。",
            fields: [
                .choice(id: "type", title: "理赔类型", options: ["门诊医疗", "住院医疗", "重大疾病"], selected: 0),
                .text(id: "amount", title: "预计金额", placeholder: "例如 12000", keyboard: .numberPad, required: true),
            ],
            submitTitle: "创建理赔申请"
        ) { [weak self] values in
            guard let self else { return }
            let amount = Int(values["amount"] as? String ?? "") ?? 0
            self.claimDraft = ClaimDraftResult(
                type: values["type"] as? String ?? "门诊医疗",
                amount: amount
            )
            self.rebuild()
            self.showNotice("理赔申请已创建，案件经理将在 1 个工作日内联系")
        }
        present(sheet, animated: true)
    }

    @objc private func gapAdvisorTapped(_ sender: UIButton) {
        contactAdvisor(productName: "保障缺口 · \(["住院医疗", "重大疾病", "意外保障"][sender.tag])")
    }

    @objc private func planDetailsTapped(_ sender: UIButton) {
        guard let name = sender.accessibilityIdentifier?.replacingOccurrences(of: "plan-", with: ""),
              let plan = MedicalHubViewController.plans.first(where: { $0.name == name }) else { return }
        let sheet = MedicalDetailSheetViewController(
            title: plan.name,
            subtitle: "\(plan.provider) · \(plan.price) · 保额 \(plan.coverage)",
            lines: [
                ("自付预测", "P50 \(plan.p50) · P90 \(plan.p90) · P95 \(plan.p95)"),
                ("免赔额", plan.deductible),
                ("等待期", plan.waiting),
                ("为什么适合", plan.fit),
                ("主要限制", plan.limit),
            ],
            notice: "平台结果为方案推荐，不构成保险销售建议。正式投保、健康告知与理赔决定以持牌机构的书面确认为准。"
        )
        present(sheet, animated: true)
    }

    @objc private func planAdvisorTapped(_ sender: UIButton) {
        contactAdvisor(productName: sender.accessibilityValue ?? "推荐保障方案")
    }

    @objc private func preAuthTapped() {
        showNotice("预授权与直付合作需由保险公司书面确认")
    }

    private func contactAdvisor(productName: String) {
        let sheet = MedicalFormSheetViewController(
            title: "联系持牌保险顾问",
            subtitle: "顾问将在服务时段内回电，优先解答 \(productName) 相关问题。",
            fields: [
                .text(id: "name", title: "姓名", placeholder: "请输入姓名", keyboard: .default, required: true),
                .text(id: "phone", title: "联系电话", placeholder: "请输入手机号", keyboard: .phonePad, required: true),
                .choice(id: "channel", title: "联系方式", options: ["电话", "微信"], selected: 0),
                .choice(id: "time", title: "方便联系时间", options: ["工作日上午", "工作日下午", "工作日晚上", "周末"], selected: 0),
            ],
            submitTitle: "预约顾问回电"
        ) { [weak self] values in
            guard let self else { return }
            let contact = AdvisorContactResult(
                name: values["name"] as? String ?? "",
                phone: values["phone"] as? String ?? "",
                contactChannel: values["channel"] as? String ?? "电话",
                preferredTime: values["time"] as? String ?? "工作日上午",
                productName: productName
            )
            self.showNotice("已预约顾问回电：\(contact.preferredTime) · \(contact.contactChannel)")
        }
        present(sheet, animated: true)
    }
}

// MARK: - Community tab

extension MedicalHubViewController {

    struct CommunityPost {
        let id, title, detail, author, role, topic, time: String
        let isNew: Bool
    }

    // DIRTY HACK: Android parity demo data (mirrors _CommunityPageState._visiblePosts fixture).
    var visiblePosts: [CommunityPost] {
        var posts = [
            CommunityPost(id: "post-1", title: "化疗期间的饮食安排经验", detail: "分享治疗期间营养补充和胃口管理的做法，供参考", author: "向阳而生", role: "康复 3 年", topic: "治疗经验", time: "2 小时前", isNew: false),
            CommunityPost(id: "post-2", title: "复诊前如何整理问题清单", detail: "提前记录症状变化、用药反应和想问医生的问题", author: "慢慢走", role: "照护者", topic: "康复随访", time: "昨天", isNew: false),
            CommunityPost(id: "post-3", title: "和家人沟通治疗决定的一些心得", detail: "把信息分层说明，先讲目标再讲方案，减少焦虑", author: "晴天", role: "康友", topic: "心理生活", time: "3 天前", isNew: false),
        ]
        posts.insert(contentsOf: newPosts.enumerated().map { index, draft in
            CommunityPost(id: "local-\(index)", title: draft.content, detail: "你刚创建的分享（演示）", author: "我", role: "成员", topic: draft.type, time: "刚刚", isNew: true)
        }, at: 0)
        return posts
    }

    var filteredCommunities: [Community] {
        MedicalHubViewController.communities.filter { community in
            let matchesTopic = communityTopic == "推荐" || communityTopic == "最新" || community.topic == communityTopic
            let query = communityQuery
            let matchesQuery = query.isEmpty
                || community.name.contains(query)
                || community.description.contains(query)
                || community.topic.contains(query)
            return matchesTopic && matchesQuery
        }
    }

    var filteredPosts: [CommunityPost] {
        visiblePosts.filter { post in
            let matchesTopic = communityTopic == "推荐" || communityTopic == "最新" || post.topic == communityTopic
            let query = communityQuery
            let matchesQuery = query.isEmpty
                || post.title.contains(query)
                || post.detail.contains(query)
                || post.topic.contains(query)
            return matchesTopic && matchesQuery
        }
    }

    func buildCommunity() {
        stack.addArrangedSubview(makeSectionHeading(
            title: "康友社区",
            subtitle: "找到与你有相似经历的人，在保护隐私的前提下交流经验、获得支持。"
        ))
        stack.addArrangedSubview(makeCommunitySearch())
        stack.addArrangedSubview(makeCommunityTopicChips())
        for community in filteredCommunities {
            stack.addArrangedSubview(makeCommunityCard(community: community))
        }
        stack.addArrangedSubview(makeCommunityPostsSection())
        stack.addArrangedSubview(makeCommunityEventCard())
        stack.addArrangedSubview(makeNoticeBox(
            text: "社区规则：分享经验不等于医疗建议；请勿发布联系方式、诊断书、医保号等敏感信息。涉及个人隐私的内容请先取得当事人同意。",
            color: .systemRed
        ))
    }

    private func makeCommunitySearch() -> UIView {
        let field = UITextField()
        field.placeholder = "搜索社区或内容"
        field.font = .systemFont(ofSize: 15)
        field.backgroundColor = AppDesign.Surface.elevatedCard
        field.layer.cornerRadius = 12
        field.leftView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        field.leftViewMode = .always
        field.clearButtonMode = .whileEditing
        field.text = communityQuery
        field.heightAnchor.constraint(equalToConstant: 48).isActive = true
        field.addTarget(self, action: #selector(communitySearchChanged(_:)), for: .editingChanged)
        communitySearchField = field
        return field
    }

    @objc private func communitySearchChanged(_ sender: UITextField) {
        communityQuery = sender.text ?? ""
        rebuild()
        communitySearchField?.becomeFirstResponder()
    }

    private func makeCommunityTopicChips() -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.topAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.heightAnchor),
        ])
        for topic in MedicalHubViewController.communityTopics {
            let selected = topic == communityTopic
            let button = UIButton(type: .system)
            button.setTitle(topic, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: selected ? .bold : .medium)
            button.tintColor = selected ? .white : AppDesign.Color.darkTeal
            button.backgroundColor = selected ? AppDesign.Color.darkTeal : AppDesign.Surface.highlightCard
            button.layer.cornerRadius = 15
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            button.accessibilityValue = topic
            button.addTarget(self, action: #selector(communityTopicTapped(_:)), for: .touchUpInside)
            row.addArrangedSubview(button)
        }
        scroll.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return scroll
    }

    @objc private func communityTopicTapped(_ sender: UIButton) {
        communityTopic = sender.accessibilityValue ?? "推荐"
        rebuild()
    }

    private func makeCommunityCard(community: Community) -> UIView {
        let joined = joinedCommunities.contains(community.id)
        let card = MedicalHubCard(backgroundColor: AppDesign.Surface.elevatedCard)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 8
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.addArrangedSubview(makeStatusLabel(community.topic, color: AppDesign.Color.primaryGreen))
        topRow.addArrangedSubview(UIView())
        let meta = UILabel()
        meta.text = "\(community.members) 成员 · \(community.posts) 条分享"
        meta.font = .systemFont(ofSize: 12)
        meta.textColor = .secondaryLabel
        topRow.addArrangedSubview(meta)
        let name = UILabel()
        name.text = community.name
        name.font = .systemFont(ofSize: 17, weight: .bold)
        let description = UILabel()
        description.text = community.description
        description.font = .systemFont(ofSize: 13)
        description.textColor = .secondaryLabel
        description.numberOfLines = 0
        let buttonsRow = UIStackView()
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 8
        buttonsRow.distribution = .fillEqually
        let joinButton = joined
            ? makeSecondaryButton(title: "已加入", selector: #selector(communityLeaveTapped(_:)))
            : makePrimaryButton(title: "申请加入", selector: #selector(communityJoinTapped(_:)))
        joinButton.accessibilityValue = community.id
        joinButton.accessibilityIdentifier = "community-\(community.id)"
        let detailsButton = makeSecondaryButton(title: "社区详情", selector: #selector(communityDetailsTapped(_:)))
        detailsButton.accessibilityValue = community.id
        buttonsRow.addArrangedSubview(joinButton)
        buttonsRow.addArrangedSubview(detailsButton)
        content.addArrangedSubview(topRow)
        content.addArrangedSubview(name)
        content.addArrangedSubview(description)
        content.addArrangedSubview(buttonsRow)
        card.addContent(content)
        return card
    }

    private func makeCommunityPostsSection() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 10
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        let title = UILabel()
        title.text = "社区动态"
        title.font = .systemFont(ofSize: 20, weight: .bold)
        let createButton = UIButton(type: .system)
        createButton.setTitle("创建分享", for: .normal)
        createButton.tintColor = AppDesign.Color.darkTeal
        createButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        createButton.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        createButton.addTarget(self, action: #selector(createPostTapped), for: .touchUpInside)
        headerRow.addArrangedSubview(title)
        headerRow.addArrangedSubview(UIView())
        headerRow.addArrangedSubview(createButton)
        container.addArrangedSubview(headerRow)
        let posts = filteredPosts
        if posts.isEmpty {
            let empty = UILabel()
            empty.text = "当前筛选下暂无内容，试试切换主题或清空搜索。"
            empty.font = .systemFont(ofSize: 13)
            empty.textColor = .secondaryLabel
            empty.numberOfLines = 0
            container.addArrangedSubview(empty)
        } else {
            for post in posts {
                container.addArrangedSubview(makePostCard(post: post))
            }
        }
        return container
    }

    private func makePostCard(post: CommunityPost) -> UIView {
        let card = MedicalHubCard(backgroundColor: AppDesign.Surface.elevatedCard)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 8
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.spacing = 6
        topRow.addArrangedSubview(makeStatusLabel(post.topic, color: UIColor(red: 0.23, green: 0.55, blue: 0.85, alpha: 1)))
        if post.isNew { topRow.addArrangedSubview(makeStatusLabel("新发布", color: AppDesign.Color.primaryGreen)) }
        topRow.addArrangedSubview(UIView())
        let time = UILabel()
        time.text = post.time
        time.font = .systemFont(ofSize: 12)
        time.textColor = .tertiaryLabel
        topRow.addArrangedSubview(time)
        let title = UILabel()
        title.text = post.title
        title.font = .systemFont(ofSize: 15, weight: .bold)
        title.numberOfLines = 0
        let detail = UILabel()
        detail.text = post.detail
        detail.font = .systemFont(ofSize: 13)
        detail.textColor = .secondaryLabel
        detail.numberOfLines = 0
        let author = UILabel()
        author.text = "\(post.author) · \(post.role)"
        author.font = .systemFont(ofSize: 12)
        author.textColor = .tertiaryLabel
        let actionsRow = UIStackView()
        actionsRow.axis = .horizontal
        actionsRow.spacing = 18
        let bookmarked = bookmarkedPosts.contains(post.id)
        let bookmark = makePostAction(icon: bookmarked ? "bookmark.fill" : "bookmark", title: bookmarked ? "已收藏" : "收藏", selector: #selector(postBookmarkTapped(_:)), value: post.id)
        let reply = makePostAction(icon: "bubble.left", title: "回复", selector: #selector(postReplyTapped(_:)), value: post.title)
        let report = makePostAction(icon: "flag", title: "举报", selector: #selector(postReportTapped(_:)), value: post.title)
        let share = makePostAction(icon: "square.and.arrow.up", title: "分享", selector: #selector(postShareTapped(_:)), value: post.title)
        [bookmark, reply, report, share].forEach { actionsRow.addArrangedSubview($0) }
        actionsRow.addArrangedSubview(UIView())
        content.addArrangedSubview(topRow)
        content.addArrangedSubview(title)
        content.addArrangedSubview(detail)
        content.addArrangedSubview(author)
        content.addArrangedSubview(actionsRow)
        card.addContent(content)
        return card
    }

    private func makePostAction(icon: String, title: String, selector: Selector, value: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.setTitle(" " + title, for: .normal)
        button.tintColor = .secondaryLabel
        button.titleLabel?.font = .systemFont(ofSize: 12)
        button.accessibilityValue = value
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }

    private func makeCommunityEventCard() -> UIView {
        let card = MedicalHubCard(backgroundColor: UIColor.systemOrange.withAlphaComponent(0.12))
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 10
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.addArrangedSubview(makeStatusLabel("线上活动", color: .systemOrange))
        topRow.addArrangedSubview(UIView())
        let time = UILabel()
        time.text = "6月12日 19:30"
        time.font = .systemFont(ofSize: 12)
        time.textColor = .secondaryLabel
        topRow.addArrangedSubview(time)
        let title = UILabel()
        title.text = "治疗期间的营养支持直播"
        title.font = .systemFont(ofSize: 16, weight: .bold)
        let detail = UILabel()
        detail.text = "营养师在线答疑，可提前提交问题"
        detail.font = .systemFont(ofSize: 13)
        detail.textColor = .secondaryLabel
        let button = makeSecondaryButton(title: eventRegistered ? "已报名" : "报名参加活动", selector: #selector(eventRegisterTapped))
        content.addArrangedSubview(topRow)
        content.addArrangedSubview(title)
        content.addArrangedSubview(detail)
        content.addArrangedSubview(button)
        card.addContent(content)
        return card
    }

    // MARK: - Community actions

    @objc private func communityJoinTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityValue,
              let community = MedicalHubViewController.communities.first(where: { $0.id == id }) else { return }
        let alert = UIAlertController(
            title: "加入\(community.name)",
            message: "加入即表示你同意社区公约：尊重他人、不发布医疗广告、不索取联系方式。社区内容由成员分享，平台会进行基础审核。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        alert.addAction(UIAlertAction(title: "同意并加入", style: .default) { [weak self] _ in
            self?.joinedCommunities.insert(id)
            self?.rebuild()
            self?.showNotice("已加入\(community.name)")
        })
        present(alert, animated: true)
    }

    @objc private func communityLeaveTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityValue else { return }
        joinedCommunities.remove(id)
        rebuild()
    }

    @objc private func communityDetailsTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityValue,
              let community = MedicalHubViewController.communities.first(where: { $0.id == id }) else { return }
        let sheet = MedicalDetailSheetViewController(
            title: community.name,
            subtitle: "\(community.members) 成员 · \(community.posts) 条分享 · \(community.topic)",
            lines: [
                ("社区定位", community.description),
                ("社区公约", "尊重他人、不发布医疗广告、不索取联系方式、不公开他人病历资料"),
                ("内容审核", "成员分享会经过基础审核，违规内容将被移除"),
            ],
            notice: "社区内容由成员分享，不构成医疗建议。"
        )
        present(sheet, animated: true)
    }

    @objc private func createPostTapped() {
        let sheet = MedicalFormSheetViewController(
            title: "创建分享",
            subtitle: "分享经验前请移除姓名、联系方式和医疗编号。",
            fields: [
                .choice(id: "type", title: "分享类型", options: ["治疗经验", "康复随访", "心理生活", "问答"], selected: 0),
                .multiline(id: "content", title: "分享内容", placeholder: "描述你的经验、问题或希望获得的建议", required: true),
            ],
            submitTitle: "发布分享"
        ) { [weak self] values in
            guard let self else { return }
            self.newPosts.append(CommunityPostDraft(
                type: values["type"] as? String ?? "治疗经验",
                content: values["content"] as? String ?? ""
            ))
            self.rebuild()
            self.showNotice("分享已创建，演示环境不会公开发布")
        }
        present(sheet, animated: true)
    }

    @objc private func postBookmarkTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityValue else { return }
        if bookmarkedPosts.contains(id) { bookmarkedPosts.remove(id) } else { bookmarkedPosts.insert(id) }
        rebuild()
    }

    @objc private func postReplyTapped(_ sender: UIButton) {
        let sheet = MedicalFormSheetViewController(
            title: "回复分享",
            subtitle: sender.accessibilityValue,
            fields: [
                .multiline(id: "reply", title: "回复内容", placeholder: "写下你的回复", required: true),
            ],
            submitTitle: "发布回复"
        ) { [weak self] _ in
            self?.showNotice("回复已提交，演示环境不会公开显示")
        }
        present(sheet, animated: true)
    }

    @objc private func postReportTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "举报内容", message: "请选择举报原因，平台将在 24 小时内审核。", preferredStyle: .actionSheet)
        for reason in ["广告或营销内容", "侵犯个人隐私", "医疗误导信息", "其他违规行为"] {
            alert.addAction(UIAlertAction(title: reason, style: .default) { [weak self] _ in
                self?.showNotice("举报已提交，平台将在 24 小时内审核")
            })
        }
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        present(alert, animated: true)
    }

    @objc private func postShareTapped(_ sender: UIButton) {
        guard let title = sender.accessibilityValue else { return }
        present(UIActivityViewController(activityItems: [title], applicationActivities: nil), animated: true)
    }

    @objc private func eventRegisterTapped() {
        eventRegistered = true
        rebuild()
        showNotice("已为你预留活动席位，开始前会发送提醒")
    }
}
