import UIKit

/// 基础健康信息编辑页（6项：姓名、性别、生日、身高、体重、血型）
final class HealthProfileEditViewController: UIViewController, UITextFieldDelegate {

    private let themeColor = AppDesign.Color.primaryGreen
    private weak var saveButton: UIButton?
    // MARK: - 输入控件

    private let nameField: UITextField = {
        let tf = UITextField()
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 15)
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let genderSegment: UISegmentedControl = {
        let sc = UISegmentedControl(items: [
            t(.healthProfileGenderMale),
            t(.healthProfileGenderFemale),
            t(.healthProfileGenderOther)
        ])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let birthdayPicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .date
        dp.maximumDate = Date()
        if #available(iOS 14.0, *) {
            dp.preferredDatePickerStyle = .inline
        }
        dp.translatesAutoresizingMaskIntoConstraints = false
        return dp
    }()

    private let heightField: UITextField = {
        let tf = UITextField()
        tf.borderStyle = .roundedRect
        tf.keyboardType = .decimalPad
        tf.font = .systemFont(ofSize: 15)
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let weightField: UITextField = {
        let tf = UITextField()
        tf.borderStyle = .roundedRect
        tf.keyboardType = .decimalPad
        tf.font = .systemFont(ofSize: 15)
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let bloodTypeSegment: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["A", "B", "AB", "O", "?"])
        sc.selectedSegmentIndex = 4
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    // MARK: - Scroll / Stack

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 16
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - 当前档案

    private var profile: UserProfile = UserProfileRepository.shared.fetch()

    private let genderValues = ["male", "female", "other"]
    private let bloodTypeValues = ["A", "B", "AB", "O", ""]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        title = t(.healthProfileEdit)
        setupScrollView()
        buildForm()
        loadProfile()
        configureInputAccessories()
        setupSaveButton()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func languageChanged() {
        let draft = currentDraft()
        title = t(.healthProfileEdit)
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        [t(.healthProfileGenderMale), t(.healthProfileGenderFemale), t(.healthProfileGenderOther)]
            .enumerated().forEach { genderSegment.setTitle($1, forSegmentAt: $0) }
        buildForm()
        applyDraft(draft)
        updateAccessoryTitles()
        saveButton?.setTitle(t(.healthProfileSave), for: .normal)
    }

    // MARK: - Setup

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        scrollView.keyboardDismissMode = .interactive

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor), // 这里的约束不再减去 60 或避让键盘，交给 contentInset

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -80), // 留出保存按钮的空间
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])
    }

    private func buildForm() {
        nameField.delegate = self
        heightField.delegate = self
        weightField.delegate = self
        contentStack.addArrangedSubview(makeField(label: t(.healthProfileName), input: nameField))
        contentStack.addArrangedSubview(makeSegmentField(label: t(.healthProfileGender), control: genderSegment))
        contentStack.addArrangedSubview(makeDateField(label: t(.healthProfileBirthday), picker: birthdayPicker))
        contentStack.addArrangedSubview(makeField(label: t(.healthProfileHeight), input: heightField))
        contentStack.addArrangedSubview(makeField(label: t(.healthProfileWeight), input: weightField))
        contentStack.addArrangedSubview(makeSegmentField(label: t(.healthProfileBloodType), control: bloodTypeSegment))
    }

    private func configureInputAccessories() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: t(.done), style: .done, target: self, action: #selector(doneTapped))
        toolbar.items = [flex, done]
        heightField.inputAccessoryView = toolbar
        weightField.inputAccessoryView = toolbar
    }

    private func updateAccessoryTitles() {
        [heightField, weightField].forEach { field in
            guard let toolbar = field.inputAccessoryView as? UIToolbar,
                  let doneItem = toolbar.items?.last else { return }
            doneItem.title = t(.done)
        }
    }

    private func setupSaveButton() {
        let btn = UIButton(type: .system)
        btn.setTitle(t(.healthProfileSave), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = themeColor
        btn.layer.cornerRadius = AppDesign.CornerRadius.button
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            btn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            btn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            btn.heightAnchor.constraint(equalToConstant: 50),
        ])
        saveButton = btn
    }

    // MARK: - 加载档案到控件

    private func loadProfile() {
        if let owner = try? ProfileManager.shared.ownerProfile() {
            if profile.name.isEmpty, !owner.name.isEmpty {
                profile.name = owner.name
            }
            if profile.gender.isEmpty, let gender = owner.gender?.rawValue {
                profile.gender = gender
            }
            if profile.birthday == nil,
               let birthYear = owner.birthYear,
               let inferredBirthday = Calendar.current.date(from: DateComponents(year: birthYear, month: 1, day: 1)) {
                profile.birthday = inferredBirthday
            }
            if profile.heightCm == nil, let heightCm = owner.heightCm {
                profile.heightCm = heightCm
            }
            if profile.weightKg == nil, let weightKg = owner.weightKg {
                profile.weightKg = weightKg
            }
            if profile.bloodType.isEmpty, let bloodType = owner.bloodType, !bloodType.isEmpty {
                profile.bloodType = bloodType
            }
        }

        nameField.text = profile.name.isEmpty ? nil : profile.name
        let gIdx = genderValues.firstIndex(of: profile.gender) ?? 0
        genderSegment.selectedSegmentIndex = gIdx
        if let bd = profile.birthday { birthdayPicker.date = bd }
        heightField.text = localizedWholeNumberString(profile.heightCm)
        weightField.text = localizedWholeNumberString(profile.weightKg)
        let btIdx = bloodTypeValues.firstIndex(of: profile.bloodType) ?? 4
        bloodTypeSegment.selectedSegmentIndex = btIdx
    }

    // MARK: - 保存

    @objc private func saveTapped() {
        view.endEditing(true)
        profile.name    = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        profile.gender  = genderValues[genderSegment.selectedSegmentIndex]
        profile.birthday = birthdayPicker.date
        profile.heightCm = parseLocalizedDouble(heightField.text)
        profile.weightKg = parseLocalizedDouble(weightField.text)
        profile.bloodType = bloodTypeValues[bloodTypeSegment.selectedSegmentIndex]
        UserProfileRepository.shared.save(profile)
        try? ProfileManager.shared.upsertOwnerProfile(from: profile)
        navigationController?.popViewController(animated: true)
    }

    @objc private func doneTapped() {
        view.endEditing(true)
    }

    private func currentDraft() -> UserProfile {
        var draft = profile
        draft.name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        draft.gender = genderValues[genderSegment.selectedSegmentIndex]
        draft.birthday = birthdayPicker.date
        draft.heightCm = parseLocalizedDouble(heightField.text)
        draft.weightKg = parseLocalizedDouble(weightField.text)
        draft.bloodType = bloodTypeValues[bloodTypeSegment.selectedSegmentIndex]
        return draft
    }

    private func applyDraft(_ draft: UserProfile) {
        profile = draft
        nameField.text = draft.name.isEmpty ? nil : draft.name
        genderSegment.selectedSegmentIndex = genderValues.firstIndex(of: draft.gender) ?? 0
        if let birthday = draft.birthday {
            birthdayPicker.date = birthday
        }
        heightField.text = localizedWholeNumberString(draft.heightCm)
        weightField.text = localizedWholeNumberString(draft.weightKg)
        bloodTypeSegment.selectedSegmentIndex = bloodTypeValues.firstIndex(of: draft.bloodType) ?? 4
    }

    // MARK: - 表单 Cell 工厂

    private func makeField(label: String, input: UIView) -> UIView {
        let card = makeCard()
        let lbl = makeLabel(label)
        input.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(lbl)
        card.addSubview(input)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            lbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            input.topAnchor.constraint(equalTo: lbl.bottomAnchor, constant: 8),
            input.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            input.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            input.heightAnchor.constraint(equalToConstant: 44),
            input.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    private func makeSegmentField(label: String, control: UISegmentedControl) -> UIView {
        let card = makeCard()
        let lbl = makeLabel(label)
        control.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(lbl)
        card.addSubview(control)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            lbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            control.topAnchor.constraint(equalTo: lbl.bottomAnchor, constant: 10),
            control.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            control.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            control.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    private func makeDateField(label: String, picker: UIDatePicker) -> UIView {
        let card = makeCard()
        let lbl = makeLabel(label)
        picker.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(lbl)
        card.addSubview(picker)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            lbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            picker.topAnchor.constraint(equalTo: lbl.bottomAnchor, constant: 8),
            picker.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            picker.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            picker.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
        ])
        return card
    }

    private func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = AppDesign.CornerRadius.card
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        v.layer.shadowOffset = AppDesign.Shadow.cardOffset
        v.layer.shadowRadius = AppDesign.Shadow.cardRadius
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func makeLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
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
