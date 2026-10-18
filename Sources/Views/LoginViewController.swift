import UIKit

enum LoginEntryMode {
    case phone
    case email
}

class LoginViewController: UIViewController, UITextFieldDelegate, KeyboardBehaviorCustomizable {

    // MARK: - Keyboard Customization

    var keyboardAdjustmentType: KeyboardAdjustmentType {
        return .none
    }

    // MARK: - Constants

    private let themeColor = AppDesign.Color.primaryGreen
    // DIRTY_DEMO_FIXED_VERIFICATION_CODE_KEEP_FOR_PARITY_REMOVE_BEFORE_RELEASE
    private let mockVerificationCode = "1234"
    private var countdownSeconds = 0
    private var countdownTimer: Timer?
    private var loginButtonTopToPhoneConstraint: NSLayoutConstraint?
    private var loginButtonTopToEmailConstraint: NSLayoutConstraint?
    private let preferredLoginMode: LoginEntryMode
    private var isPerformingEmailLogin = false
    var onLoginSuccess: (() -> Void)?

    // MARK: - Scroll Container

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        // 允许拖动时收起键盘
        scroll.keyboardDismissMode = .interactive
        // 防止额外的滚动偏移，使用 safeAreaInsets 自动适应即可
        scroll.contentInsetAdjustmentBehavior = .never
        return scroll
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Gradient Header

    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let headerGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            AppDesign.Color.primaryGreen.cgColor,
            AppDesign.Color.gradientTop.cgColor,
            AppDesign.Color.gradientBottom.cgColor
        ]
        layer.locations = [0.0, 0.6, 1.0]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }()

    private let logoIconView: UIView = {
        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        container.layer.cornerRadius = 32
        container.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let imageView = UIImageView(image: UIImage(systemName: "heart.text.clipboard", withConfiguration: config))
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }()

    private let logoLabel: UILabel = {
        let label = UILabel()
        label.text = "Vvewell"
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = t(.brandTagline)
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Form Card

    private let formCard: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 24
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let formTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .label
        label.textAlignment = .natural
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let formSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .natural
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var loginModeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [t(.loginMethodPhone), t(.loginMethodEmail)])
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = themeColor.withAlphaComponent(0.16)
        control.backgroundColor = .secondarySystemBackground
        control.translatesAutoresizingMaskIntoConstraints = false
        control.addTarget(self, action: #selector(loginModeChanged), for: .valueChanged)
        return control
    }()

    private let phoneContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let prefixLabel: UILabel = {
        let label = UILabel()
        label.text = "+86"
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .natural
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let phoneTextField: UITextField = {
        let field = UITextField()
        field.font = .systemFont(ofSize: 16)
        field.keyboardType = .phonePad
        field.textAlignment = .natural
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let codeContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let codeTextField: UITextField = {
        let field = UITextField()
        field.font = .systemFont(ofSize: 16)
        field.keyboardType = .numberPad
        field.textAlignment = .natural
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private lazy var sendCodeButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.setTitleColor(themeColor, for: .normal)
        button.setTitleColor(.tertiaryLabel, for: .disabled)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addTarget(self, action: #selector(sendCodeTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Login Button (Gradient)

    private lazy var loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 14
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        return button
    }()

    private let loginButtonGradient: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            AppDesign.Color.primaryGreen.cgColor,
            AppDesign.Color.darkTeal.cgColor
        ]
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        return layer
    }()

    private let agreementLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.textAlignment = .natural
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emailLoginCard: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let emailLoginSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emailContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let emailTextField: UITextField = {
        let field = UITextField()
        field.font = .systemFont(ofSize: 16)
        field.keyboardType = .emailAddress
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.textContentType = .username
        field.clearButtonMode = .whileEditing
        field.textAlignment = .natural
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let passwordContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let passwordTextField: UITextField = {
        let field = UITextField()
        field.font = .systemFont(ofSize: 16)
        field.isSecureTextEntry = true
        field.textContentType = .password
        field.autocorrectionType = .no
        field.textAlignment = .natural
        field.returnKeyType = .go
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private lazy var togglePasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "eye"), for: .normal)
        button.tintColor = .tertiaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        return button
    }()

    private var currentLoginMode: LoginEntryMode

    // MARK: - Lifecycle

    init(preferredLoginMode: LoginEntryMode = .phone) {
        self.preferredLoginMode = preferredLoginMode
        self.currentLoginMode = preferredLoginMode
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        phoneTextField.delegate = self
        codeTextField.delegate = self
        emailTextField.delegate = self
        passwordTextField.delegate = self

        setupLayout()
        loginModeControl.selectedSegmentIndex = preferredLoginMode == .email ? 1 : 0
        updateTexts()

        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        headerGradientLayer.frame = headerView.bounds

        // Round only bottom corners of header
        let path = UIBezierPath(
            roundedRect: headerView.bounds,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: 32, height: 32)
        )
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        headerView.layer.mask = mask
        headerGradientLayer.frame = headerView.bounds

        loginButtonGradient.frame = loginButton.bounds
    }

    deinit {
        countdownTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup Layout

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            // 限制 contentView 宽度与 scrollView 相同，不允许横向滚动
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        setupHeader()
        setupFormCard()
    }

    private func setupHeader() {
        contentView.addSubview(headerView)
        headerView.layer.insertSublayer(headerGradientLayer, at: 0)

        headerView.addSubview(logoIconView)
        headerView.addSubview(logoLabel)
        headerView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            // 重要：高度仍然参考 self.view 的高度比例，保持视觉一致性
            headerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.38),

            logoIconView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            logoIconView.bottomAnchor.constraint(equalTo: logoLabel.topAnchor, constant: -16),
            logoIconView.widthAnchor.constraint(equalToConstant: 64),
            logoIconView.heightAnchor.constraint(equalToConstant: 64),

            logoLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            logoLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: 16),

            subtitleLabel.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
        ])
    }

    private func setupFormCard() {
        contentView.addSubview(formCard)
        formCard.addSubview(formTitleLabel)
        formCard.addSubview(formSubtitleLabel)
        formCard.addSubview(loginModeControl)
        formCard.addSubview(phoneContainerView)
        formCard.addSubview(codeContainerView)
        formCard.addSubview(emailLoginCard)
        formCard.addSubview(loginButton)
        formCard.addSubview(agreementLabel)

        loginButton.layer.insertSublayer(loginButtonGradient, at: 0)

        // Phone container children
        phoneContainerView.addSubview(prefixLabel)
        phoneContainerView.addSubview(separatorView)
        phoneContainerView.addSubview(phoneTextField)

        // Code container children
        codeContainerView.addSubview(codeTextField)
        codeContainerView.addSubview(sendCodeButton)

        emailLoginCard.addSubview(emailContainerView)
        emailLoginCard.addSubview(passwordContainerView)
        emailLoginCard.addSubview(emailLoginSubtitleLabel)
        emailContainerView.addSubview(emailTextField)
        passwordContainerView.addSubview(passwordTextField)
        passwordContainerView.addSubview(togglePasswordButton)

        NSLayoutConstraint.activate([
            // Form card overlaps header bottom
            formCard.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -32),
            formCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            formCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            // 重要：formCard 底部撑起 contentView 的内容高度
            formCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            // Form title
            formTitleLabel.topAnchor.constraint(equalTo: formCard.topAnchor, constant: 28),
            formTitleLabel.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 24),

            formSubtitleLabel.topAnchor.constraint(equalTo: formTitleLabel.bottomAnchor, constant: 6),
            formSubtitleLabel.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 24),

            loginModeControl.topAnchor.constraint(equalTo: formSubtitleLabel.bottomAnchor, constant: 20),
            loginModeControl.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 20),
            loginModeControl.trailingAnchor.constraint(equalTo: formCard.trailingAnchor, constant: -20),
            loginModeControl.heightAnchor.constraint(equalToConstant: 36),

            // Phone container
            phoneContainerView.topAnchor.constraint(equalTo: loginModeControl.bottomAnchor, constant: 16),
            phoneContainerView.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 20),
            phoneContainerView.trailingAnchor.constraint(equalTo: formCard.trailingAnchor, constant: -20),
            phoneContainerView.heightAnchor.constraint(equalToConstant: 52),

            prefixLabel.leadingAnchor.constraint(equalTo: phoneContainerView.leadingAnchor, constant: 16),
            prefixLabel.centerYAnchor.constraint(equalTo: phoneContainerView.centerYAnchor),

            separatorView.leadingAnchor.constraint(equalTo: prefixLabel.trailingAnchor, constant: 12),
            separatorView.centerYAnchor.constraint(equalTo: phoneContainerView.centerYAnchor),
            separatorView.widthAnchor.constraint(equalToConstant: 1),
            separatorView.heightAnchor.constraint(equalToConstant: 20),

            phoneTextField.leadingAnchor.constraint(equalTo: separatorView.trailingAnchor, constant: 12),
            phoneTextField.trailingAnchor.constraint(equalTo: phoneContainerView.trailingAnchor, constant: -16),
            phoneTextField.centerYAnchor.constraint(equalTo: phoneContainerView.centerYAnchor),

            // Code container
            codeContainerView.topAnchor.constraint(equalTo: phoneContainerView.bottomAnchor, constant: 14),
            codeContainerView.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 20),
            codeContainerView.trailingAnchor.constraint(equalTo: formCard.trailingAnchor, constant: -20),
            codeContainerView.heightAnchor.constraint(equalToConstant: 52),

            codeTextField.leadingAnchor.constraint(equalTo: codeContainerView.leadingAnchor, constant: 16),
            codeTextField.trailingAnchor.constraint(equalTo: sendCodeButton.leadingAnchor, constant: -8),
            codeTextField.centerYAnchor.constraint(equalTo: codeContainerView.centerYAnchor),

            sendCodeButton.trailingAnchor.constraint(equalTo: codeContainerView.trailingAnchor, constant: -16),
            sendCodeButton.centerYAnchor.constraint(equalTo: codeContainerView.centerYAnchor),

            emailLoginCard.topAnchor.constraint(equalTo: loginModeControl.bottomAnchor, constant: 16),
            emailLoginCard.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 20),
            emailLoginCard.trailingAnchor.constraint(equalTo: formCard.trailingAnchor, constant: -20),

            emailContainerView.topAnchor.constraint(equalTo: emailLoginCard.topAnchor, constant: 16),
            emailContainerView.leadingAnchor.constraint(equalTo: emailLoginCard.leadingAnchor, constant: 16),
            emailContainerView.trailingAnchor.constraint(equalTo: emailLoginCard.trailingAnchor, constant: -16),
            emailContainerView.heightAnchor.constraint(equalToConstant: 52),

            emailTextField.leadingAnchor.constraint(equalTo: emailContainerView.leadingAnchor, constant: 14),
            emailTextField.trailingAnchor.constraint(equalTo: emailContainerView.trailingAnchor, constant: -14),
            emailTextField.centerYAnchor.constraint(equalTo: emailContainerView.centerYAnchor),

            passwordContainerView.topAnchor.constraint(equalTo: emailContainerView.bottomAnchor, constant: 12),
            passwordContainerView.leadingAnchor.constraint(equalTo: emailContainerView.leadingAnchor),
            passwordContainerView.trailingAnchor.constraint(equalTo: emailContainerView.trailingAnchor),
            passwordContainerView.heightAnchor.constraint(equalToConstant: 52),

            passwordTextField.leadingAnchor.constraint(equalTo: passwordContainerView.leadingAnchor, constant: 14),
            passwordTextField.trailingAnchor.constraint(equalTo: togglePasswordButton.leadingAnchor, constant: -10),
            passwordTextField.centerYAnchor.constraint(equalTo: passwordContainerView.centerYAnchor),

            togglePasswordButton.trailingAnchor.constraint(equalTo: passwordContainerView.trailingAnchor, constant: -14),
            togglePasswordButton.centerYAnchor.constraint(equalTo: passwordContainerView.centerYAnchor),
            togglePasswordButton.widthAnchor.constraint(equalToConstant: 24),
            togglePasswordButton.heightAnchor.constraint(equalToConstant: 24),

            emailLoginSubtitleLabel.topAnchor.constraint(equalTo: passwordContainerView.bottomAnchor, constant: 10),
            emailLoginSubtitleLabel.leadingAnchor.constraint(equalTo: emailContainerView.leadingAnchor),
            emailLoginSubtitleLabel.trailingAnchor.constraint(equalTo: emailContainerView.trailingAnchor),
            emailLoginSubtitleLabel.bottomAnchor.constraint(equalTo: emailLoginCard.bottomAnchor, constant: -16),

            // Agreement
            agreementLabel.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 16),
            agreementLabel.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 24),
            agreementLabel.trailingAnchor.constraint(equalTo: formCard.trailingAnchor, constant: -24),
            agreementLabel.bottomAnchor.constraint(equalTo: formCard.bottomAnchor, constant: -24),
        ])

        loginButtonTopToPhoneConstraint = loginButton.topAnchor.constraint(equalTo: codeContainerView.bottomAnchor, constant: 28)
        loginButtonTopToEmailConstraint = loginButton.topAnchor.constraint(equalTo: emailLoginCard.bottomAnchor, constant: 28)
        NSLayoutConstraint.activate([
            loginButtonTopToPhoneConstraint!,
            loginButton.leadingAnchor.constraint(equalTo: formCard.leadingAnchor, constant: 20),
            loginButton.trailingAnchor.constraint(equalTo: formCard.trailingAnchor, constant: -20),
            loginButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func updateTexts() {
        subtitleLabel.text = t(.brandTagline)
        formTitleLabel.text = t(.loginTitle)
        formSubtitleLabel.text = currentLoginMode == .phone ? t(.loginSubtitle) : t(.relayLoginSubtitle)
        loginModeControl.setTitle(t(.loginMethodPhone), forSegmentAt: 0)
        loginModeControl.setTitle(t(.loginMethodEmail), forSegmentAt: 1)
        phoneTextField.placeholder = t(.loginPhonePlaceholder)
        codeTextField.placeholder = t(.loginCodePlaceholder)
        emailTextField.placeholder = t(.relayLoginEmailPlaceholder)
        passwordTextField.placeholder = t(.relayLoginPasswordPlaceholder)
        emailLoginSubtitleLabel.text = t(.loginEmailOptionSubtitle)
        loginButton.setTitle(currentLoginMode == .phone ? t(.loginTitle) : t(.loginEmailAction), for: .normal)
        agreementLabel.text = t(.loginAgreement)
        togglePasswordButton.accessibilityLabel = passwordTextField.isSecureTextEntry ? t(.relayLoginShowPassword) : t(.relayLoginHidePassword)
        if sendCodeButton.isEnabled {
            sendCodeButton.setTitle(t(.loginGetCode), for: .normal)
        } else {
            updateCountdownTitle()
        }
        applyLoginMode(animated: false)
    }

    @objc private func languageChanged() {
        updateTexts()
    }

    @objc private func loginModeChanged() {
        currentLoginMode = loginModeControl.selectedSegmentIndex == 1 ? .email : .phone
        updateTexts()
    }

    private func applyLoginMode(animated: Bool) {
        let showEmail = Config.useRelay && currentLoginMode == .email
        let updates = {
            self.loginModeControl.isHidden = !Config.useRelay
            self.phoneContainerView.isHidden = showEmail
            self.codeContainerView.isHidden = showEmail
            self.emailLoginCard.isHidden = !showEmail
            self.loginButtonTopToPhoneConstraint?.isActive = !showEmail
            self.loginButtonTopToEmailConstraint?.isActive = showEmail
            self.sendCodeButton.isEnabled = !showEmail && self.countdownTimer == nil
            self.loginButton.alpha = 1
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: updates)
        } else {
            updates()
        }
    }

    // MARK: - Actions

    @objc private func sendCodeTapped() {
        guard currentLoginMode == .phone else {
            return
        }

        guard let phone = phoneTextField.text, phone.count == 11 else {
            showAlert(message: t(.loginInvalidPhone))
            return
        }

        startCountdown()
        showAlert(message: t(.loginCodeSent))
    }

    @objc private func loginTapped() {
        if Config.useRelay, currentLoginMode == .email {
            performEmailLogin()
            return
        }

        guard let phone = phoneTextField.text, phone.count == 11 else {
            showAlert(message: t(.loginInvalidPhone))
            return
        }
        guard let code = codeTextField.text, code == mockVerificationCode else {
            showAlert(message: t(.loginIncorrectCode))
            return
        }

        AuthManager.shared.login(phone: phone)
        transitionToMain()
    }

    @objc private func togglePasswordVisibility() {
        passwordTextField.isSecureTextEntry.toggle()
        let imageName = passwordTextField.isSecureTextEntry ? "eye" : "eye.slash"
        togglePasswordButton.setImage(UIImage(systemName: imageName), for: .normal)
        togglePasswordButton.accessibilityLabel = passwordTextField.isSecureTextEntry ? t(.relayLoginShowPassword) : t(.relayLoginHidePassword)
    }

    // MARK: - Countdown

    private func startCountdown() {
        countdownSeconds = 60
        sendCodeButton.isEnabled = false
        updateCountdownTitle()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.countdownSeconds -= 1
            if self.countdownSeconds <= 0 {
                timer.invalidate()
                self.countdownTimer = nil
                self.sendCodeButton.isEnabled = true
                self.sendCodeButton.setTitle(t(.loginGetCode), for: .normal)
            } else {
                self.updateCountdownTitle()
            }
        }
    }

    private func updateCountdownTitle() {
        sendCodeButton.setTitle("\(countdownSeconds)s", for: .disabled)
    }

    // MARK: - Navigation

    private func transitionToMain() {
        if let onLoginSuccess {
            onLoginSuccess()
            return
        }

        guard let window = view.window else { return }

        let tabBarController = MainTabBarController()

        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
            window.rootViewController = tabBarController
        }
    }

    private func performEmailLogin() {
        guard !isPerformingEmailLogin else { return }
        let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !email.isEmpty, !password.isEmpty else {
            showAlert(message: t(.loginEnterEmailPassword))
            return
        }

        isPerformingEmailLogin = true
        loginButton.isEnabled = false
        sendCodeButton.isEnabled = false
        view.endEditing(true)

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await APIClient.shared.loginWithRelay(email: email, password: password)
                AuthTokenManager.shared.storeTokens(access: result.accessToken, refresh: result.refreshToken)
                await MainActor.run {
                    self.isPerformingEmailLogin = false
                    self.loginButton.isEnabled = true
                    self.applyLoginMode(animated: false)
                    self.transitionToMain()
                }
            } catch {
                await MainActor.run {
                    self.isPerformingEmailLogin = false
                    self.loginButton.isEnabled = true
                    self.applyLoginMode(animated: false)
                    self.showAlert(message: self.debugFriendlyErrorMessage(error))
                }
            }
        }
    }

    // MARK: - Helpers

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.loginAlertOK), style: .default))
        present(alert, animated: true)
    }

    private func debugFriendlyErrorMessage(_ error: Error) -> String {
        #if DEBUG
        let nsError = error as NSError
        return "\(error.localizedDescription)\n[\(nsError.domain):\(nsError.code)]\n\(Config.apiBaseURL)"
        #else
        return error.localizedDescription
        #endif
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case phoneTextField:
            codeTextField.becomeFirstResponder()
        case codeTextField:
            loginTapped()
        case emailTextField:
            passwordTextField.becomeFirstResponder()
        case passwordTextField:
            loginTapped()
        default:
            textField.resignFirstResponder()
        }
        return true
    }

}
