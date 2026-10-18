import UIKit

final class ThermalColorBarView: UIView {

    private let gradientLayer = CAGradientLayer()
    private let maxLabel = UILabel()
    private let minLabel = UILabel()
    private let avgIndicator = UIView()
    private let avgLabel = UILabel()

    var minTemp: Float = 20.0 {
        didSet { updateLabels() }
    }
    var maxTemp: Float = 40.0 {
        didSet { updateLabels() }
    }
    var avgTemp: Float = 30.0 {
        didSet { updateIndicator() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 8
        clipsToBounds = true

        gradientLayer.colors = [
            UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1).cgColor,
            UIColor(red: 0.95, green: 0.7, blue: 0.1, alpha: 1).cgColor,
            UIColor(red: 0.3, green: 0.85, blue: 0.2, alpha: 1).cgColor,
            UIColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1).cgColor
        ]
        gradientLayer.locations = [0.0, 0.33, 0.66, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gradientLayer)

        maxLabel.font = .systemFont(ofSize: 11, weight: .medium)
        maxLabel.textColor = .label
        maxLabel.textAlignment = .center
        maxLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(maxLabel)

        minLabel.font = .systemFont(ofSize: 11, weight: .medium)
        minLabel.textColor = .label
        minLabel.textAlignment = .center
        minLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(minLabel)

        avgIndicator.backgroundColor = .white
        avgIndicator.layer.cornerRadius = 3
        avgIndicator.layer.borderWidth = 1
        avgIndicator.layer.borderColor = UIColor.black.cgColor
        avgIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(avgIndicator)

        avgLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        avgLabel.textColor = .white
        avgLabel.layer.cornerRadius = 4
        avgLabel.layer.masksToBounds = true
        avgLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        avgLabel.textAlignment = .center
        avgLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(avgLabel)

        NSLayoutConstraint.activate([
            maxLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            maxLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            maxLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            minLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            minLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            minLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            avgIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            avgIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            avgIndicator.heightAnchor.constraint(equalToConstant: 6),

            avgLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            avgLabel.widthAnchor.constraint(equalToConstant: 48),
            avgLabel.heightAnchor.constraint(equalToConstant: 16),
        ])

        updateLabels()
        updateIndicator()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds.inset(by: UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0))
        updateIndicator()
    }

    private func updateLabels() {
        maxLabel.text = String(format: "%.1f°C", maxTemp)
        minLabel.text = String(format: "%.1f°C", minTemp)
    }

    private func updateIndicator() {
        let range = maxTemp - minTemp
        guard range > 0 else { return }
        let ratio = CGFloat((avgTemp - minTemp) / range)
        let clamped = max(0, min(1, ratio))
        let gradientTop: CGFloat = 20
        let gradientHeight = bounds.height - 40
        let y = gradientTop + (1 - clamped) * gradientHeight - 3
        avgIndicator.frame.origin.y = y
        avgLabel.text = String(format: "%.1f°", avgTemp)
        avgLabel.frame.origin.y = y - 20
    }
}
