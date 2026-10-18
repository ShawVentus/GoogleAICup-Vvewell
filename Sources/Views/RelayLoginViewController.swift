import UIKit

/// Minimal login screen for authenticating with the relay server.
/// Uses email + password via Supabase Auth, proxied through the relay.
final class RelayLoginViewController: UIViewController, UITextFieldDelegate {

    private let themeColor = AppDesign.Color.primaryGreen
    var onLoginSuccess: (() -> Void)?
    var onCancel: (() -> Void)?
    var isRootEntry = false

    // MARK: - UI Elements

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Vvewell"
        l.font = .systemFont(ofSize: 32, weight: .bold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = t(.relayLoginSubtitle)
        l.font = .systemFont(ofSize: 15)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let endpointLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        l.textColor = .tertiaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let emailField: UITextField = {
        let tf = UITextField()
        tf.placeholder = t(.relayLoginEmailPlaceholder)
        tf.keyboardType = .emailAddress
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.textContentType = .username
        tf.clearButtonMode = .whileEditing
        tf.borderStyle = .roundedRect
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let passwordField: UITextField = {
        let tf = UITextField()
        tf.placeholder = t(.relayLoginPasswordPlaceholder)
        tf.isSecureTextEntry = true
        tf.textContentType = .password
        tf.returnKeyType = .go
        tf.borderStyle = .roundedRect
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private lazy var togglePasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "eye"), for: .normal)
        button.tintColor = .tertiaryLabel
        button.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        return button
    }()

    private lazy var loginButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(t(.loginTitle), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = themeColor
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.layer.cornerRadius = 12
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        return btn
    }()

    private let errorLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .systemRed
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = t(.loginTitle)
        #if DEBUG
        endpointLabel.text = "Relay: \(Config.apiBaseURL)"
        #else
        endpointLabel.isHidden = true
        #endif
        if !isRootEntry {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: t(.cancel),
                style: .plain,
                target: self,
                action: #selector(cancelTapped)
            )
        }
        emailField.delegate = self
        passwordField.delegate = self
        passwordField.rightView = togglePasswordButton
        passwordField.rightViewMode = .always
        setupUI()
        applyAccessibility()
    }

    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel, endpointLabel, emailField, passwordField, errorLabel, loginButton, activityIndicator
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(8, after: titleLabel)
        stack.setCustomSpacing(24, after: subtitleLabel)
        stack.setCustomSpacing(8, after: errorLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            emailField.heightAnchor.constraint(equalToConstant: 48),
            passwordField.heightAnchor.constraint(equalToConstant: 48),
            loginButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func applyAccessibility() {
        emailField.accessibilityLabel = t(.relayLoginEmailPlaceholder)
        passwordField.accessibilityLabel = t(.relayLoginPasswordPlaceholder)
        loginButton.accessibilityLabel = t(.loginTitle)
        loginButton.accessibilityHint = t(.relayLoginSubtitle)
        errorLabel.accessibilityTraits.insert(.staticText)
        togglePasswordButton.accessibilityLabel = passwordField.isSecureTextEntry ? t(.relayLoginShowPassword) : t(.relayLoginHidePassword)
    }

    // MARK: - Action

    @objc private func cancelTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onCancel?()
        }
    }

    @objc private func togglePasswordVisibility() {
        passwordField.isSecureTextEntry.toggle()
        let imageName = passwordField.isSecureTextEntry ? "eye" : "eye.slash"
        togglePasswordButton.setImage(UIImage(systemName: imageName), for: .normal)
        togglePasswordButton.accessibilityLabel = passwordField.isSecureTextEntry ? t(.relayLoginShowPassword) : t(.relayLoginHidePassword)
    }

    @objc private func loginTapped() {
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            showError("Please enter email and password")
            return
        }

        errorLabel.isHidden = true
        loginButton.isEnabled = false
        activityIndicator.startAnimating()

        Task {
            do {
                let result = try await performLogin(email: email, password: password)
                AuthTokenManager.shared.storeTokens(
                    access: result.accessToken,
                    refresh: result.refreshToken
                )
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.activityIndicator.stopAnimating()
                    if self.isRootEntry {
                        self.onLoginSuccess?()
                    } else {
                        self.dismiss(animated: true) {
                            self.onLoginSuccess?()
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.activityIndicator.stopAnimating()
                    self?.loginButton.isEnabled = true
                    self?.showError(self?.debugFriendlyErrorMessage(error) ?? error.localizedDescription)
                }
            }
        }
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailField {
            passwordField.becomeFirstResponder()
        } else if textField === passwordField {
            loginTapped()
        }
        return true
    }

    private func debugFriendlyErrorMessage(_ error: Error) -> String {
        #if DEBUG
        let nsError = error as NSError
        return "\(error.localizedDescription)\n[\(nsError.domain):\(nsError.code)]\n\(Config.apiBaseURL)"
        #else
        return error.localizedDescription
        #endif
    }

    // MARK: - Network

    private func performLogin(email: String, password: String) async throws -> APIClient.RelayLoginTokens {
        try await APIClient.shared.loginWithRelay(email: email, password: password)
    }
}

extension UIViewController {
    func makeRelayRootLoginController(onSuccess: @escaping () -> Void) -> UIViewController {
        let loginVC = LoginViewController(preferredLoginMode: .email)
        loginVC.onLoginSuccess = onSuccess
        let navigationController = UINavigationController(rootViewController: loginVC)
        navigationController.modalPresentationStyle = .fullScreen
        return navigationController
    }

    func makeConfiguredLoginController(
        onRelaySuccess: (() -> Void)? = nil,
        preferredLoginMode: LoginEntryMode = .phone
    ) -> UIViewController {
        let loginVC = LoginViewController(preferredLoginMode: preferredLoginMode)
        loginVC.onLoginSuccess = onRelaySuccess
        return loginVC
    }

    @discardableResult
    func ensureRelayFeatureAuthorization(onReady: @escaping () -> Void) -> Bool {
        guard Config.useRelay else {
            return true
        }

        guard !AuthTokenManager.shared.isLoggedIn else {
            return true
        }

        let topPresented = (presentedViewController as? UINavigationController)?.topViewController
        if presentedViewController is LoginViewController || topPresented is LoginViewController ||
            presentedViewController is RelayLoginViewController || topPresented is RelayLoginViewController {
            return false
        }

        let loginVC = LoginViewController(preferredLoginMode: .email)
        loginVC.onLoginSuccess = { [weak loginVC] in
            loginVC?.dismiss(animated: true, completion: onReady)
        }
        let navigationController = UINavigationController(rootViewController: loginVC)
        navigationController.modalPresentationStyle = .formSheet
        present(navigationController, animated: true)
        return false
    }
}
