import UIKit

final class RingCheckViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = t(.ringCheckTitle)
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = t(.ringCheckSimulatorUnavailable)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }
}
