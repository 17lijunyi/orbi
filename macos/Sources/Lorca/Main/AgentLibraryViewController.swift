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
        cards = bots.enumerated().map { index, bot in
            let card = AgentLibraryCard(bot: bot, index: index, avatar: store.avatarImage(for: bot), subtitle: store.device(bot.runnerID)?.name ?? bot.provider.rawValue)
            card.onOpen = { [weak self] in
                guard let self else { return }
                self.onOpen?(self.store.dm(with: bot.id))
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

/// Square artwork echoes an album sleeve while keeping the bot's own avatar and identity.
final class AgentLibraryCard: NSButton {
    private let bot: Bot
    private let index: Int
    private let avatar: NSImage?
    private let detail: String
    private var hovered = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?
    var onOpen: (() -> Void)?
    override var isFlipped: Bool { true }

    init(bot: Bot, index: Int, avatar: NSImage?, subtitle: String) {
        self.bot = bot
        self.index = index
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
        let path = NSBezierPath(roundedRect: cover, xRadius: 10, yRadius: 10)
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        if let avatar, avatar.size.width > 0, avatar.size.height > 0 {
            let scale = max(cover.width / avatar.size.width, cover.height / avatar.size.height)
            let size = NSSize(width: avatar.size.width * scale, height: avatar.size.height * scale)
            avatar.draw(in: NSRect(x: cover.midX - size.width / 2, y: cover.midY - size.height / 2, width: size.width, height: size.height), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        } else {
            let accent = bot.accent.color
            let deep = accent.blended(withFraction: 0.65, of: .black) ?? accent
            NSGradient(colors: [bot.accent.highlight, accent, deep])?.draw(in: cover, angle: CGFloat(45 + index * 35))
            let center = NSPoint(x: cover.width * 0.52, y: cover.height * 0.52)
            for ring in 0..<9 {
                let diameter = cover.width * (0.40 + CGFloat(ring) * 0.18)
                let ellipse = NSBezierPath(ovalIn: NSRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter))
                NSColor.white.withAlphaComponent(ring.isMultiple(of: 2) ? 0.13 : 0.06).setStroke()
                ellipse.lineWidth = CGFloat(ring.isMultiple(of: 3) ? 10 : 1)
                ellipse.stroke()
            }
            let iconSize = cover.width * 0.42
            Glyph.symbol(bot.symbolName, pointSize: iconSize, weight: .light, color: .white)?.draw(in: NSRect(x: cover.midX - iconSize / 2, y: cover.midY - iconSize / 2, width: iconSize, height: iconSize), from: .zero, operation: .sourceOver, fraction: 0.95, respectFlipped: true, hints: nil)
            ("O R B I   /   " + String(format: "%02d", index + 1)).draw(at: NSPoint(x: 14, y: 13), withAttributes: [.font: NSFont.systemFont(ofSize: 8, weight: .semibold), .foregroundColor: NSColor.white.withAlphaComponent(0.72)])
        }
        if hovered || isHighlighted {
            NSColor.white.withAlphaComponent(isHighlighted ? 0.17 : 0.08).setFill()
            cover.fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(hovered ? 0.55 : 0.12).setStroke()
        path.lineWidth = 1
        path.stroke()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        bot.name.draw(in: NSRect(x: 0, y: cover.maxY + 8, width: bounds.width, height: 18), withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
        detail.draw(in: NSRect(x: 0, y: cover.maxY + 25, width: bounds.width, height: 16), withAttributes: [.font: NSFont.systemFont(ofSize: 11.5), .foregroundColor: NSColor.white.withAlphaComponent(0.68), .paragraphStyle: paragraph])
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            path.lineWidth = 3
            path.stroke()
        }
    }
}
