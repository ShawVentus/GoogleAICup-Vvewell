import UIKit

class OrderTrackingViewController: UIViewController {

    var order: GlobalCareOrder = GlobalCareMock.sampleOrder(context: GlobalCareFlowContext())

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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        navigationItem.title = t(.trackingTitle)
        setupLayout()
        buildContent()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .appLanguageDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: AppDesign.Layout.horizontalPadding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -AppDesign.Layout.horizontalPadding),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -AppDesign.Layout.horizontalPadding * 2),
        ])
    }

    private func buildContent() {
        // 订单头部信息卡
        let headerCard = makeCard()
        let orderNoLabel = UILabel()
        orderNoLabel.text = "\(t(.trackingOrderNo))  \(order.orderNo)"
        orderNoLabel.font = .systemFont(ofSize: 13)
        orderNoLabel.textColor = .secondaryLabel
        orderNoLabel.textAlignment = .natural
        orderNoLabel.translatesAutoresizingMaskIntoConstraints = false
        let pkgLabel = UILabel()
        pkgLabel.text = order.package.tier.name(language: LocaleManager.shared.current)
        pkgLabel.font = .systemFont(ofSize: 18, weight: .bold)
        pkgLabel.textColor = AppDesign.Color.primaryGreen
        pkgLabel.textAlignment = .natural
        pkgLabel.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(orderNoLabel)
        headerCard.addSubview(pkgLabel)
        NSLayoutConstraint.activate([
            orderNoLabel.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: 16),
            orderNoLabel.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 16),
            pkgLabel.topAnchor.constraint(equalTo: orderNoLabel.bottomAnchor, constant: 6),
            pkgLabel.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 16),
            pkgLabel.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: -16),
        ])
        contentStack.addArrangedSubview(headerCard)

        // 按阶段分组渲染时间线
        let phases: [(TrackingPhase, L10nKey)] = [
            (.pre, .trackingPreTreatment),
            (.during, .trackingDuringTreatment),
            (.post, .trackingPostTreatment),
        ]
        for (phase, titleKey) in phases {
            let nodes = order.nodes.filter { $0.phase == phase }
            guard !nodes.isEmpty else { continue }
            let phaseCard = makeCard()
            let phaseTitle = UILabel()
            phaseTitle.text = t(titleKey)
            phaseTitle.font = .systemFont(ofSize: 15, weight: .semibold)
            phaseTitle.textColor = AppDesign.Color.darkTeal
            phaseTitle.textAlignment = .natural
            phaseTitle.translatesAutoresizingMaskIntoConstraints = false
            let timelineStack = UIStackView()
            timelineStack.axis = .vertical
            timelineStack.spacing = 0
            timelineStack.translatesAutoresizingMaskIntoConstraints = false
            for (i, node) in nodes.enumerated() {
                let nodeView = makeTimelineNode(node: node, isLast: i == nodes.count - 1)
                timelineStack.addArrangedSubview(nodeView)
            }
            phaseCard.addSubview(phaseTitle)
            phaseCard.addSubview(timelineStack)
            NSLayoutConstraint.activate([
                phaseTitle.topAnchor.constraint(equalTo: phaseCard.topAnchor, constant: 14),
                phaseTitle.leadingAnchor.constraint(equalTo: phaseCard.leadingAnchor, constant: 16),
                timelineStack.topAnchor.constraint(equalTo: phaseTitle.bottomAnchor, constant: 12),
                timelineStack.leadingAnchor.constraint(equalTo: phaseCard.leadingAnchor, constant: 16),
                timelineStack.trailingAnchor.constraint(equalTo: phaseCard.trailingAnchor, constant: -16),
                timelineStack.bottomAnchor.constraint(equalTo: phaseCard.bottomAnchor, constant: -12),
            ])
            contentStack.addArrangedSubview(phaseCard)
        }
    }

    private func makeTimelineNode(node: TrackingNode, isLast: Bool) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // 圆点
        let dot = UIView()
        dot.layer.cornerRadius = 8
        dot.translatesAutoresizingMaskIntoConstraints = false
        switch node.status {
        case .completed:
            dot.backgroundColor = AppDesign.Color.primaryGreen
        case .inProgress:
            dot.backgroundColor = .clear
            dot.layer.borderWidth = 2.5
            dot.layer.borderColor = AppDesign.Color.primaryGreen.cgColor
            addPulse(to: dot)
        case .pending:
            dot.backgroundColor = UIColor.systemGray4
        }

        // 连接线（最后一个节点不显示）
        let line = UIView()
        line.backgroundColor = UIColor.systemGray5
        line.translatesAutoresizingMaskIntoConstraints = false
        line.isHidden = isLast

        // 标题
        let titleLabel = UILabel()
        titleLabel.text = t(node.titleKey)
        titleLabel.font = .systemFont(ofSize: 14, weight: node.status == .pending ? .regular : .semibold)
        titleLabel.textColor = node.status == .pending ? .secondaryLabel : .label
        titleLabel.textAlignment = .natural
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 副标题
        let subtitleLabel = UILabel()
        subtitleLabel.text = node.subtitle
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .natural
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 时间戳
        let timeLabel = UILabel()
        timeLabel.text = node.timestamp
        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.textColor = AppDesign.Color.primaryGreen
        timeLabel.textAlignment = .natural
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(dot)
        container.addSubview(line)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dot.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            dot.widthAnchor.constraint(equalToConstant: 16),
            dot.heightAnchor.constraint(equalToConstant: 16),

            line.topAnchor.constraint(equalTo: dot.bottomAnchor, constant: 2),
            line.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
            line.widthAnchor.constraint(equalToConstant: 2),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),

            titleLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 12),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            timeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            timeLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 100),
        ])
        return container
    }

    private func addPulse(to view: UIView) {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.35
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        view.layer.add(pulse, forKey: "pulse")
    }

    @objc private func languageChanged() {
        navigationItem.title = t(.trackingTitle)
        clearTrackingContent()
        buildContent()
    }

    private func clearTrackingContent() {
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
