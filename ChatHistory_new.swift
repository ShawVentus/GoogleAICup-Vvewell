import UIKit

@MainActor
final class ChatHistoryViewController: UIViewController {
    private let coordinator: SymptomChatSessionCoordinator
    private let onSelect: (LocalChatSession) -> Void
    private let onDelete: ([LocalChatSession]) -> Void

    private var sections: [LocalChatHistorySection] = []
    private var isSelectionMode = false {
        didSet { updateSelectionModeUI() }
    }
    private var selectedSessionIds = Set<String>() {
        didSet { updateSelectionModeTitle() }
    }

    private var hasHistoryContent: Bool { !sections.isEmpty }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let deleteBar = UIView()
    private let deleteButton = UIButton(type: .system)
    private lazy var longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = localizedEmptyStateMessage()
        label.isHidden = true
        return label
    }()

    init(
        coordinator: SymptomChatSessionCoordinator,
        onSelect: @escaping (LocalChatSession) -> Void,
        onDelete: @escaping ([LocalChatSession]) -> Void
    ) {
        self.coordinator = coordinator
        self.onSelect = onSelect
        self.onDelete = onDelete
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = localizedHistoryPageTitle()
        setupTableView()
        setupEmptyStateView()
        setupDeleteBar()
        reloadData()
        showHintIfNeeded()
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(ChatHistorySessionCell.self, forCellReuseIdentifier: ChatHistorySessionCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)

        tableView.addGestureRecognizer(longPressGestureRecognizer)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupEmptyStateView() {
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }

    private func setupDeleteBar() {
        deleteBar.translatesAutoresizingMaskIntoConstraints = false
        deleteBar.backgroundColor = .systemBackground
        deleteBar.isHidden = true
        deleteBar.layer.shadowColor = UIColor.black.cgColor
        deleteBar.layer.shadowOpacity = 0.05
        deleteBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        deleteBar.layer.shadowRadius = 8
        view.addSubview(deleteBar)

        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.setTitle(localizedDeleteLabel(), for: .normal)
        deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        deleteButton.addTarget(self, action: #selector(deleteSelectedTapped), for: .touchUpInside)
        deleteBar.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            deleteBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            deleteBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            deleteBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            deleteBar.heightAnchor.constraint(equalToConstant: 60),

            deleteButton.centerXAnchor.constraint(equalTo: deleteBar.centerXAnchor),
            deleteButton.centerYAnchor.constraint(equalTo: deleteBar.centerYAnchor),
        ])

        tableView.contentInset.bottom = 76
        tableView.verticalScrollIndicatorInsets.bottom = 76
    }

    private func reloadData() {
        sections = coordinator.visibleHistorySections()
        let availableSessionIds = Set(sections.flatMap(\.sessions).map(\.id))
        let validSelectedSessionIds = selectedSessionIds.intersection(availableSessionIds)
        if validSelectedSessionIds != selectedSessionIds {
            selectedSessionIds = validSelectedSessionIds
        }
        if !hasHistoryContent {
            if isSelectionMode {
                isSelectionMode = false
            } else if !selectedSessionIds.isEmpty {
                selectedSessionIds.removeAll()
            }
        } else if isSelectionMode && selectedSessionIds.isEmpty {
            isSelectionMode = false
        }
        emptyStateLabel.isHidden = hasHistoryContent
        tableView.isHidden = !hasHistoryContent
        tableView.isUserInteractionEnabled = hasHistoryContent
        longPressGestureRecognizer.isEnabled = hasHistoryContent
        tableView.reloadData()
    }

    private func showHintIfNeeded() {
        guard hasHistoryContent, presentedViewController == nil, SymptomChatHistoryStore.shared.shouldShowHistoryHint() else { return }
        let alert = UIAlertController(title: nil, message: localizedLongPressHintMessage(), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.confirm), style: .default) { _ in
            SymptomChatHistoryStore.shared.setHistoryHintShown()
        })
        present(alert, animated: true)
    }

    private func updateSelectionModeUI() {
        let showsSelectionUI = isSelectionMode && hasHistoryContent
        deleteBar.isHidden = !showsSelectionUI
        tableView.allowsMultipleSelection = showsSelectionUI
        navigationItem.leftBarButtonItem = showsSelectionUI
            ? UIBarButtonItem(title: t(.cancel), style: .plain, target: self, action: #selector(cancelSelectionMode))
            : nil
        if !showsSelectionUI {
            selectedSessionIds.removeAll()
            title = localizedHistoryPageTitle()
        } else {
            updateSelectionModeTitle()
        }
        tableView.reloadData()
    }

    private func updateSelectionModeTitle() {
        guard isSelectionMode else { return }
        title = localizedSelectionTitle(count: selectedSessionIds.count)
    }

    @objc private func cancelSelectionMode() {
        isSelectionMode = false
    }

    @objc private func deleteSelectedTapped() {
        guard hasHistoryContent else { return }
        let targets = sections.flatMap(\.sessions).filter { selectedSessionIds.contains($0.id) }
        guard !targets.isEmpty else { return }
        let alert = UIAlertController(title: nil, message: localizedDeleteConfirmationMessage(), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: t(.cancel), style: .cancel))
        alert.addAction(UIAlertAction(title: localizedDeleteLabel(), style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.onDelete(targets)
            self.isSelectionMode = false
            self.reloadData()
        })
        present(alert, animated: true)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard hasHistoryContent, gesture.state == .began else { return }
        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location) else { return }
        let session = sections[indexPath.section].sessions[indexPath.row]
        isSelectionMode = true
        selectedSessionIds.insert(session.id)
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

extension ChatHistoryViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].sessions.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ChatHistorySessionCell.reuseID, for: indexPath) as? ChatHistorySessionCell else {
            return UITableViewCell()
        }
        let session = sections[indexPath.section].sessions[indexPath.row]
        cell.configure(session: session, selected: selectedSessionIds.contains(session.id), selectionMode: isSelectionMode)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let session = sections[indexPath.section].sessions[indexPath.row]
        if isSelectionMode {
            if selectedSessionIds.contains(session.id) {
                selectedSessionIds.remove(session.id)
            } else {
                selectedSessionIds.insert(session.id)
            }
            if selectedSessionIds.isEmpty {
                isSelectionMode = false
            } else {
                updateSelectionModeTitle()
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            return
        }
        onSelect(session)
        navigationController?.popViewController(animated: true)
    }
}

private final class ChatHistorySessionCell: UITableViewCell {
    static let reuseID = "ChatHistorySessionCell"

    private let card = UIView()
    private let timeLabel = UILabel()
    private let userLabel = UILabel()
    private let assistantLabel = UILabel()
    private let checkmarkView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.8)
        card.layer.cornerRadius = 16
        contentView.addSubview(card)

        [timeLabel, userLabel, assistantLabel, checkmarkView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview($0)
        }

        timeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        timeLabel.textColor = .secondaryLabel
        userLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        userLabel.textColor = .label
        assistantLabel.font = .systemFont(ofSize: 13)
        assistantLabel.textColor = .secondaryLabel
        assistantLabel.numberOfLines = 2
        checkmarkView.tintColor = .label
        checkmarkView.isHidden = true

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            timeLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            timeLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            timeLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkView.leadingAnchor, constant: -8),

            checkmarkView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            checkmarkView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            checkmarkView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkView.heightAnchor.constraint(equalToConstant: 20),

            userLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 8),
            userLabel.leadingAnchor.constraint(equalTo: timeLabel.leadingAnchor),
            userLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            assistantLabel.topAnchor.constraint(equalTo: userLabel.bottomAnchor, constant: 6),
            assistantLabel.leadingAnchor.constraint(equalTo: userLabel.leadingAnchor),
            assistantLabel.trailingAnchor.constraint(equalTo: userLabel.trailingAnchor),
            assistantLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(session: LocalChatSession, selected: Bool, selectionMode: Bool) {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        timeLabel.text = formatter.string(from: Date(timeIntervalSince1970: session.updatedAt))
        userLabel.text = session.userPreview
        assistantLabel.text = session.assistantPreview.isEmpty ? localizedEmptyPreview() : session.assistantPreview
        checkmarkView.isHidden = !selectionMode
        checkmarkView.tintColor = selected ? .label : .quaternaryLabel
        card.layer.borderWidth = selected ? 1.5 : 0
        card.layer.borderColor = UIColor.label.cgColor
    }
}


private func localizedHistoryPageTitle() -> String {
    t(.symptomChatHistoryPageTitle)
}

private func localizedLongPressHintMessage() -> String {
    t(.symptomChatHistoryLongPressHint)
}

private func localizedSelectionTitle(count: Int) -> String {
    String(format: t(.symptomChatHistorySelectionTitleFormat), count)
}

private func localizedDeleteLabel() -> String {
    t(.symptomChatHistoryDeleteLabel)
}

private func localizedDeleteConfirmationMessage() -> String {
    t(.symptomChatHistoryDeleteConfirmationMessage)
}

private func localizedEmptyStateMessage() -> String {
    t(.symptomChatHistoryEmptyState)
}

private func localizedEmptyPreview() -> String {
    "—"
}
