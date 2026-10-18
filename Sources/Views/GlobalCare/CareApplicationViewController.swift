import UIKit

class CareApplicationViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {

    var context = GlobalCareFlowContext()
    private var symptomsDraftText = ""

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.keyboardDismissMode = .interactive
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let symptomsTextView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 14)
        tv.layer.cornerRadius = AppDesign.CornerRadius.button
        tv.layer.borderWidth = 1
        tv.layer.borderColor = UIColor.separator.cgColor
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let countryButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.layer.cornerRadius = AppDesign.CornerRadius.button
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor.separator.cgColor
        btn.contentHorizontalAlignment = directionalContentHorizontalAlignment()
        btn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let contactField: UITextField = {
        let tf = UITextField()
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 14)
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private var selectedCountry: String = ""
    private var selectedHistory: [String] = []

    private let countries: [L10nKey] = [.country_china, .country_usa, .country_japan, .country_germany, .country_singapore, .country_thailand]
    private let historyKeys: [L10nKey] = [.history_hypertension, .history_diabetes, .history_heart, .history_cancer, .history_none]
    private var historyButtons: [UIButton] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        navigationItem.title = t(.applyTitle)
        symptomsTextView.delegate = self
        contactField.delegate = self
        setupScrollView()
        buildForm()
        setupNextButton()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor), // 这里的约束直接到 view 底部，不再避让键盘
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: AppDesign.Layout.horizontalPadding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -AppDesign.Layout.horizontalPadding),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -80), // 留出底部按钮的空间
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -AppDesign.Layout.horizontalPadding * 2),
        ])
    }

    private func buildForm() {
        contentStack.addArrangedSubview(makeFieldCard(label: t(.applySymptoms), content: symptomsTextView, height: 100))
        applySymptomsText()

        let countryCard = makeCardView()
        let countryLabel = makeFieldLabel(t(.applyTargetCountry))
        let countryTitle = selectedCountry.isEmpty ? t(.country_china) : selectedCountry
        countryButton.setTitle(countryTitle, for: .normal)
        countryButton.setTitleColor(.label, for: .normal)
        selectedCountry = countryTitle
        countryButton.removeTarget(self, action: #selector(showCountryPicker), for: .touchUpInside)
        countryButton.addTarget(self, action: #selector(showCountryPicker), for: .touchUpInside)
        countryCard.addSubview(countryLabel)
        countryCard.addSubview(countryButton)
        NSLayoutConstraint.activate([
            countryLabel.topAnchor.constraint(equalTo: countryCard.topAnchor, constant: 14),
            countryLabel.leadingAnchor.constraint(equalTo: countryCard.leadingAnchor, constant: 14),
            countryButton.topAnchor.constraint(equalTo: countryLabel.bottomAnchor, constant: 8),
            countryButton.leadingAnchor.constraint(equalTo: countryCard.leadingAnchor, constant: 14),
            countryButton.trailingAnchor.constraint(equalTo: countryCard.trailingAnchor, constant: -14),
            countryButton.heightAnchor.constraint(equalToConstant: 44),
            countryButton.bottomAnchor.constraint(equalTo: countryCard.bottomAnchor, constant: -14),
        ])
        contentStack.addArrangedSubview(countryCard)

        let historyCard = makeCardView()
        let historyLabel = makeFieldLabel(t(.applyMedicalHistory))
        let historyStack = UIStackView()
        historyStack.axis = .vertical
        historyStack.spacing = 8
        historyStack.translatesAutoresizingMaskIntoConstraints = false
        historyButtons = historyKeys.map { key in
            let btn = UIButton(type: .system)
            btn.setTitle(t(key), for: .normal)
            btn.setTitleColor(.label, for: .normal)
            btn.contentHorizontalAlignment = directionalContentHorizontalAlignment()
            btn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
            btn.layer.cornerRadius = 8
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.separator.cgColor
            btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
            btn.addTarget(self, action: #selector(toggleHistory(_:)), for: .touchUpInside)
            if selectedHistory.contains(t(key)) {
                btn.backgroundColor = AppDesign.Color.primaryGreen.withAlphaComponent(0.12)
                btn.layer.borderColor = AppDesign.Color.primaryGreen.cgColor
            }
            return btn
        }
        historyButtons.forEach { historyStack.addArrangedSubview($0) }
        historyCard.addSubview(historyLabel)
        historyCard.addSubview(historyStack)
        NSLayoutConstraint.activate([
            historyLabel.topAnchor.constraint(equalTo: historyCard.topAnchor, constant: 14),
            historyLabel.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 14),
            historyStack.topAnchor.constraint(equalTo: historyLabel.bottomAnchor, constant: 10),
            historyStack.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 14),
            historyStack.trailingAnchor.constraint(equalTo: historyCard.trailingAnchor, constant: -14),
            historyStack.bottomAnchor.constraint(equalTo: historyCard.bottomAnchor, constant: -14),
        ])
        contentStack.addArrangedSubview(historyCard)

        contentStack.addArrangedSubview(makeFieldCard(label: t(.applyContactInfo), content: contactField, height: 44))
        contactField.placeholder = t(.applyContactPlaceholder)
    }

    private func setupNextButton() {
        let btn = UIButton(type: .system)
        btn.setTitle(t(.next), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = AppDesign.Color.primaryGreen
        btn.layer.cornerRadius = AppDesign.CornerRadius.button
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(goNext), for: .touchUpInside)
        view.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppDesign.Layout.horizontalPadding),
            btn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppDesign.Layout.horizontalPadding),
            btn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            btn.heightAnchor.constraint(equalToConstant: 50),
        ])
        scrollView.bottomAnchor.constraint(equalTo: btn.topAnchor, constant: -8).isActive = true
    }

    @objc private func goNext() {
        let symptoms = currentSymptomsText()
        let contact  = (contactField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if symptoms.isEmpty {
            showValidationAlert(message: "\(t(.applySymptoms)): \(t(.validationRequired))")
            return
        }
        if contact.isEmpty {
            showValidationAlert(message: "\(t(.applyContactInfo)): \(t(.validationRequired))")
            return
        }

        context.draft.symptoms = symptoms
        context.draft.targetCountry = selectedCountry
        context.draft.medicalHistory = selectedHistory
        context.draft.contactInfo = contact
        let vc = AIAssessmentViewController()
        vc.context = context
        navigationController?.pushViewController(vc, animated: true)
    }

    /// 显示表单校验提示弹窗
    private func showValidationAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
        present(alert, animated: true)
    }

    @objc private func showCountryPicker() {
        let alert = UIAlertController(title: t(.applyTargetCountry), message: nil, preferredStyle: .actionSheet)
        countries.forEach { key in
            alert.addAction(UIAlertAction(title: t(key), style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.selectedCountry = t(key)
                self.countryButton.setTitle(t(key), for: .normal)
            })
        }
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        present(alert, animated: true)
    }

    @objc private func toggleHistory(_ sender: UIButton) {
        let title = sender.title(for: .normal) ?? ""
        if selectedHistory.contains(title) {
            selectedHistory.removeAll { $0 == title }
            sender.backgroundColor = .clear
            sender.layer.borderColor = UIColor.separator.cgColor
        } else {
            selectedHistory.append(title)
            sender.backgroundColor = AppDesign.Color.primaryGreen.withAlphaComponent(0.12)
            sender.layer.borderColor = AppDesign.Color.primaryGreen.cgColor
        }
    }

    @objc private func languageChanged() {
        let symptoms = currentSymptomsText()
        let contact = contactField.text
        let selectedHistoryKeys = historyKeys.filter { selectedHistory.contains(t($0)) }
        let selectedCountryKey = countries.first { t($0) == selectedCountry }

        navigationItem.title = t(.applyTitle)
        clearFormContent()
        if let countryKey = selectedCountryKey {
            selectedCountry = t(countryKey)
        }
        selectedHistory = selectedHistoryKeys.map { t($0) }
        buildForm()
        if symptoms.isEmpty {
            symptomsTextView.text = ""
        } else {
            symptomsTextView.text = symptoms
            symptomsTextView.textColor = .label
        }
        applySymptomsText()
        contactField.text = contact
    }

    private func clearFormContent() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func currentSymptomsText() -> String {
        symptomsDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applySymptomsText() {
        let text = symptomsDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            symptomsTextView.text = t(.applySymptomsPlaceholder)
            symptomsTextView.textColor = .secondaryLabel
        } else {
            symptomsTextView.text = symptomsDraftText
            symptomsTextView.textColor = .label
        }
    }

    // MARK: - Helpers

    private func makeCardView() -> UIView {
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

    private func makeFieldLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeFieldCard(label: String, content: UIView, height: CGFloat) -> UIView {
        let card = makeCardView()
        let lbl = makeFieldLabel(label)
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(lbl)
        card.addSubview(content)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            lbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            content.topAnchor.constraint(equalTo: lbl.bottomAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            content.heightAnchor.constraint(equalToConstant: height),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        guard textView === symptomsTextView else { return }
        if symptomsDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textView.text = nil
            textView.textColor = .label
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        guard textView === symptomsTextView else { return }
        symptomsDraftText = textView.text ?? ""
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        guard textView === symptomsTextView else { return }
        symptomsDraftText = textView.text ?? ""
        applySymptomsText()
    }
}
