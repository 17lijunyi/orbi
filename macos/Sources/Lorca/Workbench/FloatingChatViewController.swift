import AppKit

/// A second native transcript and composer share the CLI-backed conversation with the workspace.
final class FloatingChatViewController: NSViewController {
    private let store = AppStore.shared
    let chat = ChatViewController()
    private let offline = Build.label("", font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
    private(set) var chatID: Chat.ID?
    var onChatChange: (() -> Void)?
    var onClose: (() -> Void)?

    override func loadView() {
        let container = BackgroundView()
        addChild(chat)
        chat.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chat.view)
        container.addSubview(chat.composer)
        container.addSubview(offline)
        NSLayoutConstraint.activate([
            chat.view.topAnchor.constraint(equalTo: container.topAnchor),
            chat.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chat.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            chat.view.bottomAnchor.constraint(equalTo: chat.composer.topAnchor, constant: -8),
            chat.composer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            chat.composer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            chat.composer.bottomAnchor.constraint(equalTo: offline.topAnchor, constant: -6),
            offline.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            offline.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        ])
        chat.onRedirect = { [weak self] id in self?.show(id) }
        chat.composer.onCancel = { [weak self] in self?.onClose?(); return true }
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        store.observe(self) { [weak self] event in
            switch event {
            case .connectionChanged, .snapshotReplaced: self?.refreshConnection()
            case .chatChanged, .rosterChanged, .chatsChanged: self?.onChatChange?()
            default: break
            }
        }
        refreshConnection()
    }

    func show(_ id: Chat.ID) {
        _ = view
        chatID = id
        chat.show(chatID: id)
        refreshConnection()
        onChatChange?()
    }

    func languageChanged() {
        if let chatID { chat.show(chatID: chatID) }
        refreshConnection()
    }

    func focus() { chat.focusComposer() }
    func suspend() { chat.composer.endInteraction() }

    private func refreshConnection() {
        guard isViewLoaded else { return }
        let connected = store.isConnected && chatID.flatMap { store.chat($0) } != nil
        chat.composer.isSendingEnabled = connected
        offline.stringValue = connected ? L("Same conversation as your workspace") : L("Disconnected · your draft stays here")
    }
}
