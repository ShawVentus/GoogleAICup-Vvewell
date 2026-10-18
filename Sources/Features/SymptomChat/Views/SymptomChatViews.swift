import UIKit

enum SymptomChatAppearance {
    static let pageBackgroundColor = AppDesign.Surface.canvasBackground
    static let secondarySurfaceColor = AppDesign.Surface.secondaryCard
    static let welcomeCardColor = AppDesign.Surface.highlightCard
}

final class SymptomChatWelcomeHeroView: UIView {
    var onSelectPrompt: ((String) -> Void)?
    var onResumeLatest: (() -> Void)?
    var onOpenHistory: (() -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let helperLabel = UILabel()
    private let featureStack = UIStackView()
    private let starterSectionLabel = UILabel()
    private let starterRow = UIStackView()
    private var starterButtons: [UIButton] = []
    private let latestSessionCard = UIView()
    private let latestSessionTitleLabel = UILabel()
    private let latestSessionDetailLabel = UILabel()
    private let continueLatestButton = UIButton(type: .system)
    private let historyButton = UIButton(type: .system)
    private var latestSessionCollapsedConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        refreshLocalization()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshLocalization() {
        titleLabel.text = t(.symptomChatTitle)
        subtitleLabel.text = t(.symptomChatWelcome)
        starterSectionLabel.text = t(.symptomChatLandingStarterTitle)
        helperLabel.text = t(.symptomChatLandingFeatureGuidance)

        let featureTexts = [
            t(.symptomChatLandingFeatureGuidance),
            t(.symptomChatLandingFeatureUpload),
            t(.symptomChatLandingFeatureResume),
        ]
        let featureLabels = featureStack.arrangedSubviews.compactMap { $0 as? ChatPillLabel }
        for (index, label) in featureLabels.enumerated() where index < featureTexts.count {
            label.text = featureTexts[index]
        }

        let prompts = [
            t(.symptomChatLandingStarterSymptoms),
            t(.symptomChatLandingStarterTimeline),
            t(.symptomChatLandingStarterNextSteps),
        ]
        for (index, button) in starterButtons.enumerated() where index < prompts.count {
            button.setTitle(prompts[index], for: .normal)
        }
        continueLatestButton.setTitle(t(.symptomChatContinueLatest), for: .normal)
        historyButton.setTitle(t(.symptomChatHistoryButton), for: .normal)
    }

    func configureLatestSession(_ session: LocalChatSession?) {
        latestSessionCard.isHidden = session == nil
        latestSessionCollapsedConstraint?.isActive = session == nil
        guard let session else {
            latestSessionTitleLabel.text = nil
            latestSessionDetailLabel.text = nil
            return
        }

        latestSessionTitleLabel.text = t(.symptomChatContinueLatest)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        latestSessionDetailLabel.text = [session.title, formatter.string(from: Date(timeIntervalSince1970: session.updatedAt))]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func setup() {
        backgroundColor = SymptomChatAppearance.welcomeCardColor
        layer.cornerRadius = AppDesign.CornerRadius.heroCard + 2
        layer.borderWidth = 1
        layer.borderColor = AppDesign.Surface.border.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.05
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 18
        translatesAutoresizingMaskIntoConstraints = false

        let iconWrap = UIView()
        iconWrap.backgroundColor = AppDesign.Color.primaryGreen.withAlphaComponent(0.12)
        iconWrap.layer.cornerRadius = 22
        iconWrap.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "stethoscope"))
        icon.tintColor = AppDesign.Color.primaryGreen
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.addSubview(icon)

        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let helperWrap = UIView()
        helperWrap.translatesAutoresizingMaskIntoConstraints = false
        helperWrap.backgroundColor = AppDesign.Surface.secondaryCard.withAlphaComponent(0.7)
        helperWrap.layer.cornerRadius = AppDesign.Chat.sectionCornerRadius

        helperLabel.font = .systemFont(ofSize: 13, weight: .medium)
        helperLabel.textColor = .secondaryLabel
        helperLabel.numberOfLines = 0
        helperLabel.translatesAutoresizingMaskIntoConstraints = false
        helperWrap.addSubview(helperLabel)

        featureStack.axis = .vertical
        featureStack.spacing = AppDesign.Layout.compactSpacing
        featureStack.translatesAutoresizingMaskIntoConstraints = false
        [
            t(.symptomChatLandingFeatureGuidance),
            t(.symptomChatLandingFeatureUpload),
            t(.symptomChatLandingFeatureResume),
        ].forEach { text in
            let label = ChatPillLabel()
            label.text = text
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = .label
            label.numberOfLines = 0
            label.backgroundColor = AppDesign.Surface.secondaryCard
            label.layer.cornerRadius = AppDesign.CornerRadius.pill
            label.layer.masksToBounds = true
            label.insets = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
            featureStack.addArrangedSubview(label)
        }

        latestSessionCard.translatesAutoresizingMaskIntoConstraints = false
        latestSessionCard.backgroundColor = AppDesign.Surface.elevatedCard
        latestSessionCard.layer.cornerRadius = AppDesign.Chat.latestSessionCardCornerRadius
        latestSessionCard.layer.borderWidth = 1
        latestSessionCard.layer.borderColor = AppDesign.Color.primaryGreen.withAlphaComponent(0.12).cgColor
        latestSessionCard.isHidden = true

        latestSessionTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        latestSessionTitleLabel.textColor = .label
        latestSessionTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        latestSessionDetailLabel.font = .systemFont(ofSize: 12)
        latestSessionDetailLabel.textColor = .secondaryLabel
        latestSessionDetailLabel.numberOfLines = 2
        latestSessionDetailLabel.translatesAutoresizingMaskIntoConstraints = false

        configurePrimaryHeroButton(continueLatestButton)
        configureSecondaryHeroButton(historyButton)
        continueLatestButton.addTarget(self, action: #selector(resumeLatestTapped), for: .touchUpInside)
        historyButton.addTarget(self, action: #selector(openHistoryTapped), for: .touchUpInside)

        let latestActionRow = UIStackView(arrangedSubviews: [continueLatestButton, historyButton])
        latestActionRow.axis = .horizontal
        latestActionRow.spacing = AppDesign.Layout.compactSpacing
        latestActionRow.distribution = .fillEqually
        latestActionRow.translatesAutoresizingMaskIntoConstraints = false

        latestSessionCard.addSubview(latestSessionTitleLabel)
        latestSessionCard.addSubview(latestSessionDetailLabel)
        latestSessionCard.addSubview(latestActionRow)
        latestSessionCollapsedConstraint = latestSessionCard.heightAnchor.constraint(equalToConstant: 0)

        starterSectionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        starterSectionLabel.textColor = .secondaryLabel
        starterSectionLabel.translatesAutoresizingMaskIntoConstraints = false

        starterRow.axis = .vertical
        starterRow.spacing = AppDesign.Layout.compactSpacing
        starterRow.translatesAutoresizingMaskIntoConstraints = false

        let prompts = [
            t(.symptomChatLandingStarterSymptoms),
            t(.symptomChatLandingStarterTimeline),
            t(.symptomChatLandingStarterNextSteps),
        ]
        starterButtons = prompts.enumerated().map { index, prompt in
            let button = UIButton(type: .system)
            button.setTitle(prompt, for: .normal)
            button.setImage(UIImage(systemName: "sparkles"), for: .normal)
            button.backgroundColor = SymptomChatAppearance.secondarySurfaceColor
            button.tintColor = AppDesign.Color.primaryGreen
            button.setTitleColor(.label, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            button.layer.cornerRadius = 14
            button.contentHorizontalAlignment = directionalContentHorizontalAlignment()
            button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
            button.semanticContentAttribute = directionalSemanticContentAttribute(for: .leading)
            button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
            button.tag = index
            button.addTarget(self, action: #selector(starterPromptTapped(_:)), for: .touchUpInside)
            return button
        }
        starterButtons.forEach(starterRow.addArrangedSubview)

        addSubview(iconWrap)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(helperWrap)
        addSubview(featureStack)
        addSubview(latestSessionCard)
        addSubview(starterSectionLabel)
        addSubview(starterRow)

        NSLayoutConstraint.activate([
            iconWrap.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            iconWrap.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            iconWrap.widthAnchor.constraint(equalToConstant: 44),
            iconWrap.heightAnchor.constraint(equalToConstant: 44),

            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: iconWrap.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            helperWrap.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            helperWrap.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            helperWrap.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            helperLabel.topAnchor.constraint(equalTo: helperWrap.topAnchor, constant: 12),
            helperLabel.leadingAnchor.constraint(equalTo: helperWrap.leadingAnchor, constant: 12),
            helperLabel.trailingAnchor.constraint(equalTo: helperWrap.trailingAnchor, constant: -12),
            helperLabel.bottomAnchor.constraint(equalTo: helperWrap.bottomAnchor, constant: -12),

            featureStack.topAnchor.constraint(equalTo: helperWrap.bottomAnchor, constant: 14),
            featureStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            featureStack.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            latestSessionCard.topAnchor.constraint(equalTo: featureStack.bottomAnchor, constant: 14),
            latestSessionCard.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            latestSessionCard.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            latestSessionTitleLabel.topAnchor.constraint(equalTo: latestSessionCard.topAnchor, constant: 14),
            latestSessionTitleLabel.leadingAnchor.constraint(equalTo: latestSessionCard.leadingAnchor, constant: 14),
            latestSessionTitleLabel.trailingAnchor.constraint(equalTo: latestSessionCard.trailingAnchor, constant: -14),

            latestSessionDetailLabel.topAnchor.constraint(equalTo: latestSessionTitleLabel.bottomAnchor, constant: 6),
            latestSessionDetailLabel.leadingAnchor.constraint(equalTo: latestSessionTitleLabel.leadingAnchor),
            latestSessionDetailLabel.trailingAnchor.constraint(equalTo: latestSessionTitleLabel.trailingAnchor),

            latestActionRow.topAnchor.constraint(equalTo: latestSessionDetailLabel.bottomAnchor, constant: 12),
            latestActionRow.leadingAnchor.constraint(equalTo: latestSessionDetailLabel.leadingAnchor),
            latestActionRow.trailingAnchor.constraint(equalTo: latestSessionDetailLabel.trailingAnchor),
            latestActionRow.bottomAnchor.constraint(equalTo: latestSessionCard.bottomAnchor, constant: -14),
            latestActionRow.heightAnchor.constraint(equalToConstant: AppDesign.ControlSize.minimumTapTarget),

            starterSectionLabel.topAnchor.constraint(equalTo: latestSessionCard.bottomAnchor, constant: 14),
            starterSectionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            starterSectionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            starterRow.topAnchor.constraint(equalTo: starterSectionLabel.bottomAnchor, constant: 8),
            starterRow.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            starterRow.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            starterRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
        ])
    }

    private func configurePrimaryHeroButton(_ button: UIButton) {
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = AppDesign.Color.primaryGreen
        button.layer.cornerRadius = AppDesign.CornerRadius.button
        button.contentHorizontalAlignment = directionalContentHorizontalAlignment()
        button.semanticContentAttribute = directionalSemanticContentAttribute(for: .leading)
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureSecondaryHeroButton(_ button: UIButton) {
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.setTitleColor(AppDesign.Color.primaryGreen, for: .normal)
        button.backgroundColor = AppDesign.Surface.subtleTint
        button.layer.cornerRadius = AppDesign.CornerRadius.button
        button.contentHorizontalAlignment = directionalContentHorizontalAlignment()
        button.semanticContentAttribute = directionalSemanticContentAttribute(for: .leading)
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    @objc private func starterPromptTapped(_ sender: UIButton) {
        guard sender.tag >= 0, sender.tag < starterButtons.count else { return }
        guard let prompt = starterButtons[sender.tag].title(for: .normal) else { return }
        onSelectPrompt?(prompt)
    }

    @objc private func resumeLatestTapped() {
        onResumeLatest?()
    }

    @objc private func openHistoryTapped() {
        onOpenHistory?()
    }
}

final class ComposerTextView: UITextView {
    private let placeholderLabel = UILabel()
    var maxHeight: CGFloat = AppDesign.Chat.composerMaxHeight {
        didSet { invalidateIntrinsicContentSize() }
    }

    override var text: String! {
        didSet {
            updatePlaceholderVisibility()
            invalidateIntrinsicContentSize()
        }
    }

    override var font: UIFont? {
        didSet {
            placeholderLabel.font = font
        }
    }

    override var contentSize: CGSize {
        didSet {
            isScrollEnabled = contentSize.height > maxHeight
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        let targetHeight = min(max(contentSize.height, AppDesign.Chat.composerMinHeight), maxHeight)
        return CGSize(width: UIView.noIntrinsicMetric, height: targetHeight)
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        backgroundColor = .clear
        isScrollEnabled = false
        self.textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        self.textContainer.lineFragmentPadding = 0
        showsVerticalScrollIndicator = false
        keyboardDismissMode = .interactive

        placeholderLabel.font = .systemFont(ofSize: 16)
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: textContainerInset.top),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setPlaceholder(_ text: String) {
        placeholderLabel.text = text
        updatePlaceholderVisibility()
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !(text?.isEmpty ?? true)
    }
}

final class ComposerAttachmentChipView: UIView {
    var onRemove: ((UUID) -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let removeButton = UIButton(type: .system)
    private var attachmentID: UUID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = AppDesign.Surface.secondaryCard
        layer.cornerRadius = AppDesign.CornerRadius.pill
        layer.borderWidth = 1
        layer.borderColor = AppDesign.Surface.border.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        iconView.tintColor = AppDesign.Color.primaryGreen
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 2
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        removeButton.tintColor = .secondaryLabel
        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(removeButton)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            removeButton.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            removeButton.widthAnchor.constraint(equalToConstant: 20),
            removeButton.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -8),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with state: PendingAttachmentState) {
        attachmentID = state.id
        iconView.image = UIImage(systemName: state.kind.symbolName)
        titleLabel.text = state.displayName
        detailLabel.text = state.message
        detailLabel.textColor = {
            if case .failed = state { return .systemRed }
            return .secondaryLabel
        }()
    }

    @objc private func removeTapped() {
        guard let attachmentID else { return }
        onRemove?(attachmentID)
    }
}

final class MessageBubbleView: UIView, UITextViewDelegate {
    private let role: BubbleRole
    private let bubble = UIView()
    private let contentStack = UIStackView()
    private let statusStack = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let statusLabel = UILabel()
    private let textView = UITextView()
    private let attachmentStack = UIStackView()
    private let dynamicStack = UIStackView()

    private var latestMeta: AssistantStreamMeta?
    private var citations: [AssistantCitation] = []
    private var rawText = ""
    private var allowCitationDisclosure = true
    private var onSubmitChoiceAnswers: ((String, String) -> Void)?
    private var onConfirm: (() -> Void)?
    private var onModify: (() -> Void)?
    private var onOpenCitation: ((String) -> Void)?

    init(role: BubbleRole) {
        self.role = role
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var displayedText: String {
        textView.text ?? ""
    }

    func setAttachmentTitles(_ titles: [String]) {
        attachmentStack.removeAllArrangedSubviews()
        guard !titles.isEmpty else {
            attachmentStack.isHidden = true
            return
        }

        attachmentStack.isHidden = false
        for title in titles {
            let label = ChatPillLabel()
            label.text = "📎 \(title)"
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = role == .user ? .white : .label
            label.backgroundColor = role == .user
                ? UIColor.white.withAlphaComponent(0.12)
                : UIColor.secondarySystemBackground
            label.layer.cornerRadius = 12
            label.layer.masksToBounds = true
            label.insets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
            attachmentStack.addArrangedSubview(label)
        }
    }

    func resetForStreaming(placeholder: String) {
        latestMeta = nil
        citations = []
        rawText = ""
        allowCitationDisclosure = false
        dynamicStack.removeAllArrangedSubviews()
        dynamicStack.isHidden = true
        statusStack.isHidden = false
        spinner.startAnimating()
        statusLabel.text = placeholder
        textView.attributedText = ChatMarkdownRenderer.render("", textColor: role == .user ? .white : .label)
    }

    func applyMeta(
        _ meta: AssistantStreamMeta,
        confirmTitle: String,
        modifyTitle: String,
        doctorsTitle: String,
        citationsTitle: String,
        onSubmitChoiceAnswers: @escaping (String, String) -> Void,
        onConfirm: @escaping () -> Void,
        onModify: @escaping () -> Void,
        onOpenCitation: @escaping (String) -> Void
    ) {
        self.latestMeta = meta
        if let metaCitations = meta.citations, !metaCitations.isEmpty {
            citations = metaCitations
        }
        self.onSubmitChoiceAnswers = onSubmitChoiceAnswers
        self.onConfirm = onConfirm
        self.onModify = onModify
        self.onOpenCitation = onOpenCitation
        if let cleanReply = meta.cleanReply?.trimmedForChat, !cleanReply.isEmpty {
            completeText(cleanReply)
        }
        refreshDynamicSections(confirmTitle: confirmTitle, modifyTitle: modifyTitle, doctorsTitle: doctorsTitle, citationsTitle: citationsTitle)
    }

    func applyCitations(_ citations: [AssistantCitation], title: String, onOpen: @escaping (String) -> Void) {
        self.citations = citations
        self.onOpenCitation = onOpen
        if !rawText.trimmedForChat.isEmpty {
            renderCurrentText()
        }
        refreshDynamicSections(
            confirmTitle: t(.confirm),
            modifyTitle: t(.symptomChatModify),
            doctorsTitle: t(.symptomChatDoctorsTitle),
            citationsTitle: title
        )
    }

    func revealDeferredCitations() {
        allowCitationDisclosure = true
        refreshLocalizedContent()
    }

    func completeText(_ text: String) {
        rawText = text
        statusStack.isHidden = true
        spinner.stopAnimating()
        renderCurrentText()
    }

    func setPlainText(_ text: String) {
        rawText = text
        allowCitationDisclosure = true
        statusStack.isHidden = true
        spinner.stopAnimating()
        renderCurrentText()
        dynamicStack.removeAllArrangedSubviews()
        dynamicStack.isHidden = true
    }

    func refreshLocalizedContent() {
        if !rawText.isEmpty {
            renderCurrentText()
        }
        refreshDynamicSections(
            confirmTitle: t(.confirm),
            modifyTitle: t(.symptomChatModify),
            doctorsTitle: t(.symptomChatDoctorsTitle),
            citationsTitle: t(.symptomChatCitationsTitle)
        )
    }

    private func refreshDynamicSections(confirmTitle: String, modifyTitle: String, doctorsTitle: String, citationsTitle: String) {
        dynamicStack.removeAllArrangedSubviews()
        guard role == .assistant else { return }

        if let choices = latestMeta?.choices, !choices.isEmpty {
            let choiceView = ChoiceQuestionnaireView(choices: choices)
            choiceView.onSubmitAnswers = onSubmitChoiceAnswers
            choiceView.refreshLocalization()
            dynamicStack.addArrangedSubview(choiceView)
        }

        if let confirmText = latestMeta?.confirm, !confirmText.trimmedForChat.isEmpty {
            let confirmView = ConfirmActionView(text: confirmText, confirmTitle: confirmTitle, modifyTitle: modifyTitle)
            confirmView.onConfirm = onConfirm
            confirmView.onModify = onModify
            dynamicStack.addArrangedSubview(confirmView)
        }

        if let doctors = latestMeta?.doctors {
            if doctors.isEmpty {
                let emptyLabel = UILabel()
                emptyLabel.font = .systemFont(ofSize: 12, weight: .medium)
                emptyLabel.textColor = .secondaryLabel
                emptyLabel.numberOfLines = 0
                emptyLabel.text = t(.symptomChatDoctorsEmptyHint)
                dynamicStack.addArrangedSubview(emptyLabel)
            } else {
                let summaryLabel = UILabel()
                summaryLabel.font = .systemFont(ofSize: 12, weight: .medium)
                summaryLabel.textColor = .secondaryLabel
                summaryLabel.numberOfLines = 0
                summaryLabel.text = String(format: t(.symptomChatDoctorsFoundFormat), doctors.count)
                dynamicStack.addArrangedSubview(summaryLabel)

                let views = doctors.map(DoctorCardView.init)
                dynamicStack.addArrangedSubview(
                    DisclosureSectionView(
                        title: "\(doctorsTitle) (\(doctors.count))",
                        arrangedSubviews: views,
                        initiallyExpanded: true
                    )
                )
            }
        }

        if allowCitationDisclosure, !citations.isEmpty {
            dynamicStack.addArrangedSubview(
                CitationInlineListView(
                    title: citationsTitle,
                    citations: citations,
                    onOpen: onOpenCitation ?? { _ in }
                )
            )
        }

        dynamicStack.isHidden = dynamicStack.arrangedSubviews.isEmpty
    }

    private func renderCurrentText() {
        textView.attributedText = ChatMarkdownRenderer.render(
            rawText,
            textColor: role == .user ? .white : .label,
            citations: citations
        )
    }

    private func setup() {
        bubble.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        attachmentStack.translatesAutoresizingMaskIntoConstraints = false
        dynamicStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(bubble)
        bubble.addSubview(contentStack)

        bubble.backgroundColor = role == .user ? AppDesign.Color.primaryGreen : AppDesign.Surface.elevatedCard
        bubble.layer.cornerRadius = AppDesign.Chat.sectionCornerRadius + 2
        bubble.layer.maskedCorners = role == .user
            ? [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner]
            : [.layerMaxXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner]

        if role == .assistant {
            bubble.layer.shadowColor = UIColor.black.cgColor
            bubble.layer.shadowOpacity = 0.04
            bubble.layer.shadowOffset = CGSize(width: 0, height: 1)
            bubble.layer.shadowRadius = 8
        }

        contentStack.axis = .vertical
        contentStack.spacing = 10

        statusStack.axis = .horizontal
        statusStack.spacing = 8
        statusStack.alignment = .center
        statusStack.isHidden = true

        spinner.color = role == .user ? .white : AppDesign.Color.primaryGreen
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = role == .user ? .white : .secondaryLabel

        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        textView.linkTextAttributes = [
            .foregroundColor: role == .user ? UIColor.white : AppDesign.Color.primaryGreen,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]

        attachmentStack.axis = .vertical
        attachmentStack.spacing = 6
        attachmentStack.isHidden = true

        dynamicStack.axis = .vertical
        dynamicStack.spacing = 10
        dynamicStack.isHidden = true

        statusStack.addArrangedSubview(spinner)
        statusStack.addArrangedSubview(statusLabel)

        contentStack.addArrangedSubview(statusStack)
        contentStack.addArrangedSubview(textView)
        contentStack.addArrangedSubview(attachmentStack)
        contentStack.addArrangedSubview(dynamicStack)

        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: topAnchor),
            bubble.leadingAnchor.constraint(equalTo: leadingAnchor),
            bubble.trailingAnchor.constraint(equalTo: trailingAnchor),
            bubble.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -12),
        ])
    }

    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        guard url.scheme == "cite" else { return true }
        let indexString = url.host ?? url.absoluteString.replacingOccurrences(of: "cite://", with: "")
        guard let index = Int(indexString), index > 0, index <= citations.count else {
            return false
        }
        guard let citationURL = citations[index - 1].url, !citationURL.trimmedForChat.isEmpty else {
            return false
        }
        onOpenCitation?(citationURL)
        return false
    }
}

private final class ConfirmActionView: UIView {
    var onConfirm: (() -> Void)?
    var onModify: (() -> Void)?

    private let textLabel = UILabel()
    private let confirmButton = UIButton(type: .system)
    private let modifyButton = UIButton(type: .system)

    init(text: String, confirmTitle: String, modifyTitle: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = AppDesign.Surface.secondaryCard
        layer.cornerRadius = AppDesign.Chat.sectionCornerRadius
        layer.borderWidth = 1
        layer.borderColor = AppDesign.Color.primaryGreen.withAlphaComponent(0.12).cgColor

        textLabel.text = text
        textLabel.font = .systemFont(ofSize: 14, weight: .medium)
        textLabel.textColor = .label
        textLabel.numberOfLines = 0
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        configure(button: confirmButton, title: confirmTitle, fill: true)
        configure(button: modifyButton, title: modifyTitle, fill: false)

        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        modifyButton.addTarget(self, action: #selector(modifyTapped), for: .touchUpInside)

        let buttonRow = UIStackView(arrangedSubviews: [confirmButton, modifyButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 8
        buttonRow.distribution = .fillEqually
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textLabel)
        addSubview(buttonRow)

        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            buttonRow.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 10),
            buttonRow.leadingAnchor.constraint(equalTo: textLabel.leadingAnchor),
            buttonRow.trailingAnchor.constraint(equalTo: textLabel.trailingAnchor),
            buttonRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            buttonRow.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func confirmTapped() {
        confirmButton.isEnabled = false
        onConfirm?()
    }

    @objc private func modifyTapped() {
        modifyButton.isEnabled = false
        onModify?()
    }

    private func configure(button: UIButton, title: String, fill: Bool) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.layer.cornerRadius = AppDesign.CornerRadius.button
        button.clipsToBounds = true
        if fill {
            button.backgroundColor = AppDesign.Color.primaryGreen
            button.setTitleColor(.white, for: .normal)
        } else {
            button.backgroundColor = AppDesign.Surface.elevatedCard
            button.setTitleColor(AppDesign.Color.primaryGreen, for: .normal)
            button.layer.borderWidth = 1
            button.layer.borderColor = AppDesign.Color.primaryGreen.withAlphaComponent(0.3).cgColor
        }
    }
}

private final class ChoiceQuestionnaireView: UIView {
    var onSubmitAnswers: ((String, String) -> Void)?

    private let choices: [AssistantChoice]
    private var currentIndex = 0
    private var answers: [Int: String] = [:]

    private let progressLabel = UILabel()
    private let questionLabel = UILabel()
    private let optionsStack = UIStackView()
    private let customInputField = UITextField()
    private let skipButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)

    init(choices: [AssistantChoice]) {
        self.choices = choices
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = AppDesign.Surface.secondaryCard
        layer.cornerRadius = AppDesign.Chat.sectionCornerRadius
        layer.borderWidth = 1
        layer.borderColor = AppDesign.Surface.border.cgColor
        setup()
        renderCurrentQuestion()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshLocalization() {
        customInputField.placeholder = t(.symptomChatChoiceCustomPlaceholder)
        customInputField.accessibilityLabel = t(.symptomChatChoiceCustomPlaceholder)
        skipButton.setTitle(t(.symptomChatSkip), for: .normal)
        renderCurrentQuestion()
    }

    private func setup() {
        progressLabel.font = .systemFont(ofSize: 12, weight: .medium)
        progressLabel.textColor = .secondaryLabel
        progressLabel.translatesAutoresizingMaskIntoConstraints = false

        questionLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        questionLabel.textColor = .label
        questionLabel.numberOfLines = 0
        questionLabel.translatesAutoresizingMaskIntoConstraints = false

        optionsStack.axis = .vertical
        optionsStack.spacing = 8
        optionsStack.translatesAutoresizingMaskIntoConstraints = false

        customInputField.borderStyle = .roundedRect
        customInputField.placeholder = t(.symptomChatChoiceCustomPlaceholder)
        customInputField.clearButtonMode = .whileEditing
        customInputField.addTarget(self, action: #selector(customInputChanged), for: .editingChanged)
        customInputField.translatesAutoresizingMaskIntoConstraints = false
        customInputField.accessibilityLabel = t(.symptomChatChoiceCustomPlaceholder)

        skipButton.setTitle(t(.symptomChatSkip), for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false

        nextButton.setTitle(t(.next), for: .normal)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false

        let footer = UIStackView(arrangedSubviews: [skipButton, nextButton])
        footer.axis = .horizontal
        footer.spacing = 8
        footer.distribution = .fillEqually
        footer.translatesAutoresizingMaskIntoConstraints = false

        addSubview(progressLabel)
        addSubview(questionLabel)
        addSubview(optionsStack)
        addSubview(customInputField)
        addSubview(footer)

        NSLayoutConstraint.activate([
            progressLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            progressLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            progressLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            questionLabel.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 6),
            questionLabel.leadingAnchor.constraint(equalTo: progressLabel.leadingAnchor),
            questionLabel.trailingAnchor.constraint(equalTo: progressLabel.trailingAnchor),

            optionsStack.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 12),
            optionsStack.leadingAnchor.constraint(equalTo: questionLabel.leadingAnchor),
            optionsStack.trailingAnchor.constraint(equalTo: questionLabel.trailingAnchor),

            customInputField.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 10),
            customInputField.leadingAnchor.constraint(equalTo: optionsStack.leadingAnchor),
            customInputField.trailingAnchor.constraint(equalTo: optionsStack.trailingAnchor),
            customInputField.heightAnchor.constraint(equalToConstant: 40),

            footer.topAnchor.constraint(equalTo: customInputField.bottomAnchor, constant: 12),
            footer.leadingAnchor.constraint(equalTo: optionsStack.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: optionsStack.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            footer.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func renderCurrentQuestion() {
        guard currentIndex < choices.count else { return }
        let choice = choices[currentIndex]
        progressLabel.text = "\(currentIndex + 1)/\(choices.count)"
        questionLabel.text = choice.question
        nextButton.setTitle(currentIndex == choices.count - 1 ? t(.done) : t(.next), for: .normal)
        optionsStack.removeAllArrangedSubviews()

        for option in choice.options {
            let button = ClosureButton(frame: .zero)
            button.setTitle(option, for: .normal)
            button.contentHorizontalAlignment = directionalContentHorizontalAlignment()
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            button.backgroundColor = AppDesign.Color.primaryGreen.withAlphaComponent(0.08)
            button.layer.cornerRadius = 10
            button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
            button.onTap = { [weak self] in
                self?.answers[self?.currentIndex ?? 0] = option
                self?.customInputField.text = nil
                self?.highlightSelectedOption(option)
            }
            optionsStack.addArrangedSubview(button)
        }

        let currentAnswer = answers[currentIndex]
        let isCustomAnswer = currentAnswer.map { !choice.options.contains($0) } ?? false
        customInputField.text = isCustomAnswer ? currentAnswer : nil
        highlightSelectedOption(isCustomAnswer ? nil : currentAnswer)
    }

    private func highlightSelectedOption(_ selected: String?) {
        for case let button as UIButton in optionsStack.arrangedSubviews {
            let isSelected = button.currentTitle == selected
            button.backgroundColor = isSelected
                ? AppDesign.Color.primaryGreen.withAlphaComponent(0.16)
                : AppDesign.Color.primaryGreen.withAlphaComponent(0.08)
        }
    }

    @objc private func skipTapped() {
        answers[currentIndex] = nil
        customInputField.text = nil
        advance()
    }

    @objc private func nextTapped() {
        advance()
    }

    @objc private func customInputChanged() {
        let trimmed = customInputField.text?.trimmedForChat ?? ""
        if trimmed.isEmpty {
            if let existing = answers[currentIndex], !choices[currentIndex].options.contains(existing) {
                answers[currentIndex] = nil
            }
        } else {
            answers[currentIndex] = trimmed
        }
        highlightSelectedOption(nil)
    }

    private func advance() {
        if currentIndex == choices.count - 1 {
            submitAnswers()
        } else {
            currentIndex += 1
            renderCurrentQuestion()
        }
    }

    private func submitAnswers() {
        let answeredPairs = choices.enumerated().compactMap { index, choice -> String? in
            guard let answer = answers[index], !answer.isEmpty else { return nil }
            return String(format: t(.symptomChatChoiceAnswerFormat), choice.question, answer)
        }

        let visible: String
        let api: String

        if answeredPairs.isEmpty {
            visible = t(.symptomChatChoiceFallback)
            api = t(.symptomChatChoiceFallback)
        } else {
            visible = answeredPairs.joined(separator: "\n")
            api = visible
        }

        onSubmitAnswers?(visible, api)
    }
}

private final class DisclosureSectionView: UIView {
    private let title: String
    private let toggleButton = UIButton(type: .system)
    private let contentStack = UIStackView()
    private var expanded: Bool

    init(title: String, arrangedSubviews: [UIView], initiallyExpanded: Bool = false) {
        self.title = title
        self.expanded = initiallyExpanded
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        toggleButton.contentHorizontalAlignment = directionalContentHorizontalAlignment()
        toggleButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        toggleButton.addTarget(self, action: #selector(toggleExpanded), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        toggleButton.backgroundColor = AppDesign.Surface.subtleTint
        toggleButton.layer.cornerRadius = AppDesign.CornerRadius.button
        toggleButton.setTitleColor(.label, for: .normal)
        toggleButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.isHidden = !expanded
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        arrangedSubviews.forEach { contentStack.addArrangedSubview($0) }

        let stack = UIStackView(arrangedSubviews: [toggleButton, contentStack])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = AppDesign.Surface.secondaryCard
        layer.cornerRadius = AppDesign.Chat.sectionCornerRadius
        layer.borderWidth = 1
        layer.borderColor = AppDesign.Surface.border.cgColor
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])

        updateTitle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleExpanded() {
        expanded.toggle()
        contentStack.isHidden = !expanded
        updateTitle()
    }

    private func updateTitle() {
        toggleButton.setTitle("\(title) \(expanded ? "▴" : "▾")", for: .normal)
    }
}

private final class DoctorCardView: UIView {
    init(doctor: AssistantDoctor) {
        super.init(frame: .zero)
        backgroundColor = AppDesign.Surface.elevatedCard
        layer.cornerRadius = AppDesign.CornerRadius.card
        layer.borderWidth = 1
        layer.borderColor = AppDesign.Surface.border.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 0
        nameLabel.text = [doctor.name, doctor.title].compactMap { $0?.trimmedForChat.isEmpty == false ? $0 : nil }.joined(separator: " · ")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let detailLabel = UILabel()
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        detailLabel.text = [doctor.departmentName, doctor.hospitalName].compactMap { $0?.trimmedForChat.isEmpty == false ? $0 : nil }.joined(separator: " · ")
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(nameLabel)
        addSubview(detailLabel)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            detailLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class CitationCardView: UIView {
    init(citation: AssistantCitation, onOpen: @escaping (String) -> Void) {
        super.init(frame: .zero)
        backgroundColor = AppDesign.Surface.elevatedCard
        layer.cornerRadius = AppDesign.CornerRadius.card
        layer.borderWidth = 1
        layer.borderColor = AppDesign.Surface.border.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.text = citation.title?.trimmedForChat.isEmpty == false ? citation.title : citation.url
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let snippetLabel = UILabel()
        snippetLabel.font = .systemFont(ofSize: 12)
        snippetLabel.textColor = .secondaryLabel
        snippetLabel.numberOfLines = 0
        snippetLabel.text = citation.snippet?.trimmedForChat.isEmpty == false ? citation.snippet : citation.url
        snippetLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(snippetLabel)

        var bottomAnchorTarget = snippetLabel.bottomAnchor
        if let url = citation.url, !url.trimmedForChat.isEmpty {
            let openButton = ClosureButton(frame: .zero)
            openButton.setTitle(url, for: .normal)
            openButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
            openButton.contentHorizontalAlignment = directionalContentHorizontalAlignment()
            openButton.onTap = { onOpen(url) }
            openButton.translatesAutoresizingMaskIntoConstraints = false
            addSubview(openButton)

            NSLayoutConstraint.activate([
                openButton.topAnchor.constraint(equalTo: snippetLabel.bottomAnchor, constant: 8),
                openButton.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                openButton.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            ])
            bottomAnchorTarget = openButton.bottomAnchor
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            snippetLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            snippetLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            snippetLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            bottomAnchorTarget.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class CitationInlineListView: UIView {
    init(title: String, citations: [AssistantCitation], onOpen: @escaping (String) -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = AppDesign.Surface.secondaryCard
        layer.cornerRadius = AppDesign.Chat.sectionCornerRadius
        layer.borderWidth = 1
        layer.borderColor = AppDesign.Surface.border.cgColor

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.text = title
        stack.addArrangedSubview(titleLabel)

        for (index, citation) in citations.enumerated() {
            let row = UIStackView()
            row.axis = .vertical
            row.spacing = 4

            let button = ClosureButton(frame: .zero)
            let buttonTitle = "[\(index + 1)] \(displayTitle(for: citation, index: index))"
            button.setTitle(buttonTitle, for: .normal)
            button.setTitleColor(AppDesign.Color.primaryGreen, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
            button.contentHorizontalAlignment = directionalContentHorizontalAlignment()
            if let url = citation.url, !url.trimmedForChat.isEmpty {
                button.onTap = { onOpen(url) }
            } else {
                button.isEnabled = false
            }
            row.addArrangedSubview(button)

            let summary = UILabel()
            summary.font = .systemFont(ofSize: 11)
            summary.textColor = .tertiaryLabel
            summary.numberOfLines = 2
            summary.text = summaryText(for: citation)
            if !(summary.text?.trimmedForChat.isEmpty ?? true) {
                row.addArrangedSubview(summary)
            }

            stack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func displayTitle(for citation: AssistantCitation, index: Int) -> String {
        if let title = citation.title?.trimmedForChat, !title.isEmpty {
            return truncate(title, limit: 42)
        }
        if let url = citation.url, let host = URL(string: url)?.host, !host.isEmpty {
            return host
        }
        return String(format: t(.symptomChatCitationFallbackFormat), index + 1)
    }

    private func summaryText(for citation: AssistantCitation) -> String {
        let source = citation.snippet?.trimmedForChat ?? ""
        return truncate(source, limit: 96)
    }

    private func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }
}

private final class ChatPillLabel: UILabel {
    var insets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}

private final class ClosureButton: UIButton {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        onTap?()
    }
}

private enum ChatMarkdownRenderer {
    static func render(_ text: String, textColor: UIColor, citations: [AssistantCitation] = []) -> NSAttributedString {
        let normalized = preprocessFootnotes(in: text.replacingOccurrences(of: "\r\n", with: "\n"), citations: citations)
        let lines = normalized.components(separatedBy: "\n")
        let result = NSMutableAttributedString()

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let font: UIFont
            let content: String
            if trimmed.hasPrefix("### ") {
                font = .systemFont(ofSize: 17, weight: .bold)
                content = String(trimmed.dropFirst(4))
            } else if trimmed.hasPrefix("## ") {
                font = .systemFont(ofSize: 18, weight: .bold)
                content = String(trimmed.dropFirst(3))
            } else if trimmed.hasPrefix("# ") {
                font = .systemFont(ofSize: 20, weight: .bold)
                content = String(trimmed.dropFirst(2))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                font = .systemFont(ofSize: 16)
                content = "• " + String(trimmed.dropFirst(2))
            } else {
                font = .systemFont(ofSize: 16)
                content = line
            }

            result.append(inline(content, font: font, textColor: textColor, accentColor: AppDesign.Color.primaryGreen))
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }

    private static func inline(_ text: String, font: UIFont, textColor: UIColor, accentColor: UIColor) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let nsText = text as NSString
        let pattern = "(\\*\\*([^*]+)\\*\\*)|(`([^`]+)`)|(\\[([^\\]]+)\\]\\(([^)]+)\\))"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: textColor])
        }

        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            if match.range.location > cursor {
                output.append(NSAttributedString(
                    string: nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor)),
                    attributes: [.font: font, .foregroundColor: textColor]
                ))
            }

            if match.range(at: 2).location != NSNotFound {
                output.append(NSAttributedString(
                    string: nsText.substring(with: match.range(at: 2)),
                    attributes: [.font: UIFont.systemFont(ofSize: font.pointSize, weight: .semibold), .foregroundColor: textColor]
                ))
            } else if match.range(at: 4).location != NSNotFound {
                output.append(NSAttributedString(
                    string: nsText.substring(with: match.range(at: 4)),
                    attributes: [
                        .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular),
                        .foregroundColor: textColor,
                        .backgroundColor: UIColor.secondarySystemBackground
                    ]
                ))
            } else if match.range(at: 6).location != NSNotFound, match.range(at: 7).location != NSNotFound {
                let title = nsText.substring(with: match.range(at: 6))
                let url = nsText.substring(with: match.range(at: 7))
                let isCitationLink = url.hasPrefix("cite://")
                output.append(NSAttributedString(
                    string: title,
                    attributes: [
                        .font: isCitationLink ? UIFont.systemFont(ofSize: max(font.pointSize - 4, 11), weight: .semibold) : font,
                        .foregroundColor: accentColor,
                        .underlineStyle: isCitationLink ? 0 : NSUnderlineStyle.single.rawValue,
                        .baselineOffset: isCitationLink ? 5 : 0,
                        .link: url
                    ]
                ))
            }

            cursor = match.range.location + match.range.length
        }

        if cursor < nsText.length {
            output.append(NSAttributedString(
                string: nsText.substring(from: cursor),
                attributes: [.font: font, .foregroundColor: textColor]
            ))
        }

        return output
    }

    private static func preprocessFootnotes(in text: String, citations: [AssistantCitation]) -> String {
        guard !citations.isEmpty,
              let regex = try? NSRegularExpression(pattern: "\\^\\[(\\d+)\\]\\^")
        else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }

        var result = text
        for match in matches.reversed() {
            let token = nsText.substring(with: match.range(at: 1))
            guard let index = Int(token), index > 0, index <= citations.count else { continue }
            let replacement = "[\(token)](cite://\(token))"
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: replacement)
            }
        }
        return result
    }
}

extension UIStackView {
    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach {
            removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }
}

extension String {
    var trimmedForChat: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SymptomChatPresentationState {
    let isRelayEnabled: Bool
    let isRelayLoggedIn: Bool
    let hasConversationHistory: Bool
    let hasInitialMessage: Bool
    let coordinatorState: SymptomChatSessionCoordinator.State
    let isSending: Bool
    let hasActiveStream: Bool
    let hasPendingSubmission: Bool

    var shouldAutoRestoreConversationAfterAuthChange: Bool {
        isRelayEnabled
            && isRelayLoggedIn
            && !hasConversationHistory
            && !hasInitialMessage
            && coordinatorState == .draftOnly
            && !isSending
            && !hasActiveStream
            && !hasPendingSubmission
    }

    var shouldShowWelcomeHero: Bool {
        !isSending && !hasActiveStream && !hasPendingSubmission && !hasConversationHistory
    }

    var isHistoryButtonEnabled: Bool {
        !isSending && coordinatorState != .streamingFirstReply
    }
}
