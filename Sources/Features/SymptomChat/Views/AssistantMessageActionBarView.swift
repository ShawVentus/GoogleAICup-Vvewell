import UIKit

final class AssistantMessageActionBarView: UIView {
    var onCopy: (() -> Void)?
    var onLike: (() -> Void)?
    var onDislike: (() -> Void)?
    var onRegenerate: (() -> Void)?
    var onPreviousVersion: (() -> Void)?
    var onNextVersion: (() -> Void)?

    private let stackView = UIStackView()
    private let copyButton = UIButton(type: .system)
    private let likeButton = UIButton(type: .system)
    private let dislikeButton = UIButton(type: .system)
    private let regenerateButton = UIButton(type: .system)
    private let previousVersionButton = UIButton(type: .system)
    private let nextVersionButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        addSubview(stackView)

        [copyButton, likeButton, dislikeButton, regenerateButton, previousVersionButton, nextVersionButton].forEach {
            configure(button: $0)
            stackView.addArrangedSubview($0)
        }

        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        likeButton.addTarget(self, action: #selector(likeTapped), for: .touchUpInside)
        dislikeButton.addTarget(self, action: #selector(dislikeTapped), for: .touchUpInside)
        regenerateButton.addTarget(self, action: #selector(regenerateTapped), for: .touchUpInside)
        previousVersionButton.addTarget(self, action: #selector(previousVersionTapped), for: .touchUpInside)
        nextVersionButton.addTarget(self, action: #selector(nextVersionTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(feedback: ChatFeedbackKind?, canRegenerate: Bool, hasPreviousVersion: Bool, hasNextVersion: Bool) {
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        likeButton.setImage(UIImage(systemName: feedback == .like ? "hand.thumbsup.fill" : "hand.thumbsup"), for: .normal)
        dislikeButton.setImage(UIImage(systemName: feedback == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown"), for: .normal)
        regenerateButton.setImage(UIImage(systemName: canRegenerate ? "arrow.clockwise" : "arrow.clockwise.circle"), for: .normal)
        previousVersionButton.setImage(UIImage(systemName: "chevron.left.circle"), for: .normal)
        nextVersionButton.setImage(UIImage(systemName: "chevron.right.circle"), for: .normal)

        likeButton.tintColor = feedback == .like ? AppDesign.Color.primaryGreen : .secondaryLabel
        dislikeButton.tintColor = feedback == .dislike ? .systemOrange : .secondaryLabel
        regenerateButton.tintColor = canRegenerate ? AppDesign.Color.primaryGreen : .tertiaryLabel
        regenerateButton.isEnabled = canRegenerate
        previousVersionButton.isHidden = !hasPreviousVersion
        nextVersionButton.isHidden = !hasNextVersion
        previousVersionButton.isEnabled = hasPreviousVersion
        nextVersionButton.isEnabled = hasNextVersion
    }

    private func configure(button: UIButton) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .secondaryLabel
        button.backgroundColor = AppDesign.Surface.secondaryCard
        button.layer.cornerRadius = AppDesign.ControlSize.assistantActionButton / 2
        button.layer.borderWidth = 1
        button.layer.borderColor = AppDesign.Surface.border.cgColor
        button.widthAnchor.constraint(equalToConstant: AppDesign.ControlSize.assistantActionButton).isActive = true
        button.heightAnchor.constraint(equalToConstant: AppDesign.ControlSize.assistantActionButton).isActive = true
        button.contentHorizontalAlignment = .center
    }

    @objc private func copyTapped() { onCopy?() }
    @objc private func likeTapped() { onLike?() }
    @objc private func dislikeTapped() { onDislike?() }
    @objc private func regenerateTapped() { onRegenerate?() }
    @objc private func previousVersionTapped() { onPreviousVersion?() }
    @objc private func nextVersionTapped() { onNextVersion?() }
}
