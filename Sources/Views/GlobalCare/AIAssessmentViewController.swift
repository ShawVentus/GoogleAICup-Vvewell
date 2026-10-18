import UIKit

class AIAssessmentViewController: UIViewController {

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

    private let loadingCard: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = AppDesign.CornerRadius.card
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let spinner: UIActivityIndicatorView = {
        let s: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            s = UIActivityIndicatorView(style: .large)
        } else {
            s = UIActivityIndicatorView(style: .gray)
        }
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let resultCard: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = AppDesign.CornerRadius.card
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = AppDesign.Shadow.cardOpacity
        v.layer.shadowOffset = AppDesign.Shadow.cardOffset
        v.layer.shadowRadius = AppDesign.Shadow.cardRadius
        v.alpha = 0
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let nextButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = AppDesign.Color.primaryGreen
        btn.layer.cornerRadius = AppDesign.CornerRadius.button
        btn.alpha = 0
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        navigationItem.title = t(.assessTitle)
        setupLayout()
        startAnalysis()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        loadingLabel.text = t(.assessAnalyzing)
        loadingCard.addSubview(spinner)
        loadingCard.addSubview(loadingLabel)
        NSLayoutConstraint.activate([
            loadingCard.heightAnchor.constraint(equalToConstant: 120),
            spinner.centerXAnchor.constraint(equalTo: loadingCard.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: loadingCard.topAnchor, constant: 24),
            loadingLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 14),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingCard.centerXAnchor),
        ])
        spinner.startAnimating()
        contentStack.addArrangedSubview(loadingCard)
        contentStack.addArrangedSubview(resultCard)

        nextButton.setTitle(t(.assessViewPackages), for: .normal)
        nextButton.addTarget(self, action: #selector(goNext), for: .touchUpInside)
        view.addSubview(nextButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -8),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: AppDesign.Layout.horizontalPadding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -AppDesign.Layout.horizontalPadding),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -AppDesign.Layout.horizontalPadding * 2),

            nextButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppDesign.Layout.horizontalPadding),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppDesign.Layout.horizontalPadding),
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            nextButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func startAnalysis() {
        Task { [weak self] in
            guard let self = self else { return }

            do {
                let result = try await APIClient.shared.assessGlobalCare(draft: self.context.draft)
                await MainActor.run {
                    self.context.aiAssessmentResult = result
                    self.showResult(result)
                }
            } catch {
                print("GlobalCare assessment failed: \(error)")
                let fallback = GlobalCareMock.assessmentResult()
                await MainActor.run {
                    self.context.aiAssessmentResult = fallback
                    self.showResult(fallback)
                }
            }
        }
    }

    private func showResult(_ result: AIAssessmentResult) {
        resultCard.subviews.forEach { $0.removeFromSuperview() }
        spinner.stopAnimating()
        UIView.animate(withDuration: 0.3) { self.loadingCard.alpha = 0 }

        let titleLabel = UILabel()
        titleLabel.text = t(.assessResultTitle)
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textAlignment = .natural
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(makeResultRow(label: t(.assessRiskLevel), value: result.riskLevel, valueColor: UIColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1)))
        stack.addArrangedSubview(makeResultRow(label: t(.assessRecommendedDept), value: result.recommendedDept, valueColor: AppDesign.Color.darkTeal))
        stack.addArrangedSubview(makeResultRow(label: t(.assessMatchedHospitals), value: "\(result.matchedHospitals) \(t(.assessHospitalsUnit))", valueColor: AppDesign.Color.primaryGreen))

        resultCard.addSubview(titleLabel)
        resultCard.addSubview(stack)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: resultCard.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: resultCard.leadingAnchor, constant: 16),
            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: resultCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: resultCard.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: resultCard.bottomAnchor, constant: -18),
        ])

        UIView.animate(withDuration: 0.4) {
            self.resultCard.alpha = 1
            self.nextButton.alpha = 1
        }
    }

    private func makeResultRow(label: String, value: String, valueColor: UIColor) -> UIView {
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
        val.font = .systemFont(ofSize: 15, weight: .semibold)
        val.textColor = valueColor
        val.textAlignment = .natural
        val.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(lbl)
        row.addSubview(val)
        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            lbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            val.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            val.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            row.heightAnchor.constraint(equalToConstant: 32),
        ])
        return row
    }

    @objc private func goNext() {
        let vc = CarePackageViewController()
        vc.context = context
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func languageChanged() {
        navigationItem.title = t(.assessTitle)
        loadingLabel.text = t(.assessAnalyzing)
        nextButton.setTitle(t(.assessViewPackages), for: .normal)
        if let result = context.aiAssessmentResult {
            showResult(result)
            loadingCard.alpha = 0
            resultCard.alpha = 1
            nextButton.alpha = 1
        }
    }
}
