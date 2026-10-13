import AppKit

/// One installed plugin on a Runner: its state, the sign-in for a remote server, its
/// variables (a secret is written, never read back), the skills it brought, and Remove. From a
/// DM's inspector it also shows the Always allowed rules for its tools.
final class PluginViewController: SheetViewController {
    private let store = AppStore.shared
    private let pluginID: String
    private let runner: Device

    private let status = SectionView(title: L("Status"))
    private let signIn = SectionView(title: L("Sign-in"))
    private let variables = SectionView(title: L("Setup", context: "plugin variables"))
    private let skills = SectionView(title: L("Skills"))
    private let saveButton = NSButton()
    private let removeButton = NSButton()
    private let note = Build.label(
        "", font: Theme.Font.caption, color: .secondaryLabelColor, lines: 0)

    private var fields: [(name: String, field: NSTextField)] = []
    private var fieldValues: [String: String] = [:]
    private var variableDefinitions: [PluginDetail.Variable] = []
    private var isSaving = false
    private var lifecycle = 0
    private var isDismissed = false
    /// Only the newest load renders, so an older answer arriving late (a sealed request to
    /// another Runner) never covers a newer one, such as the detail with a sign-in code.
    private var loads = 0

    init(pluginID: String, runner: Device, bot: Bot?) {
        self.pluginID = pluginID
        self.runner = runner
        let plugin = runner.plugins.first { $0.id == pluginID }
        super.init(
            title: L(plugin?.name ?? pluginID),
            subtitle: [L(plugin?.description ?? ""), L("Installed on %@.", runner.name)].filter {
                !$0.isEmpty
            }.joined(separator: " "),
            width: 520
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        saveButton.title = L("Save")
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(save)
        removeButton.title = L("Remove…")
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(confirmRemove)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let actions = Build.stack(
            [saveButton, spacer, removeButton], orientation: .horizontal, spacing: 8)

        for section in [status, signIn, variables, skills] {
            contentStack.addArrangedSubview(section)
            section.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        }
        contentStack.addArrangedSubview(note)
        contentStack.addArrangedSubview(actions)
        NSLayoutConstraint.activate([
            note.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            actions.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
        ])
        setButtons(confirm: L("Done"), cancel: nil)
        status.setRows([KeyValueRow(key: L("State"), value: L("Loading…"), tint: .secondaryLabelColor)])
        signIn.isHidden = true
        variables.isHidden = true
        skills.isHidden = true
        saveButton.isHidden = true
        note.stringValue =
            runner.isThisDevice
            ? L("Keys and sign-ins stay on this device.")
            : L("Keys and sign-ins are sent sealed to %@ and stay there. A sign-in opens the browser on %@.", runner.name, runner.name)
        load()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        store.observe(self) { [weak self] event in
            switch event {
            case .rosterChanged, .snapshotReplaced:
                // The Runner's state moved (a sign-in finished, a connection failed).
                self?.load()
            default:
                break
            }
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        isDismissed = true
        lifecycle += 1
        loads += 1
        setSaving(false)
    }

    private func load() {
        guard !isDismissed else { return }
        loads += 1
        let load = loads
        Task { [weak self] in
            guard let self, load == self.loads else { return }
            do {
                let detail = try await self.store.pluginDetail(self.pluginID, on: self.runner.id)
                guard load == self.loads else { return }
                self.render(detail)
            } catch {
                guard load == self.loads else { return }
                self.status.setRows([
                    KeyValueRow(key: L("State"), value: error.localizedDescription, tint: .systemRed)
                ])
                self.fitSheetToContent()
            }
        }
    }

    private func render(_ detail: PluginDetail) {
        var statusRows: [NSView] = [
            KeyValueRow(key: L("State"), value: detail.status.detail, tint: detail.status.stateColor)
        ]
        let rules = store.autoReview.rules.filter { $0.tool?.hasPrefix("\(pluginID)/") == true }
        if !rules.isEmpty {
            let always = ActionRow(
                key: L("Always allowed", context: "plugin tools"),
                value: rules.map { String(($0.tool ?? "").dropFirst(pluginID.count + 1)) }.joined(
                    separator: ", "), tint: .labelColor, actionTitle: L("Reset"))
            always.onAction = { [weak self] in
                guard let self else { return }
                var review = self.store.autoReview
                review.rules.removeAll { $0.tool?.hasPrefix("\(self.pluginID)/") == true }
                self.store.setAutoReview(review)
                self.render(detail)
            }
            statusRows.append(always)
        }
        if let homepage = detail.homepage, let url = URL(string: homepage) {
            let site = ActionRow(
                key: L("Site"), value: url.host ?? homepage, tint: .secondaryLabelColor,
                actionTitle: L("Open"))
            site.onAction = { NSWorkspace.shared.open(url) }
            statusRows.append(site)
        }
        status.setRows(statusRows)

        let oauthServers = detail.servers.filter(\.oauth)
        signIn.isHidden = oauthServers.isEmpty
        signIn.setRows(
            oauthServers.map { server in
                let key = oauthServers.count > 1 ? server.name : L("Account")
                // A device-flow sign-in waits for its code: the code, and the chat card's
                // button, which copies it and opens the page to enter it on.
                if let code = server.code, let link = server.link.flatMap(URL.init(string:)) {
                    let row = ActionRow(
                        key: key, value: code, tint: .labelColor,
                        actionTitle: L("Copy code and open %@", link.host ?? L("link")), monospaced: true)
                    row.onAction = { [weak row] in
                        NSPasteboard.general.clearContents()
                        if NSPasteboard.general.setString(code, forType: .string) { row?.showCopied() }
                        NSWorkspace.shared.open(link)
                    }
                    return row
                }
                let row = ActionRow(
                    key: key,
                    value: server.signedIn ? L("Signed in") : L("Not signed in"),
                    tint: server.signedIn ? .systemGreen : .secondaryLabelColor,
                    actionTitle: server.signedIn ? L("Sign in again") : L("Sign in"))
                row.onAction = { [weak self] in self?.connect() }
                return row
            })

        // Presence and sign-in changes refresh this sheet too. Keep edits (including secrets)
        // and the active field editor while updating values the user has not changed.
        let rebuildFields = variableDefinitions.count != detail.variables.count
            || zip(variableDefinitions, detail.variables).contains { old, new in
                old.name != new.name || old.secret != new.secret
                    || old.required != new.required || old.description != new.description
            }
        let previousFields = Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0.field) })
        fields = detail.variables.map { variable in
            let previous = previousFields[variable.name]
            let sameKind = previous.map { ($0 is NSSecureTextField) == variable.secret } ?? false
            let field = sameKind ? previous! : (variable.secret ? NSSecureTextField() : NSTextField())
            let value = variable.secret ? "" : (variable.value ?? "")
            if !sameKind || field.stringValue == fieldValues[variable.name] {
                field.stringValue = value
            }
            fieldValues[variable.name] = value
            field.placeholderString = variable.secret
                ? (variable.isSet ? L("Set · type to replace") : L("Not set"))
                : (variable.isSet ? "" : L("Not set"))
            field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            field.controlSize = .small
            field.toolTip = L(variable.description)
            field.isEnabled = !isSaving
            return (variable.name, field)
        }
        fieldValues = fieldValues.filter { previous in detail.variables.contains { $0.name == previous.key } }
        variableDefinitions = detail.variables
        variables.isHidden = detail.variables.isEmpty
        saveButton.isHidden = detail.variables.isEmpty
        if rebuildFields {
            variables.setRows(zip(detail.variables, fields).map { variable, entry in
                FieldRow(key: variable.name + (variable.required ? " *" : ""), field: entry.field)
            })
        }

        skills.isHidden = detail.skills.isEmpty
        skills.setRows(detail.skills.map { KeyValueRow(key: L($0.name), value: L($0.description)) })
        fitSheetToContent()
    }

    @objc private func save() {
        guard !isSaving else { return }
        var values: [String: String] = [:]
        for (name, field) in fields
        where !field.stringValue.isEmpty || !(field is NSSecureTextField) {
            values[name] = field.stringValue
        }
        setSaving(true)
        let generation = lifecycle
        Task { [weak self] in
            guard let self, generation == self.lifecycle else { return }
            defer { if generation == self.lifecycle { self.setSaving(false) } }
            do {
                _ = try await self.store.setPluginVariables(
                    self.pluginID, on: self.runner.id, variables: values)
                guard generation == self.lifecycle else { return }
                // Only acknowledged values become the baseline. Secrets are never shown
                // again after saving; failures keep every draft available for retry.
                for (name, field) in self.fields {
                    if field is NSSecureTextField { field.stringValue = "" }
                    self.fieldValues[name] = field.stringValue
                }
                self.load()
            } catch {
                guard generation == self.lifecycle else { return }
                self.alert(L("Couldn't save"), error.localizedDescription)
            }
        }
    }

    private func setSaving(_ saving: Bool) {
        isSaving = saving
        saveButton.isEnabled = !saving
        removeButton.isEnabled = !saving
        confirmButton.isEnabled = !saving
        for (_, field) in fields { field.isEnabled = !saving }
    }

    override func dismissSheet() {
        guard !isSaving else { return }
        super.dismissSheet()
    }

    override func confirmTapped() {
        guard !isSaving else { return }
        super.confirmTapped()
    }

    private func connect() {
        guard !isSaving else { return }
        let generation = lifecycle
        Task { [weak self] in
            guard let self, generation == self.lifecycle else { return }
            do {
                // The Runner notes the sign-in on the plugin, so the State row reads it.
                try await self.store.connectPlugin(self.pluginID, on: self.runner.id)
                guard generation == self.lifecycle else { return }
                self.load()
            } catch {
                guard generation == self.lifecycle else { return }
                self.alert(L("Couldn't start the sign-in"), error.localizedDescription)
            }
        }
    }

    @objc private func confirmRemove() {
        guard !isSaving, let window = view.window else { return }
        let generation = lifecycle
        let name = runner.plugins.first { $0.id == pluginID }?.name ?? pluginID
        let alert = NSAlert()
        alert.messageText = L("Remove %@ from %@?", name, runner.name)
        alert.informativeText =
            L("Every bot on %@ loses it, and its keys and sign-ins there are forgotten.", runner.name)
        alert.addButton(withTitle: L("Remove"))
        alert.addButton(withTitle: L("Cancel"))
        alert.alertStyle = .warning
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, generation == self.lifecycle, response == .alertFirstButtonReturn else { return }
            Task { [weak self] in
                guard let self, generation == self.lifecycle else { return }
                do {
                    try await self.store.uninstallPlugin(self.pluginID, on: self.runner.id)
                    guard generation == self.lifecycle else { return }
                    self.dismiss(nil)
                } catch {
                    guard generation == self.lifecycle else { return }
                    self.alert(L("Couldn't remove it"), error.localizedDescription)
                }
            }
        }
    }

    private func alert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        if let window = view.window { alert.beginSheetModal(for: window) }
    }
}

/// Key on the left, a bordered field on the right, inside a section card.
final class FieldRow: NSView {
    init(key keyText: String, field: NSTextField) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let key = Build.label(
            keyText, font: .monospacedSystemFont(ofSize: 11, weight: .regular),
            color: .secondaryLabelColor)
        key.setContentCompressionResistancePriority(.required, for: .horizontal)
        field.translatesAutoresizingMaskIntoConstraints = false
        addSubview(key)
        addSubview(field)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 34),
            key.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            key.centerYAnchor.constraint(equalTo: centerYAnchor),
            field.leadingAnchor.constraint(greaterThanOrEqualTo: key.trailingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
            field.widthAnchor.constraint(equalToConstant: 230),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
