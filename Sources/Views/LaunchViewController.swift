import UIKit

class LaunchViewController: UIViewController {
    private let content = UIStackView()
    private let logoView: UIImageView = {
        let image: UIImage? = {
            guard let url = Bundle.main.url(forResource: "vvewell-logo", withExtension: "png", subdirectory: "AvatarCoach") else { return nil }
            return UIImage(contentsOfFile: url.path)
        }()
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.accessibilityLabel = "Vvewell"
        return view
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "健康管理平台"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let spinner: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.color = AppDesign.Color.primaryGreen
        view.startAnimating()
        return view
    }()

    private let versionLabel: UILabel = {
        let label = UILabel()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        label.text = build.isEmpty ? "Version \(version)" : "Version \(version) (\(build))"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppDesign.Surface.canvasBackground
        setupUI()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        content.alpha = 0
        content.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 1.0, delay: 0.2, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.2, options: [.curveEaseInOut]) {
            self.content.alpha = 1
            self.content.transform = .identity
        }
        scheduleTransition()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        content.axis = .vertical
        content.alignment = .center
        content.spacing = 0
        content.translatesAutoresizingMaskIntoConstraints = false
        [logoView, spacer(28), subtitleLabel, spacer(40), spinner, spacer(48), versionLabel].forEach(content.addArrangedSubview)
#if DEBUG
        let debug = UILabel()
        debug.text = "DEBUG"
        debug.font = .systemFont(ofSize: 10, weight: .bold)
        debug.textColor = .systemOrange
        debug.textAlignment = .center
        debug.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.15)
        debug.layer.cornerRadius = 6
        debug.layer.masksToBounds = true
        debug.widthAnchor.constraint(equalToConstant: 58).isActive = true
        debug.heightAnchor.constraint(equalToConstant: 24).isActive = true
        content.addArrangedSubview(spacer(8))
        content.addArrangedSubview(debug)
#endif
        view.addSubview(content)

        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 34),
            content.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -34),
            logoView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.78),
            logoView.heightAnchor.constraint(equalToConstant: 94),
            spinner.widthAnchor.constraint(equalToConstant: 22),
            spinner.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    private func spacer(_ height: CGFloat) -> UIView {
        let view = UIView()
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    @objc private func languageChanged() {
        subtitleLabel.text = LocaleManager.shared.current == .en ? "Health management platform" : "健康管理平台"
    }

    private func scheduleTransition() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            Task { [weak self] in
                await self?.transitionToMain()
            }
        }
    }

    private func transitionToMain() async {
        guard let window = view.window else { return }

        let destination: UIViewController
        if Config.useRelay {
            let refreshed = AuthTokenManager.shared.refreshToken != nil
                ? await AuthTokenManager.shared.refreshAccessToken()
                : false
            let relayAuthenticated = AuthTokenManager.shared.accessToken != nil || refreshed
            if relayAuthenticated || AuthManager.shared.isLoggedIn {
                destination = MainTabBarController()
            } else {
                destination = makeConfiguredLoginController { [weak window] in
                    guard let window else { return }
                    UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
                        window.rootViewController = MainTabBarController()
                    }
                }
            }
        } else {
            if AuthManager.shared.isLoggedIn {
                destination = MainTabBarController()
            } else {
                destination = makeConfiguredLoginController()
            }
        }

        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
            window.rootViewController = destination
        }
    }
}
