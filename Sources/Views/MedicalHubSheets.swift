import UIKit

// MARK: - Result models
// Native counterpart of Android's medical_flow_sheets.dart result classes.

struct ReferralIntakeResult {
    let complaint: String
    let urgency: String
    let channel: String
    let hasRecords: Bool
}

struct InsuranceNeedsResult {
    let annualBudget: Int
    let priority: String
    let hasExistingPolicy: Bool
}

struct ClaimDraftResult {
    let type: String
    let amount: Int
}

struct CommunityPostDraft {
    let type: String
    let content: String
}

struct AdvisorContactResult {
    let name: String
    let phone: String
    let contactChannel: String
    let preferredTime: String
    let productName: String
}

// MARK: - Generic form sheet

/// Generic modal form used by the medical hub flows.
/// Mirrors the Android bottom-sheet forms (referral intake, insurance needs,
/// claim draft, community post, advisor contact) with native controls.
final class MedicalFormSheetViewController: UIViewController {

    enum Field {
        case text(id: String, title: String, placeholder: String, keyboard: UIKeyboardType, required: Bool)
        case multiline(id: String, title: String, placeholder: String, required: Bool)
        case choice(id: String, title: String, options: [String], selected: Int)
        case toggle(id: String, title: String, isOn: Bool)
    }

    private let sheetTitle: String
    private let sheetSubtitle: String?
    private let fields: [Field]
    private let submitTitle: String
    private let onSubmit: ([String: Any]) -> Void

    private var textFields: [String: UITextField] = [:]
    private var textViews: [String: UITextView] = [:]
    private var segmentedControls: [String: UISegmentedControl] = [:]
    private var switches: [String: UISwitch] = [:]
    private var choiceOptions: [String: [String]] = [:]
    private let errorLabel = UILabel()

    init(
        title: String,
        subtitle: String?,
        fields: [Field],
        submitTitle: String,
        onSubmit: @escaping ([String: Any]) -> Void
    ) {
        self.sheetTitle = title
        self.sheetSubtitle = subtitle
        self.fields = fields
        self.submitTitle = submitTitle
        self.onSubmit = onSubmit
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        let titleLabel = UILabel()
        titleLabel.text = sheetTitle
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        stack.addArrangedSubview(titleLabel)

        if let sheetSubtitle, !sheetSubtitle.isEmpty {
            let subtitleLabel = UILabel()
            subtitleLabel.text = sheetSubtitle
            subtitleLabel.textColor = .secondaryLabel
            subtitleLabel.font = .systemFont(ofSize: 13)
            subtitleLabel.numberOfLines = 0
            stack.addArrangedSubview(subtitleLabel)
        }

        for field in fields {
            stack.addArrangedSubview(makeFieldView(field))
        }

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        stack.addArrangedSubview(errorLabel)

        let submitButton = UIButton(type: .system)
        submitButton.setTitle(submitTitle, for: .normal)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        submitButton.backgroundColor = AppDesign.Color.primaryGreen
        submitButton.layer.cornerRadius = AppDesign.CornerRadius.button
        submitButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        stack.addArrangedSubview(submitButton)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(t(.cancel), for: .normal)
        cancelButton.tintColor = .secondaryLabel
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        stack.addArrangedSubview(cancelButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])
    }

    private func makeFieldView(_ field: Field) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6
        switch field {
        case let .text(id, title, placeholder, keyboard, _):
            container.addArrangedSubview(makeFieldTitle(title))
            let textField = PaddedTextField()
            textField.placeholder = placeholder
            textField.keyboardType = keyboard
            textField.borderStyle = .none
            textField.layer.borderColor = AppDesign.Surface.border.cgColor
            textField.layer.borderWidth = 1
            textField.layer.cornerRadius = 10
            textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
            textFields[id] = textField
            container.addArrangedSubview(textField)
        case let .multiline(id, title, placeholder, _):
            container.addArrangedSubview(makeFieldTitle(title))
            let textView = UITextView()
            textView.font = .systemFont(ofSize: 15)
            textView.layer.borderColor = AppDesign.Surface.border.cgColor
            textView.layer.borderWidth = 1
            textView.layer.cornerRadius = 10
            textView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
            textView.heightAnchor.constraint(equalToConstant: 96).isActive = true
            textView.accessibilityLabel = placeholder
            textViews[id] = textView
            container.addArrangedSubview(textView)
        case let .choice(id, title, options, selected):
            container.addArrangedSubview(makeFieldTitle(title))
            let control = UISegmentedControl(items: options.map(zhEn))
            control.selectedSegmentIndex = selected
            control.selectedSegmentTintColor = AppDesign.Color.primaryGreen
            segmentedControls[id] = control
            choiceOptions[id] = options
            container.addArrangedSubview(control)
        case let .toggle(id, title, isOn):
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            let label = UILabel()
            label.text = title
            label.font = .systemFont(ofSize: 15, weight: .medium)
            label.numberOfLines = 0
            let toggle = UISwitch()
            toggle.isOn = isOn
            toggle.onTintColor = AppDesign.Color.primaryGreen
            toggle.setContentHuggingPriority(.required, for: .horizontal)
            switches[id] = toggle
            row.addArrangedSubview(label)
            row.addArrangedSubview(toggle)
            container.addArrangedSubview(row)
        }
        return container
    }

    private func makeFieldTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        return label
    }

    @objc private func submitTapped() {
        var values: [String: Any] = [:]
        for field in fields {
            switch field {
            case let .text(id, _, _, _, required):
                let value = (textFields[id]?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if required && value.isEmpty {
                    showError("请填写所有必填项")
                    return
                }
                values[id] = value
            case let .multiline(id, _, _, required):
                let value = (textViews[id]?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if required && value.count < 2 {
                    showError("请填写完整内容后再提交")
                    return
                }
                values[id] = value
            case let .choice(id, _, _, _):
                guard let control = segmentedControls[id], let options = choiceOptions[id] else { continue }
                values[id] = options[control.selectedSegmentIndex]
            case let .toggle(id, _, _):
                values[id] = switches[id]?.isOn ?? false
            }
        }
        dismiss(animated: true) { [onSubmit] in
            onSubmit(values)
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }
}

private final class PaddedTextField: UITextField {
    private let padding = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    override func textRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: padding) }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: padding) }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: padding) }
}

// MARK: - Detail sheet

/// Scrollable read-only detail sheet mirroring Android's info bottom sheets
/// (provider details, plan details, hospital cost center, community rules).
final class MedicalDetailSheetViewController: UIViewController {

    private let sheetTitle: String
    private let sheetSubtitle: String?
    private let lines: [(String, String)]
    private let notice: String?
    private let actionTitle: String?
    private let onAction: (() -> Void)?

    init(
        title: String,
        subtitle: String?,
        lines: [(String, String)],
        notice: String?,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.sheetTitle = title
        self.sheetSubtitle = subtitle
        self.lines = lines
        self.notice = notice
        self.actionTitle = actionTitle
        self.onAction = onAction
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 13
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        let titleLabel = UILabel()
        titleLabel.text = sheetTitle
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.numberOfLines = 0
        stack.addArrangedSubview(titleLabel)

        if let sheetSubtitle, !sheetSubtitle.isEmpty {
            let subtitleLabel = UILabel()
            subtitleLabel.text = sheetSubtitle
            subtitleLabel.textColor = .secondaryLabel
            subtitleLabel.font = .systemFont(ofSize: 13)
            subtitleLabel.numberOfLines = 0
            stack.addArrangedSubview(subtitleLabel)
        }

        for (label, value) in lines {
            stack.addArrangedSubview(makeDetailLine(label: label, value: value))
        }

        if let notice {
            let noticeLabel = PaddingLabel()
            noticeLabel.text = notice
            noticeLabel.font = .systemFont(ofSize: 13)
            noticeLabel.numberOfLines = 0
            noticeLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
            noticeLabel.layer.cornerRadius = 12
            noticeLabel.layer.masksToBounds = true
            noticeLabel.contentInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            stack.addArrangedSubview(noticeLabel)
        }

        if let actionTitle {
            let button = UIButton(type: .system)
            button.setTitle(actionTitle, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            button.backgroundColor = AppDesign.Color.primaryGreen
            button.layer.cornerRadius = AppDesign.CornerRadius.button
            button.heightAnchor.constraint(equalToConstant: 48).isActive = true
            button.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])
    }

    private func makeDetailLine(label: String, value: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 8
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 14, weight: .semibold)
        labelView.textColor = .secondaryLabel
        labelView.widthAnchor.constraint(equalToConstant: 88).isActive = true
        let valueView = UILabel()
        valueView.text = value
        valueView.font = .systemFont(ofSize: 14)
        valueView.numberOfLines = 0
        row.addArrangedSubview(labelView)
        row.addArrangedSubview(valueView)
        return row
    }

    @objc private func actionTapped() {
        dismiss(animated: true) { [onAction] in
            onAction?()
        }
    }
}

final class PaddingLabel: UILabel {
    var contentInsets = UIEdgeInsets.zero
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }
    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width += contentInsets.left + contentInsets.right
        size.height += contentInsets.top + contentInsets.bottom
        return size
    }
}
