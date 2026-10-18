import UIKit

class OrderConfirmViewController: UIViewController {

    var context = GlobalCareFlowContext()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
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

    private let submitButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = AppDesign.Color.primaryGreen
        btn.layer.cornerRadius = AppDesign.CornerRadius.button
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        navigationItem.title = t(.confirmTitle)
        setupLayout()
        buildSummary()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        submitButton.setTitle(t(.confirmSubmit), for: .normal)
        submitButton.addTarget(self, action: #selector(submitOrder), for: .touchUpInside)
        view.addSubview(submitButton)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: submitButton.topAnchor, constant: -8),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: AppDesign.Layout.horizontalPadding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -AppDesign.Layout.horizontalPadding),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -AppDesign.Layout.horizontalPadding * 2),
            submitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppDesign.Layout.horizontalPadding),
            submitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppDesign.Layout.horizontalPadding),
            submitButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            submitButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func buildSummary() {
        let pkg = context.selectedPackage ?? GlobalCareMock.packages()[1]
        let draft = context.draft

        let summaryCard = makeCard()
        let rows: [(String, String)] = [
            (t(.confirmApplicant), draft.applicantName),
            (t(.confirmCountry), draft.targetCountry.isEmpty ? t(.country_japan) : draft.targetCountry),
            (t(.confirmPackage), pkg.tier.name(language: LocaleManager.shared.current)),
            (t(.confirmEstimatedCost), "USD $\(pkg.priceUSD)"),
        ]
        let rowStack = UIStackView()
        rowStack.axis = .vertical
        rowStack.spacing = 14
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rows.forEach { label, value in
            rowStack.addArrangedSubview(makeSummaryRow(label: label, value: value))
        }
        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        rowStack.insertArrangedSubview(divider, at: 3)

        summaryCard.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 16),
            rowStack.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 16),
            rowStack.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -16),
            rowStack.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -16),
        ])
        contentStack.addArrangedSubview(summaryCard)

        let noteCard = makeCard()
        let noteLabel = UILabel()
        noteLabel.text = t(.confirmNote)
        noteLabel.font = .systemFont(ofSize: 13)
        noteLabel.textColor = .secondaryLabel
        noteLabel.numberOfLines = 0
        noteLabel.textAlignment = .natural
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        noteCard.addSubview(noteLabel)
        NSLayoutConstraint.activate([
            noteLabel.topAnchor.constraint(equalTo: noteCard.topAnchor, constant: 14),
            noteLabel.leadingAnchor.constraint(equalTo: noteCard.leadingAnchor, constant: 14),
            noteLabel.trailingAnchor.constraint(equalTo: noteCard.trailingAnchor, constant: -14),
            noteLabel.bottomAnchor.constraint(equalTo: noteCard.bottomAnchor, constant: -14),
        ])
        contentStack.addArrangedSubview(noteCard)
    }

    private func makeSummaryRow(label: String, value: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let lbl = UILabel()
        lbl.text = label
        lbl.font = .systemFont(ofSize: 13)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .natural
        lbl.translatesAutoresizingMaskIntoConstraints = false
        let val = UILabel()
        val.text = value
        val.font = .systemFont(ofSize: 15, weight: .medium)
        val.textColor = .label
        val.textAlignment = .natural
        val.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(lbl)
        row.addSubview(val)
        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            lbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            val.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            val.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            val.leadingAnchor.constraint(greaterThanOrEqualTo: lbl.trailingAnchor, constant: 8),
            row.heightAnchor.constraint(equalToConstant: 28),
        ])
        return row
    }

    @objc private func submitOrder() {
        submitButton.isEnabled = false
        submitButton.setTitle(t(.loading), for: .normal)

        Task { [weak self] in
            guard let self = self else { return }

            let pkg = self.context.selectedPackage ?? GlobalCareMock.packages()[1]
            let assessment = self.context.aiAssessmentResult ?? GlobalCareMock.assessmentResult()

            do {
                let response = try await APIClient.shared.submitGlobalCareOrder(
                    draft: self.context.draft,
                    package: pkg,
                    assessment: assessment
                )

                let order = GlobalCareOrder(
                    orderNo: response.orderNo,
                    draft: self.context.draft,
                    package: pkg,
                    nodes: GlobalCareMock.trackingNodes(),
                    submittedAt: Date()
                )

                await MainActor.run {
                    let vc = OrderTrackingViewController()
                    vc.order = order
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            } catch {
                await MainActor.run {
                    self.submitButton.isEnabled = true
                    self.submitButton.setTitle(t(.confirmSubmit), for: .normal)

                    let alert = UIAlertController(
                        title: nil,
                        message: "提交失败，请检查网络后重试",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: t(.confirm), style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    @objc private func languageChanged() {
        navigationItem.title = t(.confirmTitle)
        submitButton.setTitle(t(.confirmSubmit), for: .normal)
        clearSummaryContent()
        buildSummary()
    }

    private func clearSummaryContent() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
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
}
