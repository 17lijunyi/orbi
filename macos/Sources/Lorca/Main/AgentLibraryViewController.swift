import AppKit

/// The library is the account's real roster. A card opens that bot's existing direct chat.
final class AgentLibraryViewController: NSViewController, NSSearchFieldDelegate {
    private let store = AppStore.shared
    private let search = NSSearchField()
    private let scroll = NSScrollView()
    private let grid = FlippedView()
    private var cards: [AgentLibraryCard] = []
    private let empty = Build.label("", font: .systemFont(ofSize: 15), color: .secondaryLabelColor, lines: 0, alignment: .center)
    private let filter = SpatialButton("line.3.horizontal.decrease", label: L("Filter teammates"), size: 17)
    private var onlineOnly = false
    private var localOnly = false
    let composer = ComposerView()
    var onOpen: ((Chat.ID) -> Void)?
    var onNewBot: (() -> Void)?

    override func loadView() {
        let container = NSView()
        search.placeholderString = L("Search in Teammates")
        search.setAccessibilityLabel(L("Search in Teammates"))
        search.controlSize = .large
        search.font = .systemFont(ofSize: 13)
        search.focusRingType = .none
        search.delegate = self
        search.translatesAutoresizingMaskIntoConstraints = false
        filter.onPress = { [weak self] in self?.showFilters() }
        scroll.documentView = grid
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.contentView.postsBoundsChangedNotifications = true
        [search, filter, scroll].forEach { container.addSubview($0) }
        grid.addSubview(empty)
        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo: container.topAnchor, constant: 0),
            search.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            search.trailingAnchor.constraint(equalTo: filter.leadingAnchor, constant: -10),
            search.heightAnchor.constraint(equalToConstant: 38),
            filter.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -22),
            filter.centerYAnchor.constraint(equalTo: search.centerYAnchor),
            filter.widthAnchor.constraint(equalToConstant: 36),
            filter.heightAnchor.constraint(equalToConstant: 36),
            scroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 24),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            empty.centerXAnchor.constraint(equalTo: grid.centerXAnchor),
            empty.topAnchor.constraint(equalTo: grid.topAnchor, constant: 110),
            empty.widthAnchor.constraint(lessThanOrEqualToConstant: 350),
        ])
        composer.onSend = { [weak self] text, attachments, mentions in
            guard let self, let bot = self.store.bots.first else { self?.onNewBot?(); return }
            let chat = self.store.dm(with: bot.id)
            let destination = self.store.send(text, attachments: attachments, mentions: mentions, in: chat)
            self.onOpen?(destination)
        }
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

    override func viewDidLayout() { super.viewDidLayout(); layoutCards() }

    func controlTextDidChange(_ obj: Notification) { rebuild() }
    func focusSearch() { view.window?.makeFirstResponder(search) }

    private func rebuild() {
        guard isViewLoaded else { return }
        let query = search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let bots = store.bots.filter { bot in
            let device = store.device(bot.runnerID)
            return (query.isEmpty || bot.name.localizedCaseInsensitiveContains(query) || bot.description.localizedCaseInsensitiveContains(query))
                && (!onlineOnly || device?.status == .online)
                && (!localOnly || device?.isThisDevice == true)
        }
        cards.forEach { $0.removeFromSuperview() }
        cards = bots.map { bot in
            let card = AgentLibraryCard(bot: bot, avatar: AvatarView.content(for: bot, store: store), subtitle: store.device(bot.runnerID)?.name ?? bot.provider.rawValue)
            card.onOpen = { [weak self] in
                guard let self else { return }
                self.onOpen?(self.store.dm(with: bot.id))
            }
            card.onChangeLook = { [weak self] in
                self?.presentAsSheet(BotLookViewController(botID: bot.id))
            }
            grid.addSubview(card)
            return card
        }
        empty.stringValue = store.bots.isEmpty ? L("Your team starts here.\nCreate your first teammate with +.") : L("No teammates found")
        empty.isHidden = !bots.isEmpty
        if let first = store.bots.first {
            composer.configure(placeholder: L("Message %@…", first.name), bots: store.bots)
        } else {
            composer.configure(placeholder: L("Create a teammate to get started"), bots: [])
        }
        layoutCards()
    }

    private func layoutCards() {
        let width = max(1, scroll.contentSize.width)
        let columns = max(1, min(4, Int((width + 24) / 182)))
        let gap: CGFloat = 24
        let side = floor((width - CGFloat(columns - 1) * gap - 2) / CGFloat(columns))
        let rowHeight = side + 62
        let rows = Int(ceil(Double(cards.count) / Double(columns)))
        grid.setFrameSize(NSSize(width: width, height: max(scroll.contentSize.height, CGFloat(rows) * rowHeight)))
        for (index, card) in cards.enumerated() {
            card.frame = NSRect(x: CGFloat(index % columns) * (side + gap), y: CGFloat(index / columns) * rowHeight, width: side, height: side + 43)
        }
    }

    private func showFilters() {
        let menu = NSMenu()
        for (index, title) in [L("All Teammates"), L("Online"), L("This computer")].enumerated() {
            let item = NSMenuItem(title: title, action: #selector(pickFilter(_:)), keyEquivalent: "")
            item.tag = index
            item.target = self
            item.state = (index == 0 && !onlineOnly && !localOnly) || (index == 1 && onlineOnly) || (index == 2 && localOnly) ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: filter.bounds.maxY), in: filter)
    }
    @objc private func pickFilter(_ sender: NSMenuItem) {
        onlineOnly = sender.tag == 1
        localOnly = sender.tag == 2
        filter.selected = sender.tag != 0
        rebuild()
    }
}

/// A floating character opens its chat; the contextual menu opens the same look editor as its profile.
final class AgentLibraryCard: NSButton {
    private let bot: Bot
    private let avatar: AvatarView.Content
    private let detail: String
    private var hovered = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?
    var onOpen: (() -> Void)?
    var onChangeLook: (() -> Void)?
    override var isFlipped: Bool { true }

    init(bot: Bot, avatar: AvatarView.Content, subtitle: String) {
        self.bot = bot
        self.avatar = avatar
        detail = subtitle
        super.init(frame: .zero)
        isBordered = false
        title = ""
        target = self
        action = #selector(openChat)
        setAccessibilityLabel("\(bot.name), \(subtitle)")
        toolTip = bot.description
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    @objc private func openChat() { onOpen?() }
    @objc private func changeLook() { onChangeLook?() }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let open = NSMenuItem(title: L("Open chat"), action: #selector(openChat), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let look = NSMenuItem(title: L("Change look"), action: #selector(changeLook), keyEquivalent: "")
        look.target = self
        menu.addItem(look)
        return menu
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }
    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func draw(_ dirtyRect: NSRect) {
        let cover = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.width)
        let inset = cover.width * (isHighlighted ? 0.035 : hovered ? 0.005 : 0.02)
        AvatarView.render(avatar, in: cover.insetBy(dx: inset, dy: inset))
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        bot.name.draw(in: NSRect(x: 0, y: cover.maxY + 8, width: bounds.width, height: 18), withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
        detail.draw(in: NSRect(x: 0, y: cover.maxY + 25, width: bounds.width, height: 16), withAttributes: [.font: NSFont.systemFont(ofSize: 11.5), .foregroundColor: NSColor.labelColor.withAlphaComponent(0.68), .paragraphStyle: paragraph])
        if window?.firstResponder === self {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 12, yRadius: 12)
            NSColor.keyboardFocusIndicatorColor.setStroke()
            path.lineWidth = 3
            path.stroke()
        }
    }
}
