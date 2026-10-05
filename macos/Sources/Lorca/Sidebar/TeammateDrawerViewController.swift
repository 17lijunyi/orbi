import AppKit

/// A group draft takes the sidebar's place while the current conversation remains visible.
final class TeammateDrawerViewController: NSViewController, NSSearchFieldDelegate {
    private let store = AppStore.shared
    private let nameField = NSTextField()
    private let search = NSSearchField()
    private let count = Build.label("", font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor)
    private let empty = Build.label("", font: .systemFont(ofSize: 12), color: .secondaryLabelColor, lines: 0, alignment: .center)
    private let rowsStack = Build.stack([], spacing: 8)
    private let scroll = NSScrollView()
    private let document = FlippedView()
    private let createButton = NSButton()
    private let backButton = NSButton()
    private var selected: [Bot.ID] = []
    private var rows: [Bot.ID: SelectableBotRow] = [:]
    private var seededSelection = false

    var onCreate: (([Bot.ID], String?) -> Void)?
    var onBack: (() -> Void)?

    override func loadView() {
        let container = NSView()
        nameField.placeholderString = L("Group name (optional)")
        nameField.setAccessibilityLabel(L("Group name (optional)"))
        nameField.font = .systemFont(ofSize: 13)
        nameField.translatesAutoresizingMaskIntoConstraints = false
        search.placeholderString = L("Search in Teammates")
        search.setAccessibilityLabel(L("Search in Teammates"))
        search.delegate = self
        search.target = self
        search.action = #selector(searchChanged)
        search.sendsSearchStringImmediately = true
        search.translatesAutoresizingMaskIntoConstraints = false

        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(rowsStack)
        rowsStack.pin(to: document)
        scroll.documentView = document
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        for (button, title, selector) in [
            (createButton, L("Create Group Chat"), #selector(createGroup)),
            (backButton, L("Back"), #selector(back)),
        ] {
            button.title = title
            button.setAccessibilityLabel(title)
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.target = self
            button.action = selector
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        }
        let footer = Build.stack([createButton, backButton], spacing: 8)
        [count, nameField, search, scroll, footer].forEach { container.addSubview($0) }
        NSLayoutConstraint.activate([
            count.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            count.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            count.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            nameField.topAnchor.constraint(equalTo: count.bottomAnchor, constant: 14),
            nameField.leadingAnchor.constraint(equalTo: count.leadingAnchor),
            nameField.trailingAnchor.constraint(equalTo: count.trailingAnchor),
            nameField.heightAnchor.constraint(equalToConstant: 30),
            search.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 12),
            search.leadingAnchor.constraint(equalTo: count.leadingAnchor),
            search.trailingAnchor.constraint(equalTo: count.trailingAnchor),
            search.heightAnchor.constraint(equalToConstant: 30),
            scroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 14),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -12),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            footer.leadingAnchor.constraint(equalTo: count.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: count.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            createButton.widthAnchor.constraint(equalTo: footer.widthAnchor),
            backButton.widthAnchor.constraint(equalTo: footer.widthAnchor),
        ])
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rebuild()
        store.observe(self) { [weak self] event in
            switch event {
            case .snapshotReplaced, .rosterChanged, .connectionChanged: self?.rebuild()
            default: break
            }
        }
    }

    func focusName() { view.window?.makeFirstResponder(nameField) }

    func languageChanged() {
        guard isViewLoaded else { return }
        nameField.placeholderString = L("Group name (optional)")
        nameField.setAccessibilityLabel(L("Group name (optional)"))
        search.placeholderString = L("Search in Teammates")
        search.setAccessibilityLabel(L("Search in Teammates"))
        createButton.title = L("Create Group Chat")
        createButton.setAccessibilityLabel(createButton.title)
        backButton.title = L("Back")
        backButton.setAccessibilityLabel(backButton.title)
        rebuild()
    }

    func controlTextDidChange(_ obj: Notification) { rebuild() }
    @objc private func searchChanged() { rebuild() }

    private func rebuild() {
        guard isViewLoaded else { return }
        if !seededSelection, !store.bots.isEmpty {
            selected = Array(store.bots.prefix(2).map(\.id))
            seededSelection = true
        }
        selected.removeAll { store.bot($0) == nil }
        let query = search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = store.bots.filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.description.localizedCaseInsensitiveContains(query)
        }
        rowsStack.arrangedSubviews.forEach { rowsStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        rows = [:]
        for bot in visible {
            let host = store.device(bot.runnerID)
            let row = SelectableBotRow()
            row.configure(bot: bot, detail: host?.name ?? L("unassigned"), isOffline: host?.status == .offline)
            row.onToggle = { [weak self] in self?.toggle(bot.id) }
            rows[bot.id] = row
            rowsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
            row.heightAnchor.constraint(equalToConstant: 60).isActive = true
        }
        if visible.isEmpty {
            empty.stringValue = store.bots.isEmpty ? L("Create a teammate with the planet button to build your team.") : L("No teammates found")
            rowsStack.addArrangedSubview(empty)
            empty.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
            empty.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        }
        updateState()
    }

    private func toggle(_ id: Bot.ID) {
        if let index = selected.firstIndex(of: id) { selected.remove(at: index) }
        else if selected.count < Chat.maxGroupBots { selected.append(id) }
        else { NSSound.beep() }
        updateState()
    }

    private func updateState() {
        count.stringValue = L("%d of %d teammates selected", selected.count, Chat.maxGroupBots)
        for (id, row) in rows {
            row.isSelected = selected.contains(id)
            row.isEnabled = store.isConnected && (row.isSelected || selected.count < Chat.maxGroupBots)
        }
        createButton.isEnabled = store.isConnected && !selected.isEmpty
    }

    @objc private func createGroup() {
        selected.removeAll { store.bot($0) == nil }
        guard store.isConnected, !selected.isEmpty else { updateState(); return }
        let title = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        onCreate?(selected, title.isEmpty ? nil : title)
    }

    @objc private func back() { onBack?() }
}
