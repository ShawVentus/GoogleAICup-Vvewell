import UIKit

enum PendingAttachmentKind: String {
    case image
    case pdf

    var mimeType: String {
        switch self {
        case .image:
            return "image/jpeg"
        case .pdf:
            return "application/pdf"
        }
    }

    var symbolName: String {
        switch self {
        case .image:
            return "photo.fill"
        case .pdf:
            return "doc.richtext.fill"
        }
    }
}

struct PreparedAttachment {
    let kind: PendingAttachmentKind
    let displayName: String
    let summary: String
    let payload: AssistantAttachmentPayload
}

enum PendingAttachmentState {
    case processing(id: UUID, kind: PendingAttachmentKind, name: String)
    case ready(id: UUID, attachment: PreparedAttachment)
    case failed(id: UUID, kind: PendingAttachmentKind, name: String, message: String)

    var id: UUID {
        switch self {
        case .processing(let id, _, _), .ready(let id, _), .failed(let id, _, _, _):
            return id
        }
    }

    var kind: PendingAttachmentKind {
        switch self {
        case .processing(_, let kind, _), .failed(_, let kind, _, _):
            return kind
        case .ready(_, let attachment):
            return attachment.kind
        }
    }

    var displayName: String {
        switch self {
        case .processing(_, _, let name), .failed(_, _, let name, _):
            return name
        case .ready(_, let attachment):
            return attachment.displayName
        }
    }

    var preparedAttachment: PreparedAttachment? {
        if case .ready(_, let attachment) = self {
            return attachment
        }
        return nil
    }

    var isProcessing: Bool {
        if case .processing = self {
            return true
        }
        return false
    }

    var message: String {
        switch self {
        case .processing:
            return t(.symptomChatAttachmentProcessing)
        case .ready(_, let attachment):
            return attachment.summary
        case .failed(_, _, _, let message):
            return message
        }
    }
}

private struct OutgoingMessage {
    let visibleMessage: String
    let apiMessage: String
    let historyMessage: String
    let historySnapshot: [AssistantChatMessage]
    let attachments: [AssistantAttachmentPayload]
    let attachmentTitles: [String]
}

enum BubbleRole {
    case user
    case assistant
}

/// AI 症状咨询与对话页面
final class SymptomChatViewController: UIViewController, UITextViewDelegate, KeyboardBehaviorCustomizable, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate, UIScrollViewDelegate {

    var keyboardAdjustmentType: KeyboardAdjustmentType { .none }

    // MARK: - State

    private let initialMessage: String?
    let remoteService: SymptomChatRemoteServing
    private var hasHandledInitialMessage = false
    private var conversationHistory: [AssistantChatMessage] = []
    private var activeStream: AssistantStreamSession?
    private var pendingHistorySnapshot: [AssistantChatMessage] = []
    private var lastSubmittedMessage: OutgoingMessage?
    var pendingAttachments: [PendingAttachmentState] = [] {
        didSet { refreshAttachmentPreviewStack() }
    }
    private var currentAssistantBubble: MessageBubbleView?
    private var latestStreamMeta: AssistantStreamMeta?
    private var streamedTokenBuffer = ""
    private var currentCitations: [AssistantCitation] = []
    private var streamDidFail = false
    private var isSending = false
    private var isCancellingStream = false
    private var isFollowingLatestContent = true
    private var currentRemoteSessionID: String?
    private var remoteHistoryBaselineSignature: String?
    private var remoteHistorySavingSignature: String?
    private var remoteHistorySaveGeneration = 0
    private var welcomeHeroView: UIView?
    /// Android parity: topic selector (健康咨询/报告咨询/营养顾问/睡眠助手) shown
    /// when this controller is the root of the chat tab. Routing still uses the
    /// real AI backend; the topic only reframes welcome content and prompt context.
    var topicSelectorEnabled = false
    private var currentTopic: ChatTopic = .healthConsult
    private var topicStripView: ChatTopicStripView?
    private var scrollViewTopConstraint: NSLayoutConstraint?
    private var latestResumeSession: LocalChatSession?
    private var externalDraftMessage: String?
    var attachmentTask: Task<Void, Never>?
    private let sessionCoordinator: SymptomChatSessionCoordinator
    private var currentLocalMessages: [LocalChatMessage] = []
    private var activeLocalSessionId: String?
    private var renderedAssistantBubbles: [String: MessageBubbleView] = [:]
    private var renderedActionBars: [String: AssistantMessageActionBarView] = [:]
    private var regeneratingMessageId: String?

    // MARK: - UI

    private weak var retryButton: UIButton?
    private var composerBottomConstraint: NSLayoutConstraint?
    private let sendButtonSymbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
    private lazy var newChatButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "square.and.pencil", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)),
            style: .plain,
            target: self,
            action: #selector(startNewConversationTapped)
        )
        item.accessibilityLabel = t(.symptomChatStartNew)
        return item
    }()
    private lazy var historyButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "clock.arrow.circlepath", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)),
            style: .plain,
            target: self,
            action: #selector(historyTapped)
        )
        item.accessibilityLabel = t(.symptomChatHistoryButton)
        return item
    }()

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.backgroundColor = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.05, green: 0.07, blue: 0.08, alpha: 1.0)
            }
            return .systemGroupedBackground
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alwaysBounceVertical = true
        return view
    }()

    private let messageStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let composerBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.08, green: 0.10, blue: 0.11, alpha: 1.0)
            }
            return .systemBackground
        }
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.05
        view.layer.shadowOffset = CGSize(width: 0, height: -2)
        view.layer.shadowRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let composerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = AppDesign.Layout.compactSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let composerHelperLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let attachmentPreviewStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = AppDesign.Layout.compactSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true
        return stack
    }()

    private let inputContainer: UIView = {
        let view = UIView()
        view.backgroundColor = AppDesign.Surface.secondaryCard
        view.layer.cornerRadius = AppDesign.CornerRadius.composer
        view.layer.borderWidth = 1
        view.layer.borderColor = AppDesign.Surface.border.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var attachmentButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "paperclip", withConfiguration: sendButtonSymbolConfig), for: .normal)
        button.tintColor = AppDesign.Color.primaryGreen
        button.backgroundColor = AppDesign.Surface.subtleTint
        button.layer.cornerRadius = AppDesign.ControlSize.minimumTapTarget / 2
        button.addTarget(self, action: #selector(attachmentTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let inputField: ComposerTextView = {
        let field = ComposerTextView()
        field.font = .systemFont(ofSize: 16)
        field.textColor = .label
        field.tintColor = AppDesign.Color.primaryGreen
        field.maxHeight = AppDesign.Chat.composerMaxHeight
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private lazy var sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.up", withConfiguration: sendButtonSymbolConfig), for: .normal)
        button.tintColor = .white
        button.backgroundColor = AppDesign.Color.primaryGreen
        button.layer.cornerRadius = AppDesign.ControlSize.minimumTapTarget / 2
        button.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Init

    init(
        initialMessage: String?,
        remoteService: SymptomChatRemoteServing = LiveSymptomChatRemoteService()
    ) {
        self.initialMessage = initialMessage
        self.remoteService = remoteService
        self.sessionCoordinator = SymptomChatSessionCoordinator(remoteService: remoteService)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.initialMessage = nil
        self.remoteService = LiveSymptomChatRemoteService()
        self.sessionCoordinator = SymptomChatSessionCoordinator(remoteService: self.remoteService)
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTheme()
        setupLayout()
        installTopicStripIfNeeded()
        applyAccessibility()
        setupKeyboardNotifications()
        setupGestures()
        configureBackButtonIfNeeded()
        navigationItem.rightBarButtonItems = [newChatButtonItem, historyButtonItem]
        refreshHistoryButtonState()
        restoreBestAvailableConversation()

        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(authTokenChanged), name: .authTokenDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureNavigationChrome()
        refreshHistoryButtonState()
        processPendingDeletesIfNeeded()
        processPendingUploadsIfNeeded()
        guard !hasHandledInitialMessage else { return }
        hasHandledInitialMessage = true

        let draftText = externalDraftMessage ?? initialMessage
        if conversationHistory.isEmpty, let draftText, !draftText.isEmpty {
            inputField.text = draftText
        } else {
            inputField.text = nil
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        persistConversationHistory()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        activeStream?.cancel()
        attachmentTask?.cancel()
        persistConversationHistory()
    }

    // MARK: - Setup

    private func setupTheme() {
        view.backgroundColor = SymptomChatAppearance.pageBackgroundColor
        title = t(.tabChat)
        configureNavigationChrome()
        composerHelperLabel.text = t(.symptomChatLandingFeatureUpload)
        inputField.setPlaceholder(t(.symptomChatInputPlaceholder))
        inputField.delegate = self
    }

    private func applyAccessibility() {
        inputField.accessibilityLabel = t(.symptomChatInputPlaceholder)
        attachmentButton.accessibilityLabel = t(.symptomChatAttachmentMenuTitle)
        sendButton.accessibilityLabel = t(.symptomChatSend)
    }

    private func configureBackButtonIfNeeded() {
        if navigationController?.viewControllers.first === self {
            navigationItem.leftBarButtonItem = nil
        } else {
            let item = UIBarButtonItem(
                image: UIImage(systemName: "chevron.left"),
                style: .plain,
                target: self,
                action: #selector(backTapped)
            )
            item.accessibilityLabel = t(.back)
            navigationItem.leftBarButtonItem = item
        }
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(messageStack)
        view.addSubview(composerBackground)
        scrollView.delegate = self

        composerBackground.addSubview(composerStack)
        composerStack.addArrangedSubview(composerHelperLabel)
        composerStack.addArrangedSubview(attachmentPreviewStack)
        composerStack.addArrangedSubview(inputContainer)

        inputContainer.addSubview(attachmentButton)
        inputContainer.addSubview(inputField)
        inputContainer.addSubview(sendButton)

        let bottomConstraint = composerBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        composerBottomConstraint = bottomConstraint
        let scrollTopConstraint = scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        scrollViewTopConstraint = scrollTopConstraint

        NSLayoutConstraint.activate([
            scrollTopConstraint,
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: composerBackground.topAnchor),

            messageStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            messageStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            messageStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            messageStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            messageStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),

            composerBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composerBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,

            composerStack.topAnchor.constraint(equalTo: composerBackground.topAnchor, constant: 12),
            composerStack.leadingAnchor.constraint(equalTo: composerBackground.leadingAnchor, constant: 16),
            composerStack.trailingAnchor.constraint(equalTo: composerBackground.trailingAnchor, constant: -16),
            composerStack.bottomAnchor.constraint(equalTo: composerBackground.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            attachmentButton.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 10),
            attachmentButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            attachmentButton.widthAnchor.constraint(equalToConstant: AppDesign.ControlSize.minimumTapTarget),
            attachmentButton.heightAnchor.constraint(equalToConstant: AppDesign.ControlSize.minimumTapTarget),

            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -10),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: AppDesign.ControlSize.minimumTapTarget),
            sendButton.heightAnchor.constraint(equalToConstant: AppDesign.ControlSize.minimumTapTarget),

            inputField.leadingAnchor.constraint(equalTo: attachmentButton.trailingAnchor, constant: 10),
            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -10),
            inputField.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 6),
            inputField.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -6),
            inputField.heightAnchor.constraint(greaterThanOrEqualToConstant: AppDesign.Chat.composerMinHeight),
        ])
    }

    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)
    }

    // MARK: - Actions

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    func setDraftMessage(_ text: String?) {
        externalDraftMessage = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isViewLoaded, conversationHistory.isEmpty else { return }
        inputField.text = externalDraftMessage?.isEmpty == false ? externalDraftMessage : nil
    }

    @objc private func keyboardWillChangeFrame(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
            ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
        let keyboardFrameInView = view.convert(keyboardFrame.cgRectValue, from: nil)
        let overlap = max(0, view.bounds.intersection(keyboardFrameInView).height)
        let shouldScroll = overlap > 0 && (inputField.isFirstResponder || isFollowingLatestContent)

        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState]) {
            self.composerBottomConstraint?.constant = -overlap
            self.view.layoutIfNeeded()
        } completion: { _ in
            guard shouldScroll else { return }
            self.scrollToBottom(force: true)
        }
    }

    @objc private func appDidEnterBackground() {
        persistConversationHistory()
    }

    @objc private func languageChanged() {
        title = t(.tabChat)
        configureNavigationChrome()
        composerHelperLabel.text = t(.symptomChatLandingFeatureUpload)
        applyTopicPlaceholder()
        inputField.accessibilityLabel = t(.symptomChatInputPlaceholder)
        attachmentButton.accessibilityLabel = t(.symptomChatAttachmentMenuTitle)
        sendButton.accessibilityLabel = isSending ? t(.symptomChatCancelled) : t(.symptomChatSend)
        newChatButtonItem.accessibilityLabel = t(.symptomChatStartNew)
        historyButtonItem.accessibilityLabel = t(.symptomChatHistoryButton)
        retryButton?.setTitle(t(.symptomChatRetry), for: .normal)
        refreshAttachmentPreviewStack()
        refreshHistoryButtonState()
        (welcomeHeroView as? SymptomChatWelcomeHeroView)?.refreshLocalization()
        for row in messageStack.arrangedSubviews {
            for subview in row.subviews {
                (subview as? MessageBubbleView)?.refreshLocalizedContent()
            }
        }
    }

    @objc private func authTokenChanged() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.authTokenChanged()
            }
            return
        }
        invalidateRemoteHistorySaveState()
        remoteHistoryBaselineSignature = nil
        refreshHistoryButtonState()
        if !AuthTokenManager.shared.isLoggedIn {
            return
        }
        if shouldAutoRestoreConversationAfterAuthChange {
            restoreBestAvailableConversation()
        }
    }

    @objc private func sendTapped() {
        if isSending {
            cancelCurrentStream()
            return
        }
        sendCurrentInput()
    }

    @objc private func startNewConversationTapped() {
        let decision = sessionCoordinator.openNewChat(currentDraft: inputField.text, isStreaming: isSending || activeStream != nil)
        if let blockedMessage = decision.blockedMessage {
            showFloatingHint(blockedMessage)
            return
        }
        latestResumeSession = nil
        resetToDraftOnlyConversation(draftText: decision.injectedDraft)
    }

    @objc private func historyTapped() {
        openHistoryPage()
    }

    private func openHistoryPage() {
        guard !isSending, sessionCoordinator.state != .streamingFirstReply else {
            showInlineError(t(.symptomChatHistoryWaitForReply))
            return
        }

        let vc = ChatHistoryViewController(
            coordinator: sessionCoordinator,
            onSelect: { [weak self] session in
                guard let self else { return }
                let restored = self.sessionCoordinator.switchToSession(id: session.id, currentDraft: self.inputField.text)
                self.applyLocalSession(restored ?? session, scrollToLatest: false)
            },
            onDelete: { [weak self] sessions in
                self?.handleHistoryDeletion(sessions)
            }
        )
        navigationController?.pushViewController(vc, animated: true)
    }

    private func continueLatestConversationTapped() {
        let fallbackSession = latestResumeSession ?? sessionCoordinator.visibleHistorySessions().first
        guard let session = fallbackSession else { return }
        let restored = sessionCoordinator.switchToSession(id: session.id, currentDraft: inputField.text) ?? session
        applyLocalSession(restored, scrollToLatest: false)
        let resumeHint = restored.remoteId == nil ? t(.symptomChatResumedFromDevice) : t(.symptomChatResumedFromCloud)
        showFloatingHint(resumeHint)
    }

    private func handleHistoryDeletion(_ sessions: [LocalChatSession]) {
        let deleted = sessionCoordinator.deleteSessions(ids: sessions.map(\.id))
        let currentWasDeleted = deleted.contains { $0.id == activeLocalSessionId }
        latestResumeSession = sessionCoordinator.visibleHistorySessions().first
        Task { [weak self] in
            guard let self else { return }
            await self.sessionCoordinator.syncPendingDeletes()
        }
        if currentWasDeleted {
            resetToDraftOnlyConversation(draftText: nil)
        }
    }

    private func processPendingDeletesIfNeeded() {
        guard Config.useRelay, AuthTokenManager.shared.isLoggedIn else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.sessionCoordinator.syncPendingDeletes()
        }
    }

    private func processPendingUploadsIfNeeded() {
        guard Config.useRelay, AuthTokenManager.shared.isLoggedIn else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.sessionCoordinator.syncPendingUploads()
        }
    }

    @objc private func attachmentTapped() {
        guard ensureRelayFeatureAuthorization(onReady: { [weak self] in
            self?.attachmentTapped()
        }) else {
            return
        }

        let alert = UIAlertController(title: t(.symptomChatAttachmentMenuTitle), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: t(.symptomChatAttachImage), style: .default) { [weak self] _ in
            self?.presentImagePicker(sourceType: .photoLibrary)
        })
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: t(.symptomChatAttachCamera), style: .default) { [weak self] _ in
                self?.presentImagePicker(sourceType: .camera)
            })
        }
        alert.addAction(UIAlertAction(title: t(.symptomChatAttachPDF), style: .default) { [weak self] _ in
            self?.presentPDFPicker()
        })
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = attachmentButton
            popover.sourceRect = attachmentButton.bounds
        }

        present(alert, animated: true)
    }

    @objc private func removePendingAttachment(_ sender: UIButton) {
        guard let identifier = sender.accessibilityIdentifier,
              let uuid = UUID(uuidString: identifier) else { return }
        pendingAttachments.removeAll { $0.id == uuid }
    }

    @objc private func retryTapped() {
        guard let message = lastSubmittedMessage else { return }
        retryButton?.removeFromSuperview()
        retryButton = nil
        submit(message, appendUserBubble: false, reuseAssistantBubble: true)
    }

    // MARK: - Sending

    private func sendCurrentInput() {
        let text = (inputField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let preparedAttachments = pendingAttachments.compactMap(\.preparedAttachment)

        if pendingAttachments.contains(where: \.isProcessing) {
            showInlineError(t(.symptomChatAttachmentPending))
            return
        }

        if pendingAttachments.contains(where: {
            if case .failed = $0 { return true }
            return false
        }) {
            showInlineError(t(.symptomChatAttachmentFailedBlocked))
            return
        }

        guard !text.isEmpty || !preparedAttachments.isEmpty else {
            showInlineError(t(.symptomChatEmptyInput))
            return
        }

        guard ensureRelayFeatureAuthorization(onReady: { [weak self] in
            self?.sendCurrentInput()
        }) else {
            return
        }

        let visibleMessage = text.isEmpty ? t(.symptomChatAttachmentDefaultPrompt) : text
        // Topic context is sent to the backend but not rendered in the bubble.
        let apiMessage = topicSelectorEnabled && currentTopic != .healthConsult
            ? "\(currentTopic.promptContext)\n\(visibleMessage)"
            : visibleMessage
        let payloads = preparedAttachments.map(\.payload)
        let attachmentTitles = preparedAttachments.map(\.displayName)
        let historyMessage = makeHistoryMessage(requestText: visibleMessage, attachments: payloads)

        inputField.text = nil
        clearPendingAttachments()
        retryButton?.removeFromSuperview()
        retryButton = nil

        let outgoing = OutgoingMessage(
            visibleMessage: visibleMessage,
            apiMessage: apiMessage,
            historyMessage: historyMessage,
            historySnapshot: conversationHistory,
            attachments: payloads,
            attachmentTitles: attachmentTitles
        )
        isFollowingLatestContent = true
        submit(outgoing, appendUserBubble: true, reuseAssistantBubble: false)
    }

    private func sendAutomatedMessage(visibleText: String, apiText: String? = nil) {
        guard !isSending else { return }
        guard ensureRelayFeatureAuthorization(onReady: { [weak self] in
            self?.sendAutomatedMessage(visibleText: visibleText, apiText: apiText)
        }) else {
            return
        }

        retryButton?.removeFromSuperview()
        retryButton = nil
        let outgoing = OutgoingMessage(
            visibleMessage: visibleText,
            apiMessage: apiText ?? visibleText,
            historyMessage: apiText ?? visibleText,
            historySnapshot: conversationHistory,
            attachments: [],
            attachmentTitles: []
        )
        isFollowingLatestContent = true
        submit(outgoing, appendUserBubble: true, reuseAssistantBubble: false)
    }

    private func updatePendingHistorySnapshot(baseHistory: [AssistantChatMessage], userMessage: String, assistantText: String?) {
        var snapshot = baseHistory + [
            AssistantChatMessage(role: "user", content: userMessage)
        ]
        if let assistantText, !assistantText.trimmedForChat.isEmpty {
            snapshot.append(AssistantChatMessage(role: "assistant", content: assistantText.trimmedForChat))
        }
        pendingHistorySnapshot = snapshot
    }

    private func submit(_ outgoing: OutgoingMessage, appendUserBubble: Bool, reuseAssistantBubble: Bool) {
        activeStream?.cancel()
        activeStream = nil
        transitionToFirstReplyStreamingIfNeeded()
        if welcomeHeroView != nil {
            dismissWelcomePresentationForFirstReplyIfNeeded()
        }
        updatePendingHistorySnapshot(baseHistory: outgoing.historySnapshot, userMessage: outgoing.historyMessage, assistantText: nil)
        lastSubmittedMessage = outgoing
        latestStreamMeta = nil
        streamedTokenBuffer = ""
        currentCitations = []
        streamDidFail = false
        isCancellingStream = false

        if appendUserBubble {
            _ = appendMessageBubble(text: outgoing.visibleMessage, role: .user, attachmentTitles: outgoing.attachmentTitles)
        }

        let assistantBubble: MessageBubbleView
        if reuseAssistantBubble, let currentAssistantBubble {
            assistantBubble = currentAssistantBubble
        } else {
            assistantBubble = appendMessageBubble(text: "", role: .assistant)
        }

        assistantBubble.resetForStreaming(placeholder: t(.symptomChatThinking))
        currentAssistantBubble = assistantBubble
        setSending(true)

        Task { [weak self, weak assistantBubble] in
            guard let self, let assistantBubble else { return }

            let authReady = await prepareRelayChatAuthorization()
            guard authReady else {
                await MainActor.run {
                    self.handleStreamFailure(detail: APIError.unauthorized.localizedDescription)
                }
                return
            }

            do {
                let session = try self.remoteService.makeAssistantStreamSession(
                    message: outgoing.apiMessage,
                    history: outgoing.historySnapshot,
                    attachments: outgoing.attachments,
                    language: LocaleManager.shared.current.rawValue,
                    onToken: { [weak self] token in
                        guard let self else { return }
                        self.streamedTokenBuffer += token
                        let display = self.sanitizedStreamingText(self.streamedTokenBuffer)
                        guard !display.isEmpty else { return }
                        assistantBubble.completeText(display)
                        self.updatePendingHistorySnapshot(baseHistory: outgoing.historySnapshot, userMessage: outgoing.historyMessage, assistantText: display)
                    },
                    onMeta: { [weak self, weak assistantBubble] meta in
                        guard let self, let assistantBubble else { return }
                        self.latestStreamMeta = meta
                        if let cleanReply = meta.cleanReply?.trimmedForChat, !cleanReply.isEmpty {
                            self.updatePendingHistorySnapshot(baseHistory: outgoing.historySnapshot, userMessage: outgoing.historyMessage, assistantText: cleanReply)
                        }
                        assistantBubble.applyMeta(
                            meta,
                            confirmTitle: t(.confirm),
                            modifyTitle: t(.symptomChatModify),
                            doctorsTitle: t(.symptomChatDoctorsTitle),
                            citationsTitle: t(.symptomChatCitationsTitle),
                            onSubmitChoiceAnswers: { [weak self] visible, api in
                                self?.sendAutomatedMessage(visibleText: visible, apiText: api)
                            },
                            onConfirm: { [weak self] in
                                self?.sendAutomatedMessage(visibleText: t(.confirm), apiText: "确认")
                            },
                            onModify: { [weak self] in
                                self?.sendAutomatedMessage(visibleText: t(.symptomChatModify), apiText: "修改")
                            },
                            onOpenCitation: { urlString in
                                guard let url = URL(string: urlString) else { return }
                                UIApplication.shared.open(url)
                            }
                        )
                        self.scrollToBottom()
                    },
                    onGrounding: { [weak self, weak assistantBubble] citations in
                        guard let self, let assistantBubble else { return }
                        self.currentCitations = self.mergeCitations(self.currentCitations, with: citations)
                        assistantBubble.applyCitations(self.currentCitations, title: t(.symptomChatCitationsTitle)) { urlString in
                            guard let url = URL(string: urlString) else { return }
                            UIApplication.shared.open(url)
                        }
                        self.scrollToBottom()
                    },
                    onError: { [weak self] detail in
                        guard let self else { return }
                        if self.isCancellingStream { return }
                        self.handleStreamFailure(detail: detail)
                    },
                    onComplete: { [weak self] in
                        self?.handleStreamComplete()
                    }
                )

                await MainActor.run {
                    self.activeStream = session
                    session.start()
                }
            } catch {
                await MainActor.run {
                    self.handleStreamFailure(detail: error.localizedDescription)
                }
            }
        }
    }

    private func mergeCitations(_ current: [AssistantCitation], with new: [AssistantCitation]) -> [AssistantCitation] {
        let existing = Set(current)
        return current + new.filter { !existing.contains($0) }
    }

    private func handleStreamFailure(detail: String) {
        streamDidFail = true
        activeStream = nil
        setSending(false)
        regeneratingMessageId = nil
        if activeLocalSessionId == nil {
            sessionCoordinator.returnToDraftOnly(detachedDraft: lastSubmittedMessage?.visibleMessage)
        }
        let failureText = t(.symptomChatError)
        currentAssistantBubble?.setPlainText(failureText)
        if let outgoing = lastSubmittedMessage {
            updatePendingHistorySnapshot(baseHistory: outgoing.historySnapshot, userMessage: outgoing.historyMessage, assistantText: failureText)
        }
        installRetryButton(detail: detail)
    }

    private func handleStreamComplete() {
        activeStream = nil
        defer {
            setSending(false)
            isCancellingStream = false
        }

        guard !streamDidFail else { return }
        guard let outgoing = lastSubmittedMessage else { return }

        let finalReply: String
        if let cleanReply = latestStreamMeta?.cleanReply?.trimmedForChat, !cleanReply.isEmpty {
            finalReply = cleanReply
        } else {
            finalReply = sanitizedStreamingText(streamedTokenBuffer)
        }
        let finalDisplayReply = finalReply
        let finalCitations = currentCitations

        guard !finalReply.isEmpty else { return }

        currentAssistantBubble?.completeText(finalReply)
        currentAssistantBubble?.revealDeferredCitations()
        if let regeneratingMessageId,
           let session = sessionCoordinator.appendRegeneratedVersion(
            messageId: regeneratingMessageId,
            content: finalReply,
            displayContent: finalDisplayReply,
            citations: finalCitations
           ) {
            self.regeneratingMessageId = nil
            applyLocalSession(session, scrollToLatest: false, preserveDraft: true)
            persistConversationHistory()
            return
        }
        let now = Date()
        if sessionCoordinator.state == .streamingFirstReply || activeLocalSessionId == nil {
            let session = sessionCoordinator.finalizeFirstReply(
                userMessage: outgoing.historyMessage,
                displayedUserMessage: outgoing.visibleMessage,
                userAttachmentTitles: outgoing.attachmentTitles,
                assistantMessage: finalReply,
                displayedAssistantMessage: finalDisplayReply,
                assistantCitations: finalCitations,
                createdAt: now
            )
            applyLocalSession(session)
        } else {
            let userMessage = LocalChatMessage(
                role: "user",
                content: outgoing.historyMessage,
                displayContent: outgoing.visibleMessage,
                createdAt: now.timeIntervalSince1970,
                attachmentTitles: outgoing.attachmentTitles
            )
            let assistantMessage = LocalChatMessage(
                role: "assistant",
                content: finalReply,
                createdAt: now.timeIntervalSince1970,
                versions: [LocalAssistantVersion(
                    content: finalReply,
                    displayContent: finalDisplayReply,
                    citations: finalCitations,
                    createdAt: now.timeIntervalSince1970
                )]
            )
            currentLocalMessages = outgoing.historySnapshot.enumerated().compactMap { index, historyMessage in
                if index < currentLocalMessages.count { return currentLocalMessages[index] }
                return LocalChatMessage(
                    role: historyMessage.role,
                    content: historyMessage.content,
                    displayContent: historyMessage.displayContent,
                    createdAt: now.timeIntervalSince1970,
                    versions: historyMessage.versions?.map {
                        LocalAssistantVersion(
                            id: $0.versionID,
                            content: $0.content,
                            displayContent: $0.displayContent,
                            citations: $0.citations ?? [],
                            createdAt: now.timeIntervalSince1970,
                            feedback: $0.feedback == .up ? .like : ($0.feedback == .down ? .dislike : nil)
                        )
                    } ?? []
                )
            } + [userMessage, assistantMessage]
            if let session = sessionCoordinator.syncCurrentConversation(
                messages: currentLocalMessages,
                titleFallback: LocalChatSession.makeTitle(from: outgoing.visibleMessage)
            ) {
                applyLocalSession(session)
            }
        }
        persistConversationHistory()
    }

    private func cancelCurrentStream() {
        guard activeStream != nil else { return }
        isCancellingStream = true
        streamDidFail = true
        activeStream?.cancel()
        activeStream = nil
        setSending(false)
        regeneratingMessageId = nil
        if activeLocalSessionId == nil {
            sessionCoordinator.returnToDraftOnly(detachedDraft: lastSubmittedMessage?.visibleMessage)
        }
        let cancelledText = t(.symptomChatCancelled)
        currentAssistantBubble?.setPlainText(cancelledText)
        if let outgoing = lastSubmittedMessage {
            updatePendingHistorySnapshot(baseHistory: outgoing.historySnapshot, userMessage: outgoing.historyMessage, assistantText: cancelledText)
        }
        installRetryButton(detail: cancelledText)
    }

    private func installRetryButton(detail: String) {
        retryButton?.removeFromSuperview()
        let button = UIButton(type: .system)
        button.setTitle(t(.symptomChatRetry), for: .normal)
        button.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = t(.symptomChatRetry)
        button.accessibilityHint = detail
        messageStack.addArrangedSubview(button)
        retryButton = button
        scrollToBottom()
    }

    private func applyFeedback(_ feedback: ChatFeedbackKind, for message: LocalChatMessage) {
        guard let activeVersionId = message.activeVersion?.id else { return }
        let nextFeedback: ChatFeedbackKind? = feedback
        if let session = sessionCoordinator.setFeedback(messageId: message.id, versionId: activeVersionId, feedback: nextFeedback) {
            applyLocalSession(session, scrollToLatest: false, preserveDraft: true)
            Task {
                guard let nextFeedback else { return }
                _ = try? await sessionCoordinator.submitFeedback(
                    for: session,
                    messageId: message.id,
                    versionId: activeVersionId,
                    feedback: nextFeedback
                )
            }
        }
    }

    private func regenerateLastAssistantReply(_ message: LocalChatMessage) {
        guard let lastAssistantIndex = currentLocalMessages.lastIndex(where: { $0.role == "assistant" }),
              currentLocalMessages[lastAssistantIndex].id == message.id,
              lastAssistantIndex > 0 else { return }
        let userMessage = currentLocalMessages[lastAssistantIndex - 1]
        guard userMessage.role == "user" else { return }
        let baseMessages = Array(currentLocalMessages.prefix(lastAssistantIndex - 1)).map { $0.visibleAssistantMessage }
        let outgoing = OutgoingMessage(
            visibleMessage: userMessage.activeContent,
            apiMessage: userMessage.content,
            historyMessage: userMessage.content,
            historySnapshot: baseMessages,
            attachments: [],
            attachmentTitles: userMessage.attachmentTitles
        )
        regeneratingMessageId = message.id
        currentAssistantBubble = renderedAssistantBubbles[message.id]
        submit(outgoing, appendUserBubble: false, reuseAssistantBubble: true)
    }

    private func switchVersion(for message: LocalChatMessage, direction: Int) {
        guard let index = message.activeVersionIndex else { return }
        let targetIndex = index + direction
        guard targetIndex >= 0, targetIndex < message.versions.count else { return }
        let targetVersion = message.versions[targetIndex]
        if let session = sessionCoordinator.switchAssistantVersion(messageId: message.id, versionId: targetVersion.id) {
            applyLocalSession(session, scrollToLatest: false, preserveDraft: true)
            persistConversationHistory()
        }
    }

    private func setSending(_ value: Bool) {
        isSending = value
        inputField.isEditable = !value
        inputField.isSelectable = !value
        inputField.alpha = value ? 0.7 : 1.0
        attachmentButton.isEnabled = !value
        attachmentButton.alpha = value ? 0.55 : 1.0
        historyButtonItem.isEnabled = !value
        sendButton.isEnabled = true
        sendButton.backgroundColor = value ? .systemOrange : AppDesign.Color.primaryGreen
        let symbol = value ? "stop.fill" : "arrow.up"
        sendButton.setImage(UIImage(systemName: symbol, withConfiguration: sendButtonSymbolConfig), for: .normal)
        sendButton.accessibilityLabel = value ? t(.symptomChatCancelled) : t(.symptomChatSend)
        refreshHistoryButtonState()
    }

    private func transitionToFirstReplyStreamingIfNeeded() {
        guard conversationHistory.isEmpty, currentLocalMessages.isEmpty else { return }

        if activeLocalSessionId != nil || sessionCoordinator.state != .draftOnly {
            sessionCoordinator.returnToDraftOnly()
            activeLocalSessionId = nil
            currentRemoteSessionID = nil
            currentLocalMessages = []
            remoteHistoryBaselineSignature = nil
        }

        sessionCoordinator.beginFirstReplyStreaming()
    }

    private var presentationState: SymptomChatPresentationState {
        SymptomChatPresentationState(
            isRelayEnabled: Config.useRelay,
            isRelayLoggedIn: AuthTokenManager.shared.isLoggedIn,
            hasConversationHistory: !conversationHistory.isEmpty || !currentLocalMessages.isEmpty,
            hasInitialMessage: initialMessage != nil,
            coordinatorState: sessionCoordinator.state,
            isSending: isSending,
            hasActiveStream: activeStream != nil,
            hasPendingSubmission: lastSubmittedMessage != nil
        )
    }

    private var shouldAutoRestoreConversationAfterAuthChange: Bool {
        presentationState.shouldAutoRestoreConversationAfterAuthChange
    }

    private func dismissWelcomePresentationForFirstReplyIfNeeded() {
        guard welcomeHeroView != nil else { return }
        removePresentationOverlay(welcomeHeroView)
        welcomeHeroView = nil
        view.layoutIfNeeded()
        scrollToBottom(force: true)
    }

    private func resetConversationUI() {
        for arrangedSubview in messageStack.arrangedSubviews {
            messageStack.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }
        welcomeHeroView = nil
        renderedAssistantBubbles.removeAll()
        renderedActionBars.removeAll()
    }

    private func installTopicStripIfNeeded() {
        guard topicSelectorEnabled, topicStripView == nil, isViewLoaded else { return }
        let strip = ChatTopicStripView()
        strip.translatesAutoresizingMaskIntoConstraints = false
        strip.onSelect = { [weak self] topic in
            self?.selectTopic(topic)
        }
        view.addSubview(strip)
        scrollViewTopConstraint?.isActive = false
        let newTop = scrollView.topAnchor.constraint(equalTo: strip.bottomAnchor)
        scrollViewTopConstraint = newTop
        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            strip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            newTop,
        ])
        topicStripView = strip
    }

    private func selectTopic(_ topic: ChatTopic) {
        guard !isSending, activeStream == nil else {
            showInlineError(t(.symptomChatHistoryWaitForReply))
            return
        }
        guard topic != currentTopic else { return }
        currentTopic = topic
        topicStripView?.selectTopic(topic)
        applyTopicPlaceholder()
        persistConversationHistory()
        resetToDraftOnlyConversation(draftText: nil)
    }

    private func applyTopicPlaceholder() {
        if topicSelectorEnabled {
            inputField.setPlaceholder("输入\(currentTopic.label)问题")
        } else {
            inputField.setPlaceholder(t(.symptomChatInputPlaceholder))
        }
    }

    private func showWelcomeState() {
        welcomeHeroView?.removeFromSuperview()
        welcomeHeroView = nil
        guard sessionCoordinator.state == .draftOnly,
              presentationState.shouldShowWelcomeHero else {
            return
        }
        installWelcomeHeroIfNeeded()
    }

    private func removePresentationOverlay(_ overlay: UIView?) {
        guard let overlay else { return }
        if messageStack.arrangedSubviews.contains(overlay) {
            messageStack.removeArrangedSubview(overlay)
        }
        overlay.removeFromSuperview()
    }

    private func configureNavigationChrome() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0)
                : UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0)
        }
        appearance.shadowColor = UIColor.clear
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
        ]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = .label
        navigationItem.titleView = nil
        navigationItem.title = t(.tabChat)
    }

    private func installWelcomeHeroIfNeeded() {
        welcomeHeroView?.removeFromSuperview()
        if topicSelectorEnabled {
            let memberName = ((try? ProfileManager.shared.activeProfile()) ?? nil)?.name ?? "朋友"
            let topicWelcome = ChatTopicWelcomeView(topic: currentTopic, memberName: memberName)
            topicWelcome.onSuggestion = { [weak self] question in
                self?.inputField.text = question
                self?.inputField.becomeFirstResponder()
            }
            topicWelcome.onUploadReport = { [weak self] in
                self?.attachmentTapped()
            }
            messageStack.addArrangedSubview(topicWelcome)
            welcomeHeroView = topicWelcome
            return
        }
        let heroView = SymptomChatWelcomeHeroView()
        heroView.onSelectPrompt = { [weak self] prompt in
            self?.inputField.text = prompt
            self?.inputField.becomeFirstResponder()
        }
        heroView.configureLatestSession(latestResumeSession)
        heroView.onResumeLatest = { [weak self] in
            self?.continueLatestConversationTapped()
        }
        heroView.onOpenHistory = { [weak self] in
            self?.openHistoryPage()
        }
        messageStack.addArrangedSubview(heroView)
        welcomeHeroView = heroView
    }

    private func sanitizedStreamingText(_ text: String) -> String {
        let patterns = [
            #"\[CHOICE_OPTIONS\][\s\S]*?(\[\/?\s*CHOICE_OPTIONS\]|$)"#,
            #"\[TRIAGE_QUERY\][\s\S]*?(\[\/?\s*TRIAGE_QUERY\]|$)"#,
            #"\[CONFIRM\][\s\S]*?(\[\/?\s*CONFIRM\]|$)"#,
        ]

        return patterns.reduce(text) { partial, pattern in
            partial.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }.trimmedForChat
    }

    private func prepareRelayChatAuthorization() async -> Bool {
        guard Config.useRelay else { return true }

        if AuthTokenManager.shared.refreshToken != nil {
            let refreshed = await AuthTokenManager.shared.refreshAccessToken()
            if refreshed {
                return true
            }
        }

        return AuthTokenManager.shared.accessToken != nil
    }

    // MARK: - Attachments moved to SymptomChatViewController+Attachments.swift

    // MARK: - UI Helpers

    @discardableResult
    private func appendMessageBubble(
        text: String,
        role: BubbleRole,
        attachmentTitles: [String] = [],
        localMessage: LocalChatMessage? = nil,
        canRegenerate: Bool = false,
        animate: Bool = true,
        forceScroll: Bool = false
    ) -> MessageBubbleView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let rowStack = UIStackView()
        rowStack.axis = .vertical
        rowStack.spacing = 8
        rowStack.alignment = role == .user ? .trailing : .leading
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        let bubble = MessageBubbleView(role: role)
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.setContentHuggingPriority(.required, for: .horizontal)
        bubble.setContentCompressionResistancePriority(.required, for: .horizontal)
        bubble.setAttachmentTitles(attachmentTitles)
        messageStack.addArrangedSubview(row)
        row.addSubview(rowStack)
        rowStack.addArrangedSubview(bubble)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: row.topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: rowStack.widthAnchor, multiplier: role == .user ? AppDesign.Chat.userBubbleMaxWidthRatio : AppDesign.Chat.assistantBubbleMaxWidthRatio),
        ])

        switch role {
        case .user:
            bubble.trailingAnchor.constraint(equalTo: rowStack.trailingAnchor).isActive = true
            let estimatedWidth = estimatedUserBubbleWidth(for: text)
            let widthConstraint = bubble.widthAnchor.constraint(equalToConstant: estimatedWidth)
            widthConstraint.priority = .defaultHigh
            widthConstraint.isActive = true
        case .assistant:
            bubble.leadingAnchor.constraint(equalTo: rowStack.leadingAnchor).isActive = true
            if let localMessage {
                let actionBar = makeAssistantActionBar(for: localMessage, canRegenerate: canRegenerate)
                rowStack.addArrangedSubview(actionBar)
                actionBar.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 4).isActive = true
                renderedAssistantBubbles[localMessage.id] = bubble
                renderedActionBars[localMessage.id] = actionBar
            }
        }

        bubble.completeText(text)
        if animate {
            row.alpha = 0
            row.transform = CGAffineTransform(translationX: 0, y: 10).scaledBy(x: 0.96, y: 0.96)
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                row.alpha = 1
                row.transform = .identity
            }
        } else {
            row.alpha = 1
            row.transform = .identity
        }

        scrollToBottom(force: forceScroll || role == .user)
        return bubble
    }

    private func estimatedUserBubbleWidth(for text: String) -> CGFloat {
        let maxWidth = max(180, view.bounds.width * (AppDesign.Chat.userBubbleMaxWidthRatio - 0.1))
        let bounding = NSString(string: text.isEmpty ? " " : text).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 16)],
            context: nil
        )
        return min(max(90, ceil(bounding.width) + 34), maxWidth)
    }

    private func makeAssistantActionBar(for message: LocalChatMessage, canRegenerate: Bool) -> AssistantMessageActionBarView {
        let actionBar = AssistantMessageActionBarView()
        let versionIndex = message.activeVersionIndex ?? max(message.versions.count - 1, 0)
        actionBar.configure(
            feedback: message.activeFeedback,
            canRegenerate: canRegenerate,
            hasPreviousVersion: versionIndex > 0,
            hasNextVersion: versionIndex < max(message.versions.count - 1, 0)
        )
        actionBar.onCopy = { [weak self] in
            UIPasteboard.general.string = message.activeContent
            self?.showFloatingHint(LocaleManager.shared.current == .en ? "Copied" : (LocaleManager.shared.current == .ar ? "تم النسخ" : "已复制"))
        }
        actionBar.onLike = { [weak self] in
            self?.applyFeedback(.like, for: message)
        }
        actionBar.onDislike = { [weak self] in
            self?.applyFeedback(.dislike, for: message)
        }
        actionBar.onRegenerate = canRegenerate ? { [weak self] in
            self?.regenerateLastAssistantReply(message)
        } : nil
        actionBar.onPreviousVersion = versionIndex > 0 ? { [weak self] in
            self?.switchVersion(for: message, direction: -1)
        } : nil
        actionBar.onNextVersion = versionIndex < max(message.versions.count - 1, 0) ? { [weak self] in
            self?.switchVersion(for: message, direction: 1)
        } : nil
        return actionBar
    }

    private func replayConversationHistory(_ localMessages: [LocalChatMessage], scrollToLatest: Bool) {
        for (index, message) in localMessages.enumerated() {
            let role: BubbleRole = message.role == "user" ? .user : .assistant
            let isLast = index == localMessages.count - 1
            let bubble = appendMessageBubble(
                text: message.activeContent,
                role: role,
                attachmentTitles: message.attachmentTitles,
                localMessage: message,
                canRegenerate: message.role == "assistant" && isLast,
                animate: false,
                forceScroll: scrollToLatest && isLast
            )
            if role == .assistant, !message.activeCitations.isEmpty {
                bubble.applyCitations(message.activeCitations, title: t(.symptomChatCitationsTitle)) { urlString in
                    guard let url = URL(string: urlString) else { return }
                    UIApplication.shared.open(url)
                }
                bubble.revealDeferredCitations()
            }
        }
    }

    private func applyLocalSession(_ session: LocalChatSession, scrollToLatest: Bool = true, preserveDraft: Bool = false) {
        let preservedDraft = preserveDraft ? inputField.text : nil
        isFollowingLatestContent = scrollToLatest
        latestResumeSession = nil
        currentAssistantBubble = nil
        retryButton = nil
        lastSubmittedMessage = nil
        invalidateRemoteHistorySaveState()
        pendingHistorySnapshot = []
        latestStreamMeta = nil
        currentCitations = []
        resetConversationUI()
        activeLocalSessionId = session.id
        currentRemoteSessionID = session.remoteId
        conversationHistory = session.visibleMessages
        currentLocalMessages = session.messages
        remoteHistoryBaselineSignature = conversationSignature(conversationHistory)
        inputField.text = preservedDraft
        replayConversationHistory(session.messages, scrollToLatest: scrollToLatest)
    }

    private func resetToDraftOnlyConversation(draftText: String?) {
        sessionCoordinator.returnToDraftOnly()
        isFollowingLatestContent = true
        currentAssistantBubble = nil
        retryButton = nil
        lastSubmittedMessage = nil
        invalidateRemoteHistorySaveState()
        pendingHistorySnapshot = []
        latestStreamMeta = nil
        currentCitations = []
        currentLocalMessages = []
        activeLocalSessionId = nil
        currentRemoteSessionID = nil
        resetConversationUI()
        conversationHistory = []
        inputField.text = draftText
        showWelcomeState()
        scrollView.setContentOffset(.zero, animated: false)
    }

    private func restoreBestAvailableConversation() {
        let restoredDraft = sessionCoordinator.restoreDetachedDraft()
        if let session = sessionCoordinator.bootstrapLatestSession() {
            let shouldOfferContinueLatest = (restoredDraft?.isEmpty ?? true)
                && (externalDraftMessage?.isEmpty ?? true)
                && initialMessage == nil
            if shouldOfferContinueLatest {
                latestResumeSession = session
                resetToDraftOnlyConversation(draftText: nil)
            } else {
                applyLocalSession(session)
            }
        } else {
            latestResumeSession = nil
            resetToDraftOnlyConversation(draftText: restoredDraft)
        }
    }

    private func refreshHistoryButtonState() {
        historyButtonItem.isEnabled = presentationState.isHistoryButtonEnabled
        newChatButtonItem.isEnabled = true
    }

    private func invalidateRemoteHistorySaveState() {
        remoteHistorySaveGeneration += 1
        remoteHistorySavingSignature = nil
    }

    private func conversationSignature(_ messages: [AssistantChatMessage]) -> String {
        messages.map { "\($0.role)|\($0.content)" }.joined(separator: "\n---\n")
    }

    private func persistConversationHistory() {
        guard !conversationHistory.isEmpty else { return }
        if let session = sessionCoordinator.syncCurrentConversation(
            messages: currentLocalMessages,
            titleFallback: LocalChatSession.makeTitle(from: conversationHistory.first(where: { $0.role == "user" })?.content ?? t(.tabChat))
        ) {
            activeLocalSessionId = session.id
            currentRemoteSessionID = session.remoteId
            let signature = conversationSignature(session.visibleMessages)
            guard Config.useRelay, AuthTokenManager.shared.isLoggedIn else { return }
            if signature == remoteHistoryBaselineSignature || signature == remoteHistorySavingSignature {
                return
            }

            remoteHistorySavingSignature = signature
            remoteHistorySaveGeneration += 1
            let saveGeneration = remoteHistorySaveGeneration
            Task { [weak self] in
                guard let self else { return }
                do {
                    let remoteSession = try await self.sessionCoordinator.syncSession(session)
                    await MainActor.run {
                        guard self.remoteHistorySaveGeneration == saveGeneration else { return }
                        self.remoteHistorySavingSignature = nil
                        self.currentRemoteSessionID = remoteSession.id
                        self.remoteHistoryBaselineSignature = signature
                    }
                } catch {
                    await MainActor.run {
                        guard self.remoteHistorySaveGeneration == saveGeneration else { return }
                        self.remoteHistorySavingSignature = nil
                    }
                }
            }
        }
    }

    func scrollToBottom(force: Bool = false) {
        if force {
            isFollowingLatestContent = true
        }
        guard force || isFollowingLatestContent else { return }
        view.layoutIfNeeded()
        let bottomOffset = CGPoint(
            x: 0,
            y: max(-scrollView.adjustedContentInset.top,
                   scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        )
        scrollView.setContentOffset(bottomOffset, animated: true)
    }

    private func showInlineError(_ text: String) {
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
        present(alert, animated: true)
    }

    private func showFloatingHint(_ text: String) {
        let label = PaddedHintLabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        label.insets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        label.layer.cornerRadius = 14
        label.layer.masksToBounds = true
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: composerBackground.topAnchor, constant: -12),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
        UIView.animate(withDuration: 0.2, animations: {
            label.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 1.1, options: [.curveEaseOut]) {
                label.alpha = 0
            } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        guard textView === inputField else { return }
        scrollToBottom(force: true)
    }

    func textViewDidChange(_ textView: UITextView) {
        guard textView === inputField else { return }
        view.layoutIfNeeded()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === self.scrollView else { return }
        guard scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating else { return }

        let visibleBottom = scrollView.contentOffset.y + scrollView.bounds.height - scrollView.adjustedContentInset.bottom
        let contentBottom = scrollView.contentSize.height
        isFollowingLatestContent = visibleBottom >= contentBottom - 48
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        let name = picker.sourceType == .camera
            ? t(.symptomChatAttachmentCameraFileName)
            : t(.symptomChatAttachmentPhotoLibraryFileName)
        prepareImageAttachment(image, suggestedName: name)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        preparePDFAttachment(from: url)
    }
}


private final class PaddedHintLabel: UILabel {
    var insets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
