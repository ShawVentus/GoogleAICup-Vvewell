import UIKit
import Combine

class ProfileViewController: UIViewController {

    private let themeColor = AppDesign.Color.primaryGreen
    private let cardBackgroundColor: UIColor = .systemBackground
    private let deviceManager = DeviceManager.shared
    private var rowActionStore: [() -> Void] = []
    private var cancellables = Set<AnyCancellable>()
    var sessionResetCoordinator: UserScopedResetting = AppSessionResetComposer.makeDefaultCoordinator()

    // MARK: - Scroll View

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        return sv
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = true
        return stack
    }()

    // MARK: - Header

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var settingsButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        button.setImage(UIImage(systemName: "gearshape", withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = .secondarySystemBackground
        setupScrollView()
        setupHeader()
        updateTexts()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: .appThemeDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(accountContextChanged), name: .authTokenDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(accountContextChanged), name: .userProfileDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(accountContextChanged), name: .healthRecordsDidUpdate, object: nil)
        ProfileManager.shared.profilesChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.accountContextChanged() }
            .store(in: &cancellables)
        deviceManager.connectionStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.accountContextChanged() }
            .store(in: &cancellables)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        updateTextsPreservingScrollOffset()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Scroll View Setup

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Header Setup

    private func setupHeader() {
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        headerView.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            headerView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),

            settingsButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            settingsButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        contentStack.addArrangedSubview(headerView)
    }

    // MARK: - Build Content

    private func buildContent() {
        // Profile card
        contentStack.addArrangedSubview(makeProfileCard())

        // Stats row
        contentStack.addArrangedSubview(makeStatsRow())

        // My Services section
        contentStack.addArrangedSubview(makeSectionHeader(t(.profileSectionServices)))
        contentStack.addArrangedSubview(makeSectionCard([
            RowItem(icon: "clipboard", iconBg: AppDesign.Color.primaryGreen, title: t(.profileMyOrders), action: { [weak self] in self?.navigationController?.pushViewController(AndroidOrdersViewController(), animated: true) }),
            RowItem(icon: "heart", iconBg: UIColor(red: 0.95, green: 0.4, blue: 0.45, alpha: 1.0), title: t(.profileMyFavorites), action: { [weak self] in self?.navigationController?.pushViewController(AndroidBenefitsViewController(), animated: true) }),
            RowItem(icon: "creditcard", iconBg: UIColor(red: 0.3, green: 0.5, blue: 0.85, alpha: 1.0), title: t(.profileInsurance), action: { [weak self] in self?.navigationController?.pushViewController(MedicalHubViewController(), animated: true) }),
        ]))

        // Health Management section
        contentStack.addArrangedSubview(makeSectionHeader(t(.profileSectionHealth)))
        contentStack.addArrangedSubview(makeSectionCard([
            RowItem(icon: "iphone", iconBg: UIColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1.0), title: t(.profileMyDevices), detail: String(format: t(.profileDevicesConnectedFormat), currentPairedDeviceCount()), tag: 1),
            RowItem(icon: "doc.text", iconBg: UIColor(red: 0.2, green: 0.6, blue: 0.8, alpha: 1.0), title: t(.profileHealthReports), detail: String(format: t(.profileStatCheckupsFormat), currentCheckupCount()), action: { [weak self] in
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                self?.navigationController?.pushViewController(OcrHistoryListViewController(dateFormatter: formatter), animated: true)
            }),
            RowItem(icon: "person.text.rectangle", iconBg: UIColor(red: 0.9, green: 0.55, blue: 0.3, alpha: 1.0), title: t(.healthProfileBasicInfo), detail: currentBasicHealthInfoSummary(), action: { [weak self] in
                let vc = HealthProfileEditViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            }),
            RowItem(icon: "person.2", iconBg: AppDesign.Color.primaryGreen, title: t(.healthProfileFamilyProfiles), detail: String(format: "%d 位成员", currentFamilyProfileCount()), action: { [weak self] in
                self?.navigationController?.pushViewController(FamilyProfilesViewController(), animated: true)
            }),
        ]))

        // Settings section
        contentStack.addArrangedSubview(makeSectionHeader(t(.profileSectionSettings)))
        contentStack.addArrangedSubview(makeSectionCard([
            RowItem(icon: "globe", iconBg: UIColor(red: 0.2, green: 0.7, blue: 0.65, alpha: 1.0), title: t(.profileLanguage), detail: currentLanguageDisplayName(), action: { [weak self] in self?.navigationController?.pushViewController(AndroidLanguageSettingsViewController(), animated: true) }),
            RowItem(icon: "circle.lefthalf.filled", iconBg: UIColor(red: 0.35, green: 0.45, blue: 0.9, alpha: 1.0), title: t(.profileTheme), detail: ThemeManager.shared.current.title(), action: { [weak self] in self?.showThemePicker() }),
            RowItem(icon: "bell", iconBg: UIColor(red: 0.95, green: 0.65, blue: 0.25, alpha: 1.0), title: t(.profileNotifications), action: { [weak self] in self?.navigationController?.pushViewController(AndroidNotificationSettingsViewController(), animated: true) }),
            RowItem(icon: "shield", iconBg: AppDesign.Color.primaryGreen, title: t(.profilePrivacy), action: { [weak self] in
                self?.presentProfileInfo(title: t(.profilePrivacy), message: "隐私设置由本地健康数据、相机和蓝牙权限共同管理。应用不会在未确认时上传演示数据。")
            }),
            RowItem(icon: "questionmark.circle", iconBg: UIColor(red: 0.3, green: 0.5, blue: 0.85, alpha: 1.0), title: t(.profileHelp), action: { [weak self] in
                self?.presentProfileInfo(title: t(.profileHelp), message: "请从设备中心、健康检测或症状咨询入口开始。需要制造商 SDK 的设备会明确标注不可用原因。")
            }),
        ]))

        // Sign Out button
        contentStack.addArrangedSubview(makeSignOutButton())

        // Footer
        contentStack.addArrangedSubview(makeFooter())
    }

    // MARK: - Profile Card

    private func makeProfileCard() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = cardBackgroundColor
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        // Avatar
        let avatarSize: CGFloat = 56
        let avatarView = UIView()
        avatarView.backgroundColor = themeColor.withAlphaComponent(0.15)
        avatarView.layer.cornerRadius = avatarSize / 2
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        let avatarLabel = UILabel()
        avatarLabel.text = currentAccountAvatarSymbol()
        avatarLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        avatarLabel.textColor = themeColor
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(avatarLabel)
        card.addSubview(avatarView)

        // Name & Email
        let nameLabel = UILabel()
        nameLabel.text = currentAccountDisplayName()
        nameLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.textAlignment = .natural
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(nameLabel)

        let emailLabel = UILabel()
        emailLabel.text = currentAccountSubtitle()
        emailLabel.font = .systemFont(ofSize: 13, weight: .regular)
        emailLabel.textColor = .secondaryLabel
        emailLabel.textAlignment = .natural
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(emailLabel)

        // Badges
        let badgeStack = UIStackView()
        badgeStack.axis = .horizontal
        badgeStack.spacing = 8
        badgeStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(badgeStack)

        let scopeBadge = makeBadge(
            text: currentAccountScopeText(),
            bgColor: currentAccountScopeColor().withAlphaComponent(0.14),
            textColor: currentAccountScopeColor()
        )
        badgeStack.addArrangedSubview(scopeBadge)

        let familyBadge = makeBadge(
            text: String(format: t(.healthProfileFamilyProfilesCountFormat), t(.healthProfileFamilyProfiles), currentFamilyProfileCount()),
            bgColor: UIColor.tertiarySystemFill,
            textColor: .secondaryLabel
        )
        badgeStack.addArrangedSubview(familyBadge)

        // Chevron
        let chevron = UIImageView(image: directionalChevronImage(pointSize: 12))
        chevron.tintColor = .tertiaryLabel
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        card.addSubview(chevron)

        let tapButton = UIButton(type: .system)
        tapButton.translatesAutoresizingMaskIntoConstraints = false
        tapButton.backgroundColor = .clear
        tapButton.accessibilityLabel = localizedAccountSummary()
        tapButton.accessibilityHint = t(.healthProfileFamilyProfiles)
        tapButton.addTarget(self, action: #selector(accountCardTapped), for: .touchUpInside)
        card.addSubview(tapButton)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            avatarView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            avatarView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            avatarView.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarView.heightAnchor.constraint(equalToConstant: avatarSize),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: 2),

            emailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),

            badgeStack.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            badgeStack.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 8),
            badgeStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            tapButton.topAnchor.constraint(equalTo: card.topAnchor),
            tapButton.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            tapButton.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            tapButton.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        container.accessibilityLabel = localizedAccountSummary()
        return container
    }

    private func currentAccountDisplayName() -> String {
        if let owner = try? ProfileManager.shared.ownerProfile(),
           !owner.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return owner.name
        }

        let profile = UserProfileRepository.shared.fetch()
        let localName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !localName.isEmpty {
            return localName
        }

        if let email = AuthTokenManager.shared.currentEmail {
            let prefix = email.split(separator: "@").first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !prefix.isEmpty {
                return prefix
            }
        }

        if AuthManager.shared.isLoggedIn, let phone = AuthManager.shared.phoneNumber, !phone.isEmpty {
            return phone
        }

        return t(.profileGuestUser)
    }

    private func currentAccountSubtitle() -> String {
        let relayEmail = AuthTokenManager.shared.currentEmail
        let hasPhoneLogin = AuthManager.shared.isLoggedIn && ((AuthManager.shared.phoneNumber?.isEmpty == false))
        if let email = relayEmail {
            if hasPhoneLogin {
                return String(format: t(.profileDualSignedInFormat), email)
            }
            return email
        }
        if hasPhoneLogin, let phone = AuthManager.shared.phoneNumber, !phone.isEmpty {
            return t(.profilePhoneSignedIn)
        }
        if Config.useRelay {
            return t(.syncStatusRequiresLogin)
        }
        return t(.healthProfileLocalOnly)
    }

    private func currentAccountAvatarSymbol() -> String {
        let candidate = currentAccountDisplayName().trimmingCharacters(in: .whitespacesAndNewlines)
        if let scalar = candidate.unicodeScalars.first {
            return String(Character(scalar)).uppercased()
        }
        let fallback = t(.profileGuestUser).trimmingCharacters(in: .whitespacesAndNewlines)
        if let scalar = fallback.unicodeScalars.first {
            return String(Character(scalar)).uppercased()
        }
        return "•"
    }

    private func currentAccountScopeText() -> String {
        if Config.useRelay && AuthTokenManager.shared.isLoggedIn && AuthManager.shared.isLoggedIn {
            return t(.healthProfileHybridMode)
        }
        if Config.useRelay && AuthTokenManager.shared.isLoggedIn {
            return t(.healthProfileCloudConnected)
        }
        if AuthManager.shared.isLoggedIn {
            return t(.healthProfilePhoneLocalMode)
        }
        return t(.healthProfileLocalOnly)
    }

    private func currentAccountScopeColor() -> UIColor {
        (Config.useRelay && AuthTokenManager.shared.isLoggedIn) ? themeColor : .secondaryLabel
    }

    private func currentFamilyProfileCount() -> Int {
        (try? ProfileManager.shared.allProfiles().count) ?? 0
    }

    private func currentCheckupCount() -> Int {
        HealthRecordRepository.shared.fetchAll().count
    }

    private func currentBasicHealthInfoSummary() -> String {
        let profile = UserProfileRepository.shared.fetch()
        let owner = try? ProfileManager.shared.ownerProfile()

        let birthdayText: String? = {
            if let birthday = profile.birthday {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter.string(from: birthday)
            }
            if let year = owner?.birthYear {
                return String(year)
            }
            return nil
        }()

        let genderRaw = !profile.gender.isEmpty ? profile.gender : (owner?.gender?.rawValue ?? "")
        let genderText: String? = {
            switch genderRaw {
            case "male": return t(.healthProfileGenderMale)
            case "female": return t(.healthProfileGenderFemale)
            case "other": return t(.healthProfileGenderOther)
            default: return nil
            }
        }()

        let height = profile.heightCm ?? owner?.heightCm
        let weight = profile.weightKg ?? owner?.weightKg
        let bloodType = profile.bloodType.isEmpty ? owner?.bloodType : profile.bloodType

        let parts = [
            genderText,
            birthdayText,
            height.map { "\(Int($0.rounded())) \(t(.unitCentimeters))" },
            weight.map { "\(Int($0.rounded())) \(t(.unitKilograms))" },
            bloodType?.isEmpty == false ? bloodType : nil
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
         .filter { !$0.isEmpty }

        if parts.isEmpty {
            return t(.healthProfileNotFilled)
        }

        let formatter = ListFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        return formatter.string(from: Array(parts.prefix(3))) ?? parts.prefix(3).joined(separator: " · ")
    }

    private func currentPairedDeviceCount() -> Int {
        deviceManager.registeredTypes.filter { type in
            deviceManager.device(for: type)?.isPaired() == true
        }.count
    }

    private func localizedAccountSummary() -> String {
        let parts = [currentAccountDisplayName(), currentAccountSubtitle(), currentAccountScopeText()]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let formatter = ListFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        return formatter.string(from: parts) ?? parts.joined(separator: ", ")
    }

    private func makeBadge(text: String, bgColor: UIColor, textColor: UIColor) -> UIView {
        let badge = UIView()
        badge.backgroundColor = bgColor
        badge.layer.cornerRadius = 10
        badge.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = textColor
        label.textAlignment = .natural
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: badge.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -4),
        ])

        return badge
    }

    // MARK: - Stats Row

    private func makeStatsRow() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        stack.addArrangedSubview(makeStatItem(value: String(currentCheckupCount()), label: t(.profileStatCheckups), color: themeColor))
        stack.addArrangedSubview(makeStatItem(value: String(currentFamilyProfileCount()), label: t(.profileStatOrders), color: UIColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1.0)))
        stack.addArrangedSubview(makeStatItem(value: String(currentPairedDeviceCount()), label: t(.profileStatDevices), color: UIColor(red: 0.3, green: 0.5, blue: 0.85, alpha: 1.0)))

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func makeStatItem(value: String, label: String, color: UIColor) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        valueLabel.textColor = color

        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .natural

        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(titleLabel)

        return stack
    }

    // MARK: - Section Header

    private func makeSectionHeader(_ title: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .natural
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - Section Card

    private struct RowItem {
        let icon: String
        let iconBg: UIColor
        let title: String
        var badge: String? = nil
        var detail: String? = nil
        var verifiedBadge: Bool = false
        var tag: Int = 0
        var action: (() -> Void)? = nil
    }

    private func makeSectionCard(_ rows: [RowItem]) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = true

        let card = UIView()
        card.backgroundColor = cardBackgroundColor
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        card.isUserInteractionEnabled = true
        container.addSubview(card)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = true
        card.addSubview(stack)

        for (index, row) in rows.enumerated() {
            stack.addArrangedSubview(makeRow(row))
            if index < rows.count - 1 {
                stack.addArrangedSubview(makeSeparator())
            }
        }

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return container
    }

    private func makeRow(_ item: RowItem) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        if item.tag > 0 {
            row.tag = item.tag
            row.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleRowTap(_:)))
            row.addGestureRecognizer(tap)
        }

        // Icon background circle
        let iconSize: CGFloat = 36
        let iconContainer = UIView()
        iconContainer.backgroundColor = item.iconBg.withAlphaComponent(0.12)
        iconContainer.layer.cornerRadius = iconSize / 2
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconContainer)

        let iconView = UIImageView(image: UIImage(systemName: item.icon))
        iconView.tintColor = item.iconBg
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .natural
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(titleLabel)

        // Chevron
        let chevron = UIImageView(image: directionalChevronImage(pointSize: 12))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(chevron)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 56),

            iconContainer.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: iconSize),
            iconContainer.heightAnchor.constraint(equalToConstant: iconSize),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 12),
        ])

        // Badge (numeric, like "3")
        if let badge = item.badge {
            let badgeLabel = UILabel()
            badgeLabel.text = badge
            badgeLabel.font = .systemFont(ofSize: 12, weight: .medium)
            badgeLabel.textColor = .secondaryLabel
            badgeLabel.textAlignment = .center
            badgeLabel.backgroundColor = UIColor.tertiarySystemFill
            badgeLabel.layer.cornerRadius = 10
            badgeLabel.clipsToBounds = true
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(badgeLabel)

            NSLayoutConstraint.activate([
                badgeLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
                badgeLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
                badgeLabel.heightAnchor.constraint(equalToConstant: 20),
            ])
        }

        // Detail text (like "2 connected", "English")
        if let detail = item.detail {
            let detailLabel = UILabel()
            detailLabel.text = detail
            detailLabel.font = .systemFont(ofSize: 13, weight: .regular)
            detailLabel.textColor = .secondaryLabel
            detailLabel.textAlignment = .natural
            detailLabel.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(detailLabel)

            NSLayoutConstraint.activate([
                detailLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
                detailLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])
        }

        // Verified badge
        if item.verifiedBadge {
            let verifiedView = UIView()
            verifiedView.backgroundColor = themeColor.withAlphaComponent(0.12)
            verifiedView.layer.cornerRadius = 10
            verifiedView.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(verifiedView)

            let verifiedLabel = UILabel()
            verifiedLabel.text = t(.profileVerified)
            verifiedLabel.font = .systemFont(ofSize: 11, weight: .medium)
            verifiedLabel.textColor = themeColor
            verifiedLabel.textAlignment = .natural
            verifiedLabel.translatesAutoresizingMaskIntoConstraints = false
            verifiedView.addSubview(verifiedLabel)

            NSLayoutConstraint.activate([
                verifiedView.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
                verifiedView.centerYAnchor.constraint(equalTo: row.centerYAnchor),

                verifiedLabel.leadingAnchor.constraint(equalTo: verifiedView.leadingAnchor, constant: 8),
                verifiedLabel.trailingAnchor.constraint(equalTo: verifiedView.trailingAnchor, constant: -8),
                verifiedLabel.topAnchor.constraint(equalTo: verifiedView.topAnchor, constant: 4),
                verifiedLabel.bottomAnchor.constraint(equalTo: verifiedView.bottomAnchor, constant: -4),
            ])
        }

        if let action = item.action {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.backgroundColor = .clear
            button.tag = rowActionStore.count
            button.accessibilityIdentifier = "profile-row-\(item.title)"
            rowActionStore.append(action)
            button.addTarget(self, action: #selector(rowButtonTapped(_:)), for: .touchUpInside)
            row.addSubview(button)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: row.topAnchor),
                button.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                button.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            ])
        }

        return row
    }

    @objc private func rowButtonTapped(_ sender: UIButton) {
        guard sender.tag < rowActionStore.count else { return }
        rowActionStore[sender.tag]()
    }

    private func presentProfileInfo(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
        present(alert, animated: true)
    }

    @objc private func handleRowTap(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag else { return }
        switch tag {
        case 1:
            let vc = DeviceCenterViewController()
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }

    private func makeSeparator() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let line = UIView()
        line.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 0.5),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 64),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - Sign Out Button

    private func makeSignOutButton() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.08)
        button.layer.cornerRadius = 24
        button.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)

        let iconView = UIImageView(image: UIImage(systemName: "rectangle.portrait.and.arrow.right"))
        iconView.tintColor = .systemRed
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = t(.profileLogout)
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .systemRed
        titleLabel.textAlignment = .natural
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let hStack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        hStack.axis = .horizontal
        hStack.spacing = 8
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.isUserInteractionEnabled = false
        button.addSubview(hStack)

        container.addSubview(button)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 48),

            hStack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            hStack.centerYAnchor.constraint(equalTo: button.centerYAnchor),

            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
        ])

        return container
    }

    // MARK: - Footer

    private func makeFooter() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let versionLabel = UILabel()
        versionLabel.text = appVersionText()
        versionLabel.font = .systemFont(ofSize: 12, weight: .regular)
        versionLabel.textColor = .tertiaryLabel

        let copyrightLabel = UILabel()
        copyrightLabel.text = t(.profileCopyrightLabel)
        copyrightLabel.font = .systemFont(ofSize: 12, weight: .regular)
        copyrightLabel.textColor = .tertiaryLabel

        stack.addArrangedSubview(versionLabel)
        stack.addArrangedSubview(copyrightLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -32),
        ])

        return container
    }

    private func appVersionText() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let combined: String
        switch (version, build) {
        case let (.some(v), .some(b)) where !v.isEmpty && !b.isEmpty && v != b:
            combined = "\(v) (\(b))"
        case let (.some(v), _ ) where !v.isEmpty:
            combined = v
        case let (_, .some(b)) where !b.isEmpty:
            combined = b
        default:
            combined = "1.0.0"
        }
        return String(format: t(.profileVersionFormat), combined)
    }

    // MARK: - 语言切换

    private func updateTexts() {
        titleLabel.text = t(.profileTitle)
        titleLabel.textAlignment = .natural
        subtitleLabel.text = t(.profileSubtitle)
        subtitleLabel.textAlignment = .natural
        rowActionStore.removeAll()
        clearContentSections()
        buildContent()
    }

    private func clearContentSections() {
        contentStack.arrangedSubviews.dropFirst().forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func updateTextsPreservingScrollOffset() {
        let previousOffset = scrollView.contentOffset
        updateTexts()
        view.layoutIfNeeded()

        let maxOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let clampedOffset = CGPoint(
            x: max(0, previousOffset.x),
            y: min(max(0, previousOffset.y), maxOffsetY)
        )
        scrollView.setContentOffset(clampedOffset, animated: false)
    }

    @objc private func languageChanged() {
        updateTexts()
    }

    @objc private func themeChanged() {
        updateTexts()
    }

    @objc private func accountContextChanged() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.accountContextChanged()
            }
            return
        }
        updateTextsPreservingScrollOffset()
    }

    // MARK: - Actions

    private func currentLanguageDisplayName() -> String {
        LocaleManager.shared.current.localizedDisplayName
    }

    @objc private func showLanguagePicker() {
        let sheet = UIAlertController(title: t(.profileLanguage), message: nil, preferredStyle: .actionSheet)
        let languages: [(String, AppLanguage)] = AppLanguage.allCases.map { ($0.localizedDisplayName, $0) }
        for (name, lang) in languages {
            let action = UIAlertAction(title: name, style: .default) { _ in
                LocaleManager.shared.setLanguage(lang)
            }
            if LocaleManager.shared.current == lang {
                action.setValue(true, forKey: "checked")
            }
            sheet.addAction(action)
        }
        sheet.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        present(sheet, animated: true)
    }

    private func showThemePicker() {
        let sheet = UIAlertController(title: t(.profileTheme), message: nil, preferredStyle: .actionSheet)
        AppTheme.allCases.forEach { theme in
            let action = UIAlertAction(title: theme.title(), style: .default) { _ in
                ThemeManager.shared.setTheme(theme)
            }
            if ThemeManager.shared.current == theme {
                action.setValue(true, forKey: "checked")
            }
            sheet.addAction(action)
        }
        sheet.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        present(sheet, animated: true)
    }

    @objc private func settingsTapped() {
        navigationController?.pushViewController(AndroidNotificationSettingsViewController(), animated: true)
    }

    @objc private func accountCardTapped() {
        let vc = FamilyProfilesViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func logoutTapped() {
        let alert = UIAlertController(title: t(.profileLogoutConfirmTitle), message: t(.profileLogoutConfirmMessage), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        alert.addAction(UIAlertAction(title: t(.profileLogoutConfirmAction), style: .destructive) { [weak self] _ in
            self?.performLogout()
        })
        present(alert, animated: true)
    }

    @objc private func performLogout() {
        AuthManager.shared.logout()
        AuthTokenManager.shared.clearTokens()
        sessionResetCoordinator.resetUserScopedData()

        guard let window = view.window else { return }
        let loginVC = makeConfiguredLoginController { [weak window] in
            guard let window else { return }
            UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
                window.rootViewController = MainTabBarController()
            }
        }
        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
            window.rootViewController = loginVC
        }
    }
}
