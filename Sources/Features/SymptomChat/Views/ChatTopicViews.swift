import UIKit

// MARK: - Chat topic model

/// Native counterpart of Android's _ChatTopic (ai_chat_page.dart).
/// Topics reframe the consultation; routing still goes through the real AI backend.
enum ChatTopic: Int, CaseIterable {
    case healthConsult
    case reportConsult
    case nutrition
    case sleep

    var label: String {
        switch self {
        case .healthConsult: return "健康咨询"
        case .reportConsult: return "报告咨询"
        case .nutrition: return "营养顾问"
        case .sleep: return "睡眠助手"
        }
    }

    var icon: String {
        switch self {
        case .healthConsult: return "stethoscope"
        case .reportConsult: return "doc.text.viewfinder"
        case .nutrition: return "leaf"
        case .sleep: return "moon.stars"
        }
    }

    var title: String {
        switch self {
        case .healthConsult: return "健康咨询"
        case .reportConsult: return "报告咨询"
        case .nutrition: return "营养顾问"
        case .sleep: return "睡眠助手"
        }
    }

    var welcomeDescription: String {
        switch self {
        case .healthConsult: return "我会结合你的健康档案与近期监测趋势，说明可能原因和下一步检查；如出现危险信号，会优先建议线下就医。"
        case .reportConsult: return "我会按“指标含义—风险提示—复查建议”解读报告，不替代医生诊断；如数值异常，会优先说明复查与就医路径。"
        case .nutrition: return "我会结合健康档案与近期饮食记录评估营养结构，并给出可执行的一日三餐建议。"
        case .sleep: return "我会结合近期睡眠数据与生活节律，分析睡眠质量与风险，并给出可执行的改善计划。"
        }
    }

    /// Prefix attached to the outgoing API message so the backend receives topic context.
    var promptContext: String {
        switch self {
        case .healthConsult: return "【健康咨询】"
        case .reportConsult: return "【报告咨询】请按“指标含义—风险提示—复查建议”的结构回答。"
        case .nutrition: return "【营养顾问】请结合健康档案评估营养结构并给出可执行的饮食建议。"
        case .sleep: return "【睡眠助手】请结合睡眠数据与生活节律分析睡眠质量并给出改善计划。"
        }
    }

    /// Suggested starter questions: (tag, question), mirrors Android _suggestionList.
    var suggestions: [(tag: String, question: String)] {
        switch self {
        case .healthConsult:
            return [
                ("症状分析", "我最近头痛频繁，可能是什么原因？"),
                ("指标解读", "体检发现血脂偏高，应该怎么改善？"),
                ("用药咨询", "这个药可以和降压药一起吃吗？"),
                ("就医建议", "什么情况下应该去看急诊？"),
            ]
        case .reportConsult:
            return [
                ("报告解读", "这份体检报告有哪些指标需要重点关注？"),
                ("异常说明", "血脂偏高是什么意思？需要复查吗？"),
                ("趋势对比", "和上次报告相比，哪些指标变化比较大？"),
                ("复查建议", "接下来建议做哪些复查或专科检查？"),
            ]
        case .nutrition:
            return [
                ("早餐", "请给我一份适合控糖的早餐建议"),
                ("午餐", "外食时如何搭配一份更健康的午餐？"),
                ("加餐", "下午容易饿，有哪些健康加餐选择？"),
                ("晚餐", "晚上想吃得清淡些，有什么推荐？"),
            ]
        case .sleep:
            return [
                ("入睡困难", "最近入睡困难，有哪些非药物的改善方法？"),
                ("早醒", "经常早醒是压力还是睡眠节律的问题？"),
                ("午睡", "午睡多久比较合适？会影响夜间睡眠吗？"),
                ("作息", "如何调整作息才能提高深睡比例？"),
            ]
        }
    }

    /// Context tags shown on the topic welcome card (Android demo fixtures).
    /// DIRTY HACK: Android parity demo data until backed by real health metrics.
    var contextTags: [String] {
        ["血压近 7 天稳定", "睡眠 6小时30分钟", "睡眠呼吸风险：中等", "心血管复查：30天内"]
    }

    var showsUploadReportAction: Bool { self == .reportConsult }
}

// MARK: - Topic strip

/// Horizontal pill strip mirroring Android's topic selector below the chat header.
final class ChatTopicStripView: UIView {

    var onSelect: ((ChatTopic) -> Void)?
    private(set) var selectedTopic: ChatTopic = .healthConsult
    private var buttons: [ChatTopic: UIButton] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        scrollView.addSubview(row)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            row.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            row.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -16),
        ])
        for topic in ChatTopic.allCases {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: topic.icon), for: .normal)
            button.setTitle(" " + topic.label, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            button.layer.cornerRadius = 17
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            button.tag = topic.rawValue
            button.accessibilityIdentifier = "chat-topic-\(topic.rawValue)"
            button.addTarget(self, action: #selector(topicTapped(_:)), for: .touchUpInside)
            buttons[topic] = button
            row.addArrangedSubview(button)
        }
        updateSelection()
    }

    func selectTopic(_ topic: ChatTopic) {
        selectedTopic = topic
        updateSelection()
    }

    private func updateSelection() {
        for (topic, button) in buttons {
            let selected = topic == selectedTopic
            button.backgroundColor = selected ? AppDesign.Color.primaryGreen : .systemBackground
            button.tintColor = selected ? .white : .secondaryLabel
            button.layer.borderWidth = selected ? 0 : 1
            button.layer.borderColor = AppDesign.Surface.border.cgColor
        }
    }

    @objc private func topicTapped(_ sender: UIButton) {
        guard let topic = ChatTopic(rawValue: sender.tag) else { return }
        onSelect?(topic)
    }
}

// MARK: - Topic welcome view

/// Android-parity welcome card per topic: member-personalized subtitle, context
/// card with tags, upload-report action (report topic) and suggestion cards.
final class ChatTopicWelcomeView: UIView {

    var onSuggestion: ((String) -> Void)?
    var onUploadReport: (() -> Void)?

    private let topic: ChatTopic
    private let memberName: String

    init(topic: ChatTopic, memberName: String) {
        self.topic = topic
        self.memberName = memberName
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func setup() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        // Header: icon + topic label + member-personalized subtitle.
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center
        let icon = UIImageView(image: UIImage(systemName: topic.icon))
        icon.tintColor = AppDesign.Color.primaryGreen
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let label = UILabel()
        label.text = topic.label
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = AppDesign.Color.darkTeal
        headerRow.addArrangedSubview(icon)
        headerRow.addArrangedSubview(label)
        headerRow.addArrangedSubview(UIView())
        let subtitle = UILabel()
        subtitle.text = "你好，\(memberName)。我可以结合你的健康档案和最近趋势，帮你先梳理方向，再决定是否就医。"
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0
        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(subtitle)

        // Context card.
        let contextCard = UIView()
        contextCard.backgroundColor = UIColor(red: 0xE8 / 255, green: 0xF1 / 255, blue: 0xFB / 255, alpha: 1)
        contextCard.layer.cornerRadius = 14
        let contextStack = UIStackView()
        contextStack.axis = .vertical
        contextStack.spacing = 10
        contextStack.translatesAutoresizingMaskIntoConstraints = false
        contextCard.addSubview(contextStack)
        NSLayoutConstraint.activate([
            contextStack.topAnchor.constraint(equalTo: contextCard.topAnchor, constant: 14),
            contextStack.leadingAnchor.constraint(equalTo: contextCard.leadingAnchor, constant: 14),
            contextStack.trailingAnchor.constraint(equalTo: contextCard.trailingAnchor, constant: -14),
            contextStack.bottomAnchor.constraint(equalTo: contextCard.bottomAnchor, constant: -14),
        ])
        let contextTitle = UILabel()
        contextTitle.text = topic.title
        contextTitle.font = .systemFont(ofSize: 17, weight: .bold)
        let contextDescription = UILabel()
        contextDescription.text = topic.welcomeDescription
        contextDescription.font = .systemFont(ofSize: 13)
        contextDescription.textColor = .secondaryLabel
        contextDescription.numberOfLines = 0
        let tagsRow = UIStackView()
        tagsRow.axis = .horizontal
        tagsRow.spacing = 8
        for tag in topic.contextTags {
            tagsRow.addArrangedSubview(makeTag(tag))
        }
        tagsRow.addArrangedSubview(UIView())
        let tagsScroll = UIScrollView()
        tagsScroll.showsHorizontalScrollIndicator = false
        tagsRow.translatesAutoresizingMaskIntoConstraints = false
        tagsScroll.addSubview(tagsRow)
        NSLayoutConstraint.activate([
            tagsRow.topAnchor.constraint(equalTo: tagsScroll.topAnchor),
            tagsRow.leadingAnchor.constraint(equalTo: tagsScroll.leadingAnchor),
            tagsRow.trailingAnchor.constraint(equalTo: tagsScroll.trailingAnchor),
            tagsRow.bottomAnchor.constraint(equalTo: tagsScroll.bottomAnchor),
            tagsRow.heightAnchor.constraint(equalTo: tagsScroll.heightAnchor),
        ])
        contextStack.addArrangedSubview(contextTitle)
        contextStack.addArrangedSubview(contextDescription)
        contextStack.addArrangedSubview(tagsScroll)

        if topic.showsUploadReportAction {
            let uploadButton = UIButton(type: .system)
            uploadButton.setImage(UIImage(systemName: "doc.badge.plus"), for: .normal)
            uploadButton.setTitle(" 上传报告开始咨询", for: .normal)
            uploadButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            uploadButton.tintColor = AppDesign.Color.darkTeal
            uploadButton.backgroundColor = .white
            uploadButton.layer.cornerRadius = 12
            uploadButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            uploadButton.addTarget(self, action: #selector(uploadTapped), for: .touchUpInside)
            contextStack.addArrangedSubview(uploadButton)
        }
        stack.addArrangedSubview(contextCard)

        // Suggestions.
        let suggestionsHeader = UILabel()
        suggestionsHeader.text = "你可以从这些问题开始"
        suggestionsHeader.font = .systemFont(ofSize: 13, weight: .semibold)
        suggestionsHeader.textColor = .secondaryLabel
        stack.addArrangedSubview(suggestionsHeader)
        for suggestion in topic.suggestions {
            stack.addArrangedSubview(makeSuggestionCard(suggestion))
        }
    }

    private func makeTag(_ text: String) -> UIView {
        let label = PaddingLabel()
        label.text = text
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabel
        label.backgroundColor = .white
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.contentInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        return label
    }

    private func makeSuggestionCard(_ suggestion: (tag: String, question: String)) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowRadius = 6
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
        let tag = PaddingLabel()
        tag.text = suggestion.tag
        tag.font = .systemFont(ofSize: 11, weight: .medium)
        tag.textColor = AppDesign.Color.darkTeal
        tag.backgroundColor = AppDesign.Surface.highlightCard
        tag.layer.cornerRadius = 8
        tag.layer.masksToBounds = true
        tag.contentInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        tag.setContentHuggingPriority(.required, for: .horizontal)
        tag.setContentCompressionResistancePriority(.required, for: .horizontal)
        let question = UILabel()
        question.text = suggestion.question
        question.font = .systemFont(ofSize: 13)
        question.numberOfLines = 2
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(tag)
        row.addArrangedSubview(question)
        row.addArrangedSubview(chevron)
        let tap = UITapGestureRecognizer(target: self, action: #selector(suggestionTapped(_:)))
        card.addGestureRecognizer(tap)
        card.accessibilityValue = suggestion.question
        return card
    }

    @objc private func suggestionTapped(_ gesture: UITapGestureRecognizer) {
        guard let question = gesture.view?.accessibilityValue else { return }
        onSuggestion?(question)
    }

    @objc private func uploadTapped() {
        onUploadReport?()
    }
}
