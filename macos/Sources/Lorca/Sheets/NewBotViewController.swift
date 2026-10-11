import AppKit

final class NewBotViewController: SheetViewController {
    private struct Look {
        let symbolName: String
        let accent: Accent
    }

    /// Older clients keep a symbol/accent fallback beside the saved plush image.
    private static let legacyLooks: [Look] = [
        Look(symbolName: "sparkles", accent: .indigo),
        Look(symbolName: "chevron.left.forwardslash.chevron.right", accent: .blue),
        Look(symbolName: "binoculars.fill", accent: .teal),
        Look(symbolName: "pencil.and.scribble", accent: .pink),
        Look(symbolName: "bolt.horizontal.fill", accent: .orange),
        Look(symbolName: "leaf.fill", accent: .green),
        Look(symbolName: "wand.and.stars", accent: .purple),
        Look(symbolName: "flame.fill", accent: .red),
    ]

    private let store = AppStore.shared
    private let nameField = NSTextField()
    private let descriptionField = WrappingTextField()
    private let runnerPopup = NSPopUpButton()
    private let providerPopup = NSPopUpButton()
    private let modelPopup = NSPopUpButton()
    private let thinkingPopup = NSPopUpButton()
    private let lookRow = Build.stack([], orientation: .horizontal, spacing: 8)
    private let note = Build.label("", font: Theme.Font.caption, color: .tertiaryLabelColor, lines: 0)

    /// Generated once for this form; selecting and editing other fields never rerolls them.
    private var looks = PlushAvatar.randomConfigurations(count: 8)
    private var lookButtons: [NewBotLookButton] = []
    private var selectedLook = 0
    private var selectedRunnerID: Device.ID?
    private var isSubmitting = false
    private var submissionError: String?

    private let onCreate: (Bot.ID) -> Void

    init(onCreate: @escaping (Bot.ID) -> Void) {
        self.onCreate = onCreate
        super.init(
            title: L("New Bot"),
            subtitle: L("A bot runs on the Runner it is assigned to, with your account's credentials and that Runner's plugins."),
            width: 440
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()

        nameField.placeholderString = L("Name")
        descriptionField.placeholderString = L("What it does and how it should work")
        descriptionField.usesSingleLineMode = false
        descriptionField.maximumNumberOfLines = 0
        descriptionField.lineBreakMode = .byWordWrapping
        descriptionField.cell?.wraps = true
        descriptionField.cell?.isScrollable = false
        for field in [nameField, descriptionField] {
            field.translatesAutoresizingMaskIntoConstraints = false
            field.delegate = self
        }

        runnerPopup.translatesAutoresizingMaskIntoConstraints = false
        selectedRunnerID = store.runners.first?.id
        rebuildRunners()
        runnerPopup.target = self
        runnerPopup.action = #selector(runnerChanged)

        providerPopup.translatesAutoresizingMaskIntoConstraints = false
        for kind in ProviderCredential.Kind.allCases {
            providerPopup.addItem(withTitle: "\(kind.rawValue) (\(kind.subtitle))")
        }
        providerPopup.target = self
        providerPopup.action = #selector(providerChanged)
        modelPopup.translatesAutoresizingMaskIntoConstraints = false
        thinkingPopup.translatesAutoresizingMaskIntoConstraints = false
        reloadModels()

        buildLookRow()

        let rows = [
            labeled(L("Name"), nameField),
            labeled(L("Description"), descriptionField, topAligned: true),
            labeled(L("Look"), lookRow),
            labeled(L("Runner"), runnerPopup),
            labeled(L("Provider"), providerPopup),
            labeled(L("Model"), modelPopup),
            labeled(L("Thinking"), thinkingPopup),
            note,
        ]
        // Width constraints need a common ancestor, so they go on after each row joins the stack.
        for row in rows {
            contentStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        }

        setButtons(confirm: L("Create Bot"))
        updateState()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        store.observe(self) { [weak self] event in
            guard let self else { return }
            switch event {
            case .snapshotReplaced, .rosterChanged:
                rebuildRunners()
                updateState()
            case .connectionChanged:
                updateState()
            default: break
            }
        }
    }

    private func rebuildRunners() {
        runnerPopup.removeAllItems()
        for device in store.runners {
            let title = device.isThisDevice ? L("%@ (this computer)", device.name) : device.name
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.representedObject = device.id
            runnerPopup.menu?.addItem(item)
        }
        // Keep the chosen identity, even if its row disappears. Never silently choose
        // the device that happens to take the removed row's former index.
        runnerPopup.select(runnerPopup.itemArray.first { $0.representedObject as? Device.ID == selectedRunnerID })
    }

    private func labeled(_ title: String, _ control: NSView, topAligned: Bool = false) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let label = Build.label(title, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        container.addSubview(label)
        container.addSubview(control)
        let labelAlignment = topAligned
            ? label.topAnchor.constraint(equalTo: control.topAnchor, constant: 6)
            : label.centerYAnchor.constraint(equalTo: control.centerYAnchor)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelAlignment,
            label.widthAnchor.constraint(equalToConstant: 76),
            control.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            control.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            control.topAnchor.constraint(equalTo: container.topAnchor),
            control.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        if control is NSTextField || control is NSPopUpButton {
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
        }
        if control === descriptionField {
            control.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        }
        return container
    }

    private func buildLookRow() {
        for (index, configuration) in looks.enumerated() {
            let button = NewBotLookButton(configuration: configuration)
            button.target = self
            button.action = #selector(pickLook(_:))
            button.tag = index
            button.identifier = NSUserInterfaceItemIdentifier("orbi.newbot.look.\(index)")

            lookButtons.append(button)
            lookRow.addArrangedSubview(button)
        }
        let shuffle = NSButton()
        shuffle.isBordered = false
        shuffle.title = ""
        shuffle.image = Glyph.symbol("shuffle", pointSize: 14, color: .secondaryLabelColor)
        shuffle.imagePosition = .imageOnly
        shuffle.target = self
        shuffle.action = #selector(shuffleLooks)
        shuffle.translatesAutoresizingMaskIntoConstraints = false
        shuffle.identifier = NSUserInterfaceItemIdentifier("orbi.newbot.shuffle-looks")
        shuffle.setAccessibilityLabel("换一组随机形象")
        shuffle.toolTip = "换一组：重新生成 8 款不同的毛绒形象"
        NSLayoutConstraint.activate([
            shuffle.widthAnchor.constraint(equalToConstant: 26),
            shuffle.heightAnchor.constraint(equalToConstant: 26),
        ])
        lookRow.addArrangedSubview(shuffle)
        updateLookSelection()
    }

    @objc private func shuffleLooks() {
        looks = PlushAvatar.randomConfigurations(count: 8)
        selectedLook = 0
        for (index, button) in lookButtons.enumerated() { button.configuration = looks[index] }
        updateLookSelection()
    }

    @objc private func pickLook(_ sender: NSButton) {
        selectedLook = sender.tag
        updateLookSelection()
    }

    private func updateLookSelection() {
        for (index, button) in lookButtons.enumerated() {
            button.isChosen = index == selectedLook
        }
    }

    private var selectedProvider: ProviderCredential.Kind {
        ProviderCredential.Kind.allCases[max(0, providerPopup.indexOfSelectedItem)]
    }

    /// nil means the provider's default model.
    private var selectedModel: String? {
        let models = selectedProvider.models
        let index = modelPopup.indexOfSelectedItem
        return index <= 0 || index > models.count ? nil : models[index - 1].id
    }

    /// nil means the provider's default thinking level.
    private var selectedThinking: String? {
        let levels = selectedProvider.thinkingLevels
        let index = thinkingPopup.indexOfSelectedItem
        return index <= 0 || index > levels.count ? nil : levels[index - 1].id
    }

    @objc private func providerChanged() {
        reloadModels()
        updateState()
    }

    private func reloadModels() {
        let models = selectedProvider.models
        modelPopup.removeAllItems()
        modelPopup.addItem(withTitle: L("Default (%@)", models.first?.label ?? ""))
        for model in models { modelPopup.addItem(withTitle: model.label) }
        modelPopup.selectItem(at: 0)
        thinkingPopup.removeAllItems()
        thinkingPopup.addItem(withTitle: L("Default"))
        for level in selectedProvider.thinkingLevels { thinkingPopup.addItem(withTitle: level.label) }
        thinkingPopup.selectItem(at: 0)
    }

    @objc private func runnerChanged() {
        selectedRunnerID = runnerPopup.selectedItem?.representedObject as? Device.ID
        updateState()
    }

    private func updateState() {
        let runner = store.runners.first { $0.id == selectedRunnerID }
        let hasName = !nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        confirmButton.isEnabled = !isSubmitting && store.isConnected && hasName && runner != nil
        confirmButton.title = isSubmitting ? "正在创建…" : L("Create Bot")
        cancelButton?.isEnabled = !isSubmitting
        for control in [nameField, descriptionField] { control.isEnabled = !isSubmitting }
        for control in [runnerPopup, providerPopup, modelPopup, thinkingPopup] { control.isEnabled = !isSubmitting }
        for case let button as NSButton in lookRow.arrangedSubviews { button.isEnabled = !isSubmitting }
        if let submissionError {
            note.stringValue = submissionError
            note.textColor = .systemRed
            return
        }
        guard store.isConnected else {
            note.stringValue = "与本机服务的连接已断开，重新连接后可继续创建。"
            note.textColor = .systemOrange
            return
        }
        guard let runner else {
            note.stringValue = L("No Runner is paired. Bots run on a Device with macOS, Linux, or Windows.")
            if !store.runners.isEmpty { note.stringValue = "原先选择的运行设备已不可用，请重新选择。" }
            note.textColor = .systemOrange
            return
        }
        let provider = selectedProvider
        if store.credential(for: provider)?.isConnected == true {
            note.stringValue = L("%@ is connected. Turns run on %@.", provider.rawValue, runner.name)
            note.textColor = .tertiaryLabelColor
        } else {
            note.stringValue =
                L("%@ is not connected yet. The bot is created now and its first turn waits until you connect it in Settings.", provider.rawValue)
            note.textColor = .systemOrange
        }
    }

    override func confirmTapped() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSubmitting, store.isConnected, !name.isEmpty,
            let runner = store.runners.first(where: { $0.id == selectedRunnerID }),
            looks.indices.contains(selectedLook) else { return }
        let look = Self.legacyLooks[selectedLook]
        let description = descriptionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatarURL: URL
        submissionError = nil
        do {
            avatarURL = try PlushAvatar.writePNG(for: looks[selectedLook], side: 512)
        } catch {
            submissionError = "形象保存失败，请重试。\n\(error.localizedDescription)"
            updateState()
            fitSheetToContent()
            return
        }

        isSubmitting = true
        updateState()
        var createdBotID: Bot.ID?
        let botID = store.createBot(
            name: name,
            description: description,
            symbolName: look.symbolName,
            accent: look.accent,
            runnerID: runner.id,
            provider: selectedProvider,
            model: selectedModel,
            thinking: selectedThinking,
            avatarFileURL: avatarURL
        ) { [weak self] result in
            guard let self else { return }
            self.isSubmitting = false
            switch result {
            case .success:
                guard let createdBotID else { return }
                self.dismiss(nil)
                self.onCreate(createdBotID)
            case .failure(let error):
                self.submissionError = "智能体未能创建，填写的内容已保留，请重试。\n\(error.localizedDescription)"
                self.updateState()
                self.fitSheetToContent()
            }
        }
        createdBotID = botID
    }

    override func dismissSheet() {
        guard !isSubmitting else { return }
        super.dismissSheet()
    }
}

extension NewBotViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        updateState()
    }
}

/// Actual plush compositions at full opacity; selection has its own outline and radio state.
private final class NewBotLookButton: NSButton {
    var configuration: PlushAvatar.Configuration {
        didSet { describeLook(); needsDisplay = true }
    }
    var isChosen = false {
        didSet {
            state = isChosen ? .on : .off
            setAccessibilityValue(isChosen ? 1 : 0)
            needsDisplay = true
        }
    }

    init(configuration: PlushAvatar.Configuration) {
        self.configuration = configuration
        super.init(frame: .zero)
        title = ""
        isBordered = false
        setButtonType(.radio)
        translatesAutoresizingMaskIntoConstraints = false
        focusRingType = .exterior
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 26),
            heightAnchor.constraint(equalToConstant: 26),
        ])
        describeLook()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }
    override var allowsVibrancy: Bool { false }

    private func describeLook() {
        let shape = PlushAvatar.shapeOptions.first { $0.id == configuration.shape }?.title ?? "星球"
        let color = PlushAvatar.palette.first { $0.hex == configuration.color }?.title ?? configuration.color
        let eyes = PlushAvatar.eyeOptions.first { $0.id == configuration.eyes }?.title ?? "眼睛"
        let glasses = PlushAvatar.glassesOptions.first { $0.id == configuration.glasses }?.title ?? "无眼镜"
        let accessory = PlushAvatar.accessoryOptions.first { $0.id == configuration.accessory }?.title ?? "无配饰"
        let label = "\(color)\(shape)，\(eyes)，\(glasses)，\(accessory)"
        setAccessibilityLabel(label)
        toolTip = label
    }

    override func draw(_ dirtyRect: NSRect) {
        if isChosen {
            NSColor.controlAccentColor.withAlphaComponent(0.14).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
        }
        AvatarView.render(.plush(configuration), in: bounds.insetBy(dx: 1, dy: 1))
        if isChosen {
            NSColor.controlAccentColor.setStroke()
            let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.8, dy: 0.8), xRadius: 6, yRadius: 6)
            outline.lineWidth = 1.6
            outline.stroke()
        }
    }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
    }
}

// MARK: - Pairing

/// Shows a pairing string for another Device to paste. The CLI runs the handshake and wraps the
/// account key to the joining machine; this sheet only polls for the outcome.
final class PairingSheetViewController: SheetViewController {
    private let store = AppStore.shared
    private var pairingString = ""
    private var nonce: String?
    private let qr = NSImageView()
    private let code = Build.label(
        L("Asking the CLI for a pairing code…"), font: .monospacedSystemFont(ofSize: 10, weight: .regular),
        color: .secondaryLabelColor, lines: 3)
    private let statusLabel = Build.label(
        L("Waiting for the other Device… Done keeps this code good for ten minutes; Cancel retires it."),
        font: .systemFont(ofSize: 12), color: .secondaryLabelColor, lines: 0)
    private let spinner = NSProgressIndicator()
    /// Covers the code once a Device has used it: a code pairs one Device, and scanning it
    /// again would only fail on the phone.
    private let pairedOverlay = BackgroundView()
    private var copy: CopyFeedbackButton?
    private var task: Task<Void, Never>?

    init() {
        super.init(
            title: L("Pair a Device"),
            subtitle:
                L("On the other Device, choose Pair in onboarding (or run `lorca pair <code>`) and paste this code. The Devices run a handshake; the relay only carries ciphertext."),
            width: 400
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()
        contentStack.alignment = .centerX

        let frame = BackgroundView()
        frame.cornerRadius = 12
        frame.fillColor = .white
        qr.translatesAutoresizingMaskIntoConstraints = false
        frame.addSubview(qr)

        pairedOverlay.cornerRadius = 12
        pairedOverlay.fillColor = NSColor.white.withAlphaComponent(0.9)
        pairedOverlay.isHidden = true
        let check = NSImageView()
        check.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: L("Paired"))
        check.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
        check.contentTintColor = .systemGreen
        check.translatesAutoresizingMaskIntoConstraints = false
        pairedOverlay.addSubview(check)
        frame.addSubview(pairedOverlay)

        let codeBox = BackgroundView()
        codeBox.cornerRadius = 8
        codeBox.fillColor = Theme.codeBackground
        code.isSelectable = true
        code.lineBreakMode = .byCharWrapping
        let copy = CopyFeedbackButton()
        copy.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: L("Copy pairing string"))
        copy.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        copy.bezelStyle = .accessoryBarAction
        copy.isBordered = false
        copy.toolTip = L("Copy pairing string")
        copy.target = self
        copy.action = #selector(copyPairingString(_:))
        copy.translatesAutoresizingMaskIntoConstraints = false
        self.copy = copy
        codeBox.addSubview(code)
        codeBox.addSubview(copy)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimation(nil)

        let status = Build.stack([spinner, statusLabel], orientation: .horizontal, spacing: 8)

        contentStack.addArrangedSubview(frame)
        contentStack.addArrangedSubview(codeBox)
        contentStack.addArrangedSubview(status)

        NSLayoutConstraint.activate([
            qr.widthAnchor.constraint(equalToConstant: 180),
            qr.heightAnchor.constraint(equalToConstant: 180),
            qr.topAnchor.constraint(equalTo: frame.topAnchor, constant: 10),
            qr.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 10),
            qr.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -10),
            qr.bottomAnchor.constraint(equalTo: frame.bottomAnchor, constant: -10),
            pairedOverlay.topAnchor.constraint(equalTo: frame.topAnchor),
            pairedOverlay.leadingAnchor.constraint(equalTo: frame.leadingAnchor),
            pairedOverlay.trailingAnchor.constraint(equalTo: frame.trailingAnchor),
            pairedOverlay.bottomAnchor.constraint(equalTo: frame.bottomAnchor),
            check.centerXAnchor.constraint(equalTo: pairedOverlay.centerXAnchor),
            check.centerYAnchor.constraint(equalTo: pairedOverlay.centerYAnchor),

            codeBox.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            code.leadingAnchor.constraint(equalTo: codeBox.leadingAnchor, constant: 10),
            code.topAnchor.constraint(equalTo: codeBox.topAnchor, constant: 8),
            code.bottomAnchor.constraint(equalTo: codeBox.bottomAnchor, constant: -8),
            copy.leadingAnchor.constraint(equalTo: code.trailingAnchor, constant: 8),
            copy.trailingAnchor.constraint(equalTo: codeBox.trailingAnchor, constant: -8),
            copy.centerYAnchor.constraint(equalTo: codeBox.centerYAnchor),
            status.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
        ])

        setButtons(confirm: L("Done"))
        begin()
    }

    private func begin() {
        if store.isMock {
            pairingString = MockData.pairingString()
            qr.image = QRCode.image(for: pairingString, size: 180)
            code.stringValue = pairingString
            return
        }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let started = try await self.store.startPairing()
                self.nonce = started.nonce
                self.pairingString = started.pairingString
                self.qr.image = QRCode.image(for: started.pairingString, size: 180)
                self.code.stringValue = started.pairingString
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                    let status = try await self.store.pairingStatus(nonce: started.nonce)
                    switch status.state {
                    case "completed":
                        self.markPaired(with: status.device?.name)
                        return
                    case "failed":
                        throw CLIClient.RequestError(message: status.error ?? L("Pairing failed"))
                    default:
                        continue
                    }
                }
            } catch is CancellationError {
            } catch {
                self.spinner.stopAnimation(nil)
                self.spinner.isHidden = true
                self.statusLabel.stringValue = error.localizedDescription
                self.statusLabel.textColor = .systemRed
            }
        }
    }

    /// The code is spent: cover it, retire the copy button, and say who joined.
    private func markPaired(with deviceName: String?) {
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        pairedOverlay.isHidden = false
        copy?.isEnabled = false
        copy?.isHidden = true
        code.stringValue = L("Paired with %@. This code is used up; pair another Device with a fresh one.", deviceName ?? L("the other Device"))
        code.font = .systemFont(ofSize: 12)
        code.textColor = .labelColor
        statusLabel.stringValue = L("Paired. The account key is wrapped to that machine.")
        statusLabel.textColor = .systemGreen
    }

    @objc private func copyPairingString(_ sender: CopyFeedbackButton) {
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(pairingString, forType: .string) {
            sender.showCopied()
        }
    }

    /// Cancel retires the code: the CLI stops waiting and the relay drops the mailbox, so a
    /// Device that pastes it afterwards is told at once.
    override func dismissSheet() {
        task?.cancel()
        if let nonce, statusLabel.textColor != .systemGreen {
            store.cancelPairing(nonce: nonce)
        }
        super.dismissSheet()
    }

    /// Done keeps the code good: the CLI goes on waiting for ten minutes, so copying the code
    /// and closing this sheet before pasting it on the phone is fine.
    override func confirmTapped() {
        task?.cancel()
        dismiss(nil)
    }
}
