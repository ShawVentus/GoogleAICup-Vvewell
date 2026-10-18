import UIKit

final class RingDetailViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = t(.ringDetailTitle)
        view.backgroundColor = .secondarySystemBackground

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = t(.ringDetailSimulatorNotice)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(card)
        card.addSubview(label)

        NSLayoutConstraint.activate([
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])
    }
}
