import AppKit

/// Single-select variant used when adding a bot to an existing chat.
final class BotPickerViewController: SheetViewController {
    private let bots: [Bot]
    private let onPick: (Bot.ID) -> Void
    private var selected: Bot.ID?
    private var rows: [Bot.ID: SelectableBotRow] = [:]

    init(title: String, bots: [Bot], onPick: @escaping (Bot.ID) -> Void) {
        self.bots = bots
        self.onPick = onPick
        super.init(title: title, subtitle: L("A group chat holds up to six bots."), width: 420)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        super.loadView()

        let store = AppStore.shared
        let list = SectionView(title: L("Available"))
        list.setRows(
            bots.map { bot in
                let host = store.device(bot.runnerID)
                let row = SelectableBotRow()
                row.configure(
                    bot: bot,
                    detail: "\(bot.provider.rawValue) · \(host?.name ?? L("unassigned"))",
                    isOffline: host?.status == .offline
                )
                row.onToggle = { [weak self] in self?.select(bot.id) }
                rows[bot.id] = row
                return row
            })

        contentStack.addArrangedSubview(list)
        list.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        setButtons(confirm: L("Add"))
        if let first = bots.first { select(first.id) }
    }

    private func select(_ id: Bot.ID) {
        selected = id
        for (rowID, row) in rows { row.isSelected = rowID == id }
        confirmButton.isEnabled = true
    }

    override func confirmTapped() {
        guard let selected else { return }
        onPick(selected)
        dismiss(nil)
    }
}

final class SelectableBotRow: NSButton {
    private let check = NSImageView()
    private let avatar = AvatarView(diameter: 28)
    private let name = Build.label("", font: .systemFont(ofSize: 13, weight: .medium))
    private let detail = Build.label("", font: Theme.Font.caption, color: .secondaryLabelColor)
    private let offline = Build.label(
        L("offline"), font: .systemFont(ofSize: 10, weight: .medium), color: .systemOrange)
    private var tracking: NSTrackingArea?
    private var isHovered = false { didSet { needsDisplay = true } }

    var onToggle: (() -> Void)?

    var isSelected = false {
        didSet {
            check.image = NSImage(
                systemSymbolName: isSelected ? "checkmark.circle.fill" : "circle",
                accessibilityDescription: nil)
            check.contentTintColor = isSelected ? .controlAccentColor : .tertiaryLabelColor
            state = isSelected ? .on : .off
        }
    }

    override var isEnabled: Bool {
        didSet { alphaValue = isEnabled ? 1 : 0.45 }
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        title = ""
        isBordered = false
        focusRingType = .exterior
        setAccessibilityRole(.checkBox)
        target = self
        action = #selector(toggle)

        check.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        check.translatesAutoresizingMaskIntoConstraints = false
        offline.setContentCompressionResistancePriority(.required, for: .horizontal)

        let text = Build.stack([name, detail], spacing: 1)
        addSubview(check)
        addSubview(avatar)
        addSubview(text)
        addSubview(offline)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 46),
            check.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            check.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatar.leadingAnchor.constraint(equalTo: check.trailingAnchor, constant: 10),
            avatar.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 9),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.trailingAnchor.constraint(lessThanOrEqualTo: offline.leadingAnchor, constant: -8),
            offline.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            offline.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        isSelected = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(bot: Bot, detail detailText: String, isOffline: Bool) {
        avatar.content = AvatarView.content(for: bot)
        name.stringValue = bot.name
        detail.stringValue = detailText
        offline.isHidden = !isOffline
        setAccessibilityLabel(bot.name + " · " + detailText + (isOffline ? " · " + L("offline") : ""))
    }

    override var allowsVibrancy: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    @objc private func toggle() { onToggle?() }

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func draw(_ dirtyRect: NSRect) {
        guard (isSelected || isHovered || isHighlighted), isEnabled else { return }
        (isSelected ? NSColor.systemPink : NSColor.labelColor).withAlphaComponent(isSelected ? 0.10 : 0.05).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 13, yRadius: 13).fill()
    }
}
