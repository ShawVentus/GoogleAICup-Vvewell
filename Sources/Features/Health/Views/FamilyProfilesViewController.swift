import UIKit
import Combine

final class FamilyProfilesViewController: UIViewController, UIGestureRecognizerDelegate {
    private var cancellables = Set<AnyCancellable>()
    private var isCloudRefreshInFlight = false
    private lazy var manageButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: t(.healthProfileManageFamily), style: .plain, target: self, action: #selector(manageTapped))
        item.accessibilityLabel = t(.healthProfileManageFamily)
        return item
    }()
    private lazy var addButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addProfileTapped))
        item.accessibilityLabel = t(.healthProfileAddFamily)
        return item
    }()
    private lazy var refreshButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: t(.healthProfileRefreshCloud), style: .plain, target: self, action: #selector(refreshCloudTapped))
        item.accessibilityLabel = t(.healthProfileRefreshCloud)
        return item
    }()

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = t(.healthProfileFamilyProfiles)
        configureBackButtonIfNeeded()
        enableInteractiveBackSwipeIfNeeded()
        navigationItem.rightBarButtonItems = [addButtonItem, refreshButtonItem, manageButtonItem]

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])

        ProfileManager.shared.profilesChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.refreshContent() }
            .store(in: &cancellables)
        NotificationCenter.default.addObserver(self, selector: #selector(authTokenChanged), name: .authTokenDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(activeProfileChanged), name: .activeHealthProfileDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
        updateRefreshButtonState()
        refreshContent()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureBackButtonIfNeeded() {
        guard navigationController?.viewControllers.first !== self else { return }
        let item = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
        item.accessibilityLabel = t(.back)
        navigationItem.leftBarButtonItem = item
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    private func enableInteractiveBackSwipeIfNeeded() {
        guard navigationController?.viewControllers.first !== self else { return }
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }

    @objc private func authTokenChanged() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.authTokenChanged()
            }
            return
        }
        updateRefreshButtonState()
        refreshContent()
    }

    @objc private func activeProfileChanged() {
        refreshContent()
    }

    @objc private func languageChanged() {
        title = t(.healthProfileFamilyProfiles)
        addButtonItem.accessibilityLabel = t(.healthProfileAddFamily)
        refreshButtonItem.title = t(.healthProfileRefreshCloud)
        refreshButtonItem.accessibilityLabel = t(.healthProfileRefreshCloud)
        manageButtonItem.title = t(.healthProfileManageFamily)
        manageButtonItem.accessibilityLabel = t(.healthProfileManageFamily)
        refreshContent()
    }

    @objc private func addProfileTapped() {
        let alert = UIAlertController(title: t(.healthProfileAddFamily), message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileName)
        }
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileBirthday)
            textField.keyboardType = .numberPad
        }
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileGender)
        }
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileHeight)
            textField.keyboardType = .decimalPad
        }
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileWeight)
            textField.keyboardType = .decimalPad
        }
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileBloodType)
        }
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        alert.addAction(UIAlertAction(title: t(.confirm), style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let enteredName = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let birthYearText = alert?.textFields?.dropFirst().first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let genderText = alert?.textFields?.dropFirst(2).first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let heightText = alert?.textFields?.dropFirst(3).first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let weightText = alert?.textFields?.dropFirst(4).first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let bloodTypeText = alert?.textFields?.dropFirst(5).first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.presentRelationshipPicker(
                prefilledName: enteredName,
                prefilledBirthYear: Int(birthYearText),
                prefilledGender: self.parseGenderInput(genderText),
                prefilledHeightCm: self.parseLocalizedDouble(heightText),
                prefilledWeightKg: self.parseLocalizedDouble(weightText),
                prefilledBloodType: bloodTypeText.isEmpty ? nil : bloodTypeText
            )
        })
        present(alert, animated: true)
    }

    @objc private func refreshCloudTapped() {
        guard !isCloudRefreshInFlight else { return }
        guard Config.useRelay, AuthTokenManager.shared.isLoggedIn else {
            let message = AuthManager.shared.isLoggedIn ? t(.healthProfileRefreshRequiresEmailLogin) : t(.healthProfileRefreshRequiresLogin)
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
            present(alert, animated: true)
            return
        }

        isCloudRefreshInFlight = true
        refreshButtonItem.isEnabled = false
        Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor [weak self] in
                    self?.isCloudRefreshInFlight = false
                    self?.updateRefreshButtonState()
                }
            }

            do {
                try await ProfileManager.shared.mergeProfilesFromCloud()
                await MainActor.run {
                    self.refreshContent()
                }
            } catch {
                await MainActor.run {
                    let alert = UIAlertController(title: nil, message: t(.healthProfileRefreshFailed), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    @objc private func manageTapped() {
        let clearableProfiles = removableProfiles()
        guard !clearableProfiles.isEmpty else {
            let alert = UIAlertController(title: nil, message: t(.healthProfileNoOtherProfiles), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
            present(alert, animated: true)
            return
        }

        let sheet = UIAlertController(title: t(.healthProfileManageFamily), message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: t(.healthProfileClearOtherProfiles), style: .destructive) { [weak self] _ in
            self?.clearOtherProfiles(clearableProfiles)
        })
        sheet.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.barButtonItem = manageButtonItem
        }
        present(sheet, animated: true)
    }

    private func refreshContent() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let scope: String
        if Config.useRelay && AuthTokenManager.shared.isLoggedIn && AuthManager.shared.isLoggedIn {
            scope = t(.healthProfileHybridMode)
        } else if Config.useRelay && AuthTokenManager.shared.isLoggedIn {
            scope = t(.healthProfileCloudConnected)
        } else if AuthManager.shared.isLoggedIn {
            scope = t(.healthProfilePhoneLocalMode)
        } else {
            scope = t(.healthProfileLocalOnly)
        }
        let count = (try? ProfileManager.shared.allProfiles().count) ?? 0
        stackView.addArrangedSubview(makeOverviewCard(count: count, scope: scope))

        let profiles = (try? ProfileManager.shared.allProfiles()) ?? []
        if profiles.isEmpty {
            manageButtonItem.isEnabled = false
            stackView.addArrangedSubview(makeEmptyStateCard())
            return
        }

        for profile in profiles {
            stackView.addArrangedSubview(makeProfileCard(profile))
        }
        manageButtonItem.isEnabled = !removableProfiles().isEmpty
    }

    private func updateRefreshButtonState() {
        refreshButtonItem.isEnabled = !isCloudRefreshInFlight
    }

    private func removableProfiles() -> [HealthProfile] {
        ((try? ProfileManager.shared.allProfiles()) ?? []).filter { $0.relationship != .owner }
    }

    private func presentRelationshipPicker(
        prefilledName: String,
        prefilledBirthYear: Int?,
        prefilledGender: Gender?,
        prefilledHeightCm: Double?,
        prefilledWeightKg: Double?,
        prefilledBloodType: String?
    ) {
        let alert = UIAlertController(title: t(.healthProfileAddFamily), message: t(.healthProfileFamilyProfiles), preferredStyle: .actionSheet)
        let relationships: [Relationship] = [.spouse, .parent, .child, .other]
        for relationship in relationships {
            alert.addAction(UIAlertAction(title: relationDisplay(relationship), style: .default) { [weak self] _ in
                guard let self else { return }
                let resolvedName = prefilledName.isEmpty ? self.relationDisplay(relationship) : prefilledName
                let profile = HealthProfile(
                    name: resolvedName,
                    relationship: relationship,
                    birthYear: prefilledBirthYear,
                    gender: prefilledGender,
                    heightCm: prefilledHeightCm,
                    weightKg: prefilledWeightKg,
                    bloodType: prefilledBloodType
                )
                try? ProfileManager.shared.addProfile(profile)
                self.refreshContent()
            })
        }
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = addButtonItem
        }
        present(alert, animated: true)
    }

    private func makeProfileCard(_ profile: HealthProfile) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 20
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 5)
        card.layer.shadowRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false
        card.accessibilityIdentifier = profile.id

        let activeProfileID: String?
        if let activeProfile = try? ProfileManager.shared.activeProfile() {
            activeProfileID = activeProfile.id
        } else {
            activeProfileID = nil
        }
        let isActiveProfile = profile.id == activeProfileID
        card.layer.borderWidth = isActiveProfile ? 1.5 : 0
        card.layer.borderColor = isActiveProfile ? AppDesign.Color.primaryGreen.cgColor : UIColor.clear.cgColor

        let tap = UITapGestureRecognizer(target: self, action: #selector(profileCardTapped(_:)))
        tap.delegate = self
        card.addGestureRecognizer(tap)

        let avatarWrap = UIView()
        avatarWrap.backgroundColor = AppDesign.Color.primaryGreen.withAlphaComponent(0.12)
        avatarWrap.layer.cornerRadius = 22
        avatarWrap.translatesAutoresizingMaskIntoConstraints = false

        let avatarLabel = UILabel()
        avatarLabel.font = .systemFont(ofSize: 18, weight: .bold)
        avatarLabel.textColor = AppDesign.Color.primaryGreen
        avatarLabel.textAlignment = .center
        avatarLabel.text = avatarInitial(for: profile)
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarWrap.addSubview(avatarLabel)

        let nameLabel = UILabel()
        nameLabel.font = .systemFont(ofSize: 17, weight: .bold)
        nameLabel.textColor = .label
        nameLabel.text = profile.name.isEmpty ? relationDisplay(profile.relationship) : profile.name
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let badgeRow = UIStackView()
        badgeRow.axis = .horizontal
        badgeRow.spacing = 8
        badgeRow.alignment = .center
        badgeRow.translatesAutoresizingMaskIntoConstraints = false
        badgeRow.addArrangedSubview(makeProfileBadge(text: relationDisplay(profile.relationship), tint: .secondaryLabel))
        if isActiveProfile {
            badgeRow.addArrangedSubview(makeProfileBadge(text: t(.symptomChatHistoryCurrentBadge), tint: AppDesign.Color.primaryGreen))
        }
        if profile.relationship == .owner {
            let ownerScope: String
            if Config.useRelay && AuthTokenManager.shared.isLoggedIn && AuthManager.shared.isLoggedIn {
                ownerScope = t(.healthProfileHybridMode)
            } else if Config.useRelay && AuthTokenManager.shared.isLoggedIn {
                ownerScope = t(.healthProfileCloudConnected)
            } else if AuthManager.shared.isLoggedIn {
                ownerScope = t(.healthProfilePhoneLocalMode)
            } else {
                ownerScope = t(.healthProfileLocalOnly)
            }
            badgeRow.addArrangedSubview(makeProfileBadge(text: ownerScope, tint: AppDesign.Color.primaryGreen))
        }

        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle(t(.healthProfileDeleteFamily), for: .normal)
        deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        deleteButton.isHidden = profile.relationship == .owner
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.accessibilityIdentifier = profile.id
        deleteButton.addTarget(self, action: #selector(deleteProfileTapped(_:)), for: .touchUpInside)

        let editButton = UIButton(type: .system)
        editButton.setTitle(t(.healthProfileEdit), for: .normal)
        editButton.setTitleColor(AppDesign.Color.primaryGreen, for: .normal)
        editButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.accessibilityIdentifier = profile.id
        editButton.addTarget(self, action: #selector(editFamilyProfileTapped(_:)), for: .touchUpInside)

        let actionsStack = UIStackView(arrangedSubviews: [editButton, deleteButton])
        actionsStack.axis = .horizontal
        actionsStack.spacing = 8
        actionsStack.alignment = .center
        actionsStack.translatesAutoresizingMaskIntoConstraints = false

        let detailLabel = UILabel()
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        var parts: [String] = []
        if let birthYear = profile.birthYear {
            parts.append(String(birthYear))
        }
        if let gender = profile.gender {
            parts.append(genderDisplay(gender))
        }
        if let heightCm = profile.heightCm {
            parts.append("\(localizedWholeNumberString(heightCm) ?? String(Int(heightCm))) \(t(.unitCentimeters))")
        }
        if let weightKg = profile.weightKg {
            parts.append("\(localizedWholeNumberString(weightKg) ?? String(Int(weightKg))) \(t(.unitKilograms))")
        }
        if let bloodType = profile.bloodType, !bloodType.isEmpty {
            parts.append(bloodType)
        }
        detailLabel.text = localizedProfileSummary(parts)
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(avatarWrap)
        card.addSubview(nameLabel)
        card.addSubview(badgeRow)
        card.addSubview(actionsStack)
        card.addSubview(detailLabel)
        NSLayoutConstraint.activate([
            avatarWrap.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            avatarWrap.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            avatarWrap.widthAnchor.constraint(equalToConstant: 44),
            avatarWrap.heightAnchor.constraint(equalToConstant: 44),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarWrap.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarWrap.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: avatarWrap.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionsStack.leadingAnchor, constant: -8),
            actionsStack.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            actionsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            badgeRow.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            badgeRow.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            badgeRow.trailingAnchor.constraint(lessThanOrEqualTo: actionsStack.leadingAnchor, constant: -8),

            detailLabel.topAnchor.constraint(equalTo: badgeRow.bottomAnchor, constant: 10),
            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    @objc private func profileCardTapped(_ sender: UITapGestureRecognizer) {
        guard let profileID = sender.view?.accessibilityIdentifier else { return }
        _ = try? ProfileManager.shared.setActiveProfile(id: profileID)
        refreshContent()
    }

    @objc private func editFamilyProfileTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier,
              let profile = try? ProfileManager.shared.profile(id: id) else { return }

        let alert = UIAlertController(title: t(.healthProfileEdit), message: relationDisplay(profile.relationship), preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileName)
            textField.text = profile.name
        }
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileRelationship)
            textField.text = self.relationDisplay(profile.relationship)
            textField.isEnabled = profile.relationship != .owner
        }
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileBirthday)
            textField.keyboardType = .numberPad
            textField.text = profile.birthYear.map(String.init)
        }
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileGender)
            textField.text = profile.gender.map(self.genderDisplay)
        }
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileHeight)
            textField.keyboardType = .decimalPad
            textField.text = self.localizedWholeNumberString(profile.heightCm)
        }
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileWeight)
            textField.keyboardType = .decimalPad
            textField.text = self.localizedWholeNumberString(profile.weightKg)
        }
        alert.addTextField { textField in
            textField.placeholder = t(.healthProfileBloodType)
            textField.text = profile.bloodType
        }
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        alert.addAction(UIAlertAction(title: t(.confirm), style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let enteredName = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let relationshipText = alert?.textFields?.dropFirst().first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let birthYearText = alert?.textFields?.dropFirst(2).first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let genderText = alert?.textFields?.dropFirst(3).first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let heightText = alert?.textFields?.dropFirst(4).first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let weightText = alert?.textFields?.dropFirst(5).first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let bloodTypeText = alert?.textFields?.dropFirst(6).first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var updated = profile
            updated.name = enteredName.isEmpty ? self.relationDisplay(profile.relationship) : enteredName
            if profile.relationship != .owner, let relationship = self.parseRelationshipInput(relationshipText) {
                updated.relationship = relationship
            }
            updated.birthYear = Int(birthYearText)
            updated.gender = self.parseGenderInput(genderText)
            updated.heightCm = self.parseLocalizedDouble(heightText)
            updated.weightKg = self.parseLocalizedDouble(weightText)
            updated.bloodType = bloodTypeText.isEmpty ? nil : bloodTypeText
            try? ProfileManager.shared.updateProfile(updated)
            self.refreshContent()
        })
        present(alert, animated: true)
    }

    private func confirmDeleteProfile(_ profile: HealthProfile) {
        let alert = UIAlertController(title: profile.name.isEmpty ? relationDisplay(profile.relationship) : profile.name, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        alert.addAction(UIAlertAction(title: t(.healthProfileDeleteFamily), style: .destructive) { [weak self] _ in
            do {
                try ProfileManager.shared.removeProfile(id: profile.id)
                self?.refreshContent()
            } catch {
                let failure = UIAlertController(title: nil, message: t(.healthProfileDeleteFailed), preferredStyle: .alert)
                failure.addAction(UIAlertAction(title: t(.confirm), style: .default))
                self?.present(failure, animated: true)
            }
        })
        present(alert, animated: true)
    }

    @objc private func deleteProfileTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier,
              let profile = try? ProfileManager.shared.profile(id: id) else { return }
        confirmDeleteProfile(profile)
    }

    private func clearOtherProfiles(_ profiles: [HealthProfile]) {
        var failed = false
        for profile in profiles {
            do {
                try ProfileManager.shared.removeProfile(id: profile.id)
            } catch {
                failed = true
            }
        }
        refreshContent()
        if failed {
            let alert = UIAlertController(title: nil, message: t(.healthProfileBulkDeleteFailed), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
            present(alert, animated: true)
        }
    }

    private func relationDisplay(_ relationship: Relationship) -> String {
        relationship.displayName
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIControl)
    }

    private func genderDisplay(_ gender: Gender) -> String {
        gender.displayName
    }

    private func localizedProfileSummary(_ parts: [String]) -> String {
        let filtered = parts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !filtered.isEmpty else { return "" }
        let formatter = ListFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        return formatter.string(from: filtered) ?? filtered.joined(separator: " · ")
    }

    private func makeOverviewCard(count: Int, scope: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 24
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.05
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.layer.shadowRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconWrap = UIView()
        iconWrap.backgroundColor = AppDesign.Color.primaryGreen.withAlphaComponent(0.12)
        iconWrap.layer.cornerRadius = 22
        iconWrap.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "person.2.fill"))
        icon.tintColor = AppDesign.Color.primaryGreen
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.addSubview(icon)

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.text = t(.healthProfileFamilyProfiles)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.text = String(format: t(.healthProfileFamilyProfilesScopeFormat), t(.healthProfileFamilyProfiles), count, scope)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let badgeRow = UIStackView(arrangedSubviews: [
            makeProfileBadge(text: String(format: t(.healthProfileFamilyProfilesCountFormat), t(.healthProfileFamilyProfiles), count), tint: .secondaryLabel),
            makeProfileBadge(text: scope, tint: AppDesign.Color.primaryGreen)
        ])
        badgeRow.axis = .horizontal
        badgeRow.spacing = 8
        badgeRow.translatesAutoresizingMaskIntoConstraints = false

        let actionRow = UIStackView(arrangedSubviews: [
            makeOverviewActionButton(title: t(.healthProfileAddFamily), iconName: "plus", selector: #selector(addProfileTapped), prominent: true),
            makeOverviewActionButton(title: t(.healthProfileRefreshCloud), iconName: "arrow.clockwise", selector: #selector(refreshCloudTapped)),
            makeOverviewActionButton(title: t(.healthProfileManageFamily), iconName: "slider.horizontal.3", selector: #selector(manageTapped))
        ])
        actionRow.axis = .horizontal
        actionRow.spacing = 8
        actionRow.distribution = .fillEqually
        actionRow.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconWrap)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(badgeRow)
        card.addSubview(actionRow)

        NSLayoutConstraint.activate([
            iconWrap.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            iconWrap.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            iconWrap.widthAnchor.constraint(equalToConstant: 44),
            iconWrap.heightAnchor.constraint(equalToConstant: 44),

            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: iconWrap.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            badgeRow.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            badgeRow.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            badgeRow.trailingAnchor.constraint(lessThanOrEqualTo: titleLabel.trailingAnchor),

            actionRow.topAnchor.constraint(equalTo: badgeRow.bottomAnchor, constant: 14),
            actionRow.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            actionRow.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            actionRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeEmptyStateCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "person.crop.circle.badge.plus"))
        icon.tintColor = .tertiaryLabel
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = t(.healthProfileNotFilled)
        label.translatesAutoresizingMaskIntoConstraints = false

        let addButton = UIButton(type: .system)
        addButton.setTitle(t(.healthProfileAddFamily), for: .normal)
        addButton.setTitleColor(.white, for: .normal)
        addButton.backgroundColor = AppDesign.Color.primaryGreen
        addButton.layer.cornerRadius = 12
        addButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        addButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addTarget(self, action: #selector(addProfileTapped), for: .touchUpInside)

        card.addSubview(icon)
        card.addSubview(label)
        card.addSubview(addButton)
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            icon.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 30),
            icon.heightAnchor.constraint(equalToConstant: 30),

            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            addButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            addButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            addButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])
        return card
    }

    private func makeProfileBadge(text: String, tint: UIColor) -> UIView {
        let label = HealthPagePaddingLabel()
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = tint
        label.backgroundColor = tint.withAlphaComponent(0.10)
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.insets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        return label
    }

    private func makeOverviewActionButton(title: String, iconName: String, selector: Selector, prominent: Bool = false) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: iconName), for: .normal)
        button.backgroundColor = prominent ? AppDesign.Color.primaryGreen : UIColor.secondarySystemBackground.withAlphaComponent(0.85)
        button.layer.cornerRadius = 12
        button.tintColor = prominent ? .white : AppDesign.Color.primaryGreen
        button.setTitleColor(prominent ? .white : AppDesign.Color.primaryGreen, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        button.semanticContentAttribute = directionalSemanticContentAttribute(for: .leading)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }

    private func avatarInitial(for profile: HealthProfile) -> String {
        let name = (profile.name.isEmpty ? relationDisplay(profile.relationship) : profile.name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let scalar = name.unicodeScalars.first {
            return String(Character(scalar)).uppercased()
        }
        return "•"
    }

    private func parseGenderInput(_ raw: String) -> Gender? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        if [Gender.male.rawValue, t(.healthProfileGenderMale).lowercased(), "男"].contains(normalized) {
            return .male
        }
        if [Gender.female.rawValue, t(.healthProfileGenderFemale).lowercased(), "女"].contains(normalized) {
            return .female
        }
        if [Gender.other.rawValue, t(.healthProfileGenderOther).lowercased(), "其他"].contains(normalized) {
            return .other
        }
        return nil
    }

    private func parseRelationshipInput(_ raw: String) -> Relationship? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        for relationship in Relationship.allCases {
            let candidates = [relationship.rawValue.lowercased(), relationship.displayName.lowercased()]
            if candidates.contains(normalized) {
                return relationship
            }
        }
        return nil
    }

    private func localizedWholeNumberString(_ value: Double?) -> String? {
        guard let value else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value))
    }

    private func parseLocalizedDouble(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.current.localeIdentifier)
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: trimmed) {
            return number.doubleValue
        }
        return Double(trimmed)
    }
}
