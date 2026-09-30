import AppKit

/// A real backdrop material: moving the window changes the desktop visible through it.
/// The system supplies an opaque material when Reduce Transparency is enabled.
final class SpatialGlassView: NSVisualEffectView {
    init(radius: CGFloat = 28) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.23).cgColor
        let tint = SpatialTintView()
        tint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tint)
        NSLayoutConstraint.activate([
            tint.leadingAnchor.constraint(equalTo: leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: trailingAnchor),
            tint.topAnchor.constraint(equalTo: topAnchor),
            tint.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

private final class SpatialTintView: NSView {
    override var allowsVibrancy: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.12, green: 0.11, blue: 0.095, alpha: 0.60).setFill()
        bounds.fill()
    }
}

final class SpatialSplitView: NSSplitView {
    override var dividerColor: NSColor { .white.withAlphaComponent(0.055) }
}

/// Icon controls on the detached rail and on the window's glass header.
final class SpatialButton: NSButton {
    var onPress: (() -> Void)?
    var selected = false { didSet { needsDisplay = true } }
    private var hovered = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    init(_ symbol: String, label: String, size: CGFloat = 19) {
        super.init(frame: .zero)
        image = Glyph.symbol(symbol, pointSize: size, weight: .regular, color: .white)
        imagePosition = .imageOnly
        title = ""
        toolTip = label
        setAccessibilityLabel(label)
        isBordered = false
        focusRingType = .exterior
        translatesAutoresizingMaskIntoConstraints = false
        target = self
        action = #selector(pressed)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func pressed() { onPress?() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let next = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(next)
        tracking = next
    }
    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }

    override func draw(_ dirtyRect: NSRect) {
        if selected || hovered || isHighlighted {
            NSColor.white.withAlphaComponent(selected ? 0.24 : 0.12).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 22, yRadius: 22).fill()
        }
        super.draw(dirtyRect)
    }
}

/// Clear space around the three floating surfaces remains transparent to the desktop.
final class SpatialStageView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

final class GlassWorkspaceViewController: NSViewController {
    let root: RootSplitViewController
    private let surface = SpatialGlassView()
    private let rail = SpatialGlassView(radius: 34)
    private let dock = NSView()
    private let titleLabel = Build.label("", font: .systemFont(ofSize: 25, weight: .bold))
    private let subtitleLabel = Build.label("", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
    private let sidebarTitle = Build.label("", font: .systemFont(ofSize: 25, weight: .bold))
    private let sidebarCaption = Build.label("", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
    private let actions = Build.stack([], orientation: .horizontal, spacing: 8)
    private var railButtons: [SpatialButton] = []
    private weak var mountedComposer: ComposerView?
    private var composerConstraints: [NSLayoutConstraint] = []
    private var dockHeight: NSLayoutConstraint!
    private var titleLeading: NSLayoutConstraint!
    private var sidebarWidth: CGFloat = 256
    private let backButton = SpatialButton("chevron.left", label: L("Back"), size: 15)
    private let forwardButton = SpatialButton("chevron.right", label: L("Forward"), size: 15)
    private let moreButton = SpatialButton("ellipsis", label: L("More"), size: 17)
    private let newButton = SpatialButton("plus", label: L("Create New Bot…"), size: 18)
    private let sidebarButton = SpatialButton("sidebar.leading", label: L("Toggle Sidebar (⌘B)"), size: 17)

    var onSearch: (() -> Void)?
    var onTasks: (() -> Void)?
    let tasksButton = SpatialButton("terminal", label: L("Running tasks"), size: 16)
    let inspectorButton = SpatialButton("sidebar.trailing", label: L("Inspector"), size: 17)
    let devicePicker = NSPopUpButton()

    init(root: RootSplitViewController) {
        self.root = root
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let stage = SpatialStageView()
        stage.wantsLayer = true
        stage.layer?.backgroundColor = NSColor.clear.cgColor
        stage.addSubview(surface)
        stage.addSubview(rail)
        dock.translatesAutoresizingMaskIntoConstraints = false
        stage.addSubview(dock)

        addChild(root)
        root.view.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(root.view)
        let heading = Build.stack([titleLabel, subtitleLabel], spacing: 4)
        let brand = Build.stack([sidebarTitle, sidebarCaption], spacing: 4)
        surface.addSubview(heading)
        surface.addSubview(brand)
        surface.addSubview(actions)
        surface.addSubview(moreButton)
        titleLeading = heading.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 286)
        dockHeight = dock.heightAnchor.constraint(greaterThanOrEqualToConstant: 78)

        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: stage.leadingAnchor, constant: 102),
            surface.trailingAnchor.constraint(equalTo: stage.trailingAnchor, constant: -22),
            surface.topAnchor.constraint(equalTo: stage.topAnchor, constant: 28),
            surface.bottomAnchor.constraint(equalTo: stage.bottomAnchor, constant: -74),
            rail.leadingAnchor.constraint(equalTo: stage.leadingAnchor, constant: 14),
            rail.centerYAnchor.constraint(equalTo: surface.centerYAnchor),
            rail.widthAnchor.constraint(equalToConstant: 64),
            rail.heightAnchor.constraint(equalToConstant: 352),
            brand.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 24),
            brand.topAnchor.constraint(equalTo: surface.topAnchor, constant: 27),
            brand.widthAnchor.constraint(equalToConstant: 198),
            moreButton.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 210),
            moreButton.topAnchor.constraint(equalTo: surface.topAnchor, constant: 26),
            moreButton.widthAnchor.constraint(equalToConstant: 32),
            moreButton.heightAnchor.constraint(equalToConstant: 32),
            heading.topAnchor.constraint(equalTo: brand.topAnchor),
            titleLeading,
            heading.trailingAnchor.constraint(lessThanOrEqualTo: actions.leadingAnchor, constant: -12),
            actions.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -26),
            actions.centerYAnchor.constraint(equalTo: heading.centerYAnchor),
            root.view.topAnchor.constraint(equalTo: surface.topAnchor, constant: 94),
            root.view.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 10),
            root.view.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -10),
            root.view.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -20),
            dock.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
            dock.widthAnchor.constraint(equalTo: surface.widthAnchor, multiplier: 0.64),
            dock.bottomAnchor.constraint(equalTo: stage.bottomAnchor, constant: -22),
            dockHeight,
        ])

        let entries: [(String, String, () -> Void)] = [
            ("square.grid.2x2", L("All Teammates"), { [weak root] in root?.select(nil) }),
            ("bubble.left.and.bubble.right", L("Chats"), { [weak root] in root?.openRecentChat() }),
            ("sparkles.rectangle.stack", L("Marketplace"), { [weak root] in root?.presentMarketplace() }),
            ("desktopcomputer", L("Devices"), { [weak root] in root?.showSettings(.device) }),
            ("gearshape", L("Settings"), { [weak root] in root?.showSettings() }),
            ("magnifyingglass", L("Search"), { [weak self] in self?.onSearch?() }),
        ]
        railButtons = entries.map { symbol, label, action in
            let button = SpatialButton(symbol, label: label)
            button.onPress = action
            NSLayoutConstraint.activate([button.widthAnchor.constraint(equalToConstant: 46), button.heightAnchor.constraint(equalToConstant: 46)])
            return button
        }
        let buttons = Build.stack(railButtons, spacing: 9)
        buttons.alignment = .centerX
        rail.addSubview(buttons)
        NSLayoutConstraint.activate([buttons.centerXAnchor.constraint(equalTo: rail.centerXAnchor), buttons.centerYAnchor.constraint(equalTo: rail.centerYAnchor)])

        tasksButton.onPress = { [weak self] in self?.onTasks?() }
        moreButton.onPress = { [weak self] in self?.showWindowMenu() }
        backButton.onPress = { [weak root] in root?.goBack() }
        forwardButton.onPress = { [weak root] in root?.goForward() }
        inspectorButton.onPress = { [weak root] in root?.toggleInspector(nil) }
        devicePicker.isBordered = false
        devicePicker.font = .systemFont(ofSize: 12)
        devicePicker.translatesAutoresizingMaskIntoConstraints = false
        devicePicker.widthAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true
        newButton.onPress = { [weak root] in root?.presentNewBot() }
        sidebarButton.onPress = { [weak root] in root?.toggleSidebar(nil) }
        for button in [backButton, forwardButton, sidebarButton, tasksButton, newButton, inspectorButton] {
            NSLayoutConstraint.activate([button.widthAnchor.constraint(equalToConstant: 34), button.heightAnchor.constraint(equalToConstant: 34)])
        }
        actions.addArrangedSubview(backButton)
        actions.addArrangedSubview(forwardButton)
        actions.addArrangedSubview(devicePicker)
        [sidebarButton, tasksButton, newButton, inspectorButton].forEach { actions.addArrangedSubview($0) }
        view = stage
        NotificationCenter.default.addObserver(self, selector: #selector(splitChanged), name: NSSplitView.didResizeSubviewsNotification, object: root.splitView)
    }

    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func splitChanged() {
        guard isViewLoaded, let item = root.splitViewItems.first else { return }
        sidebarWidth = item.isCollapsed ? 0 : item.viewController.view.frame.width
        titleLeading.constant = max(24, sidebarWidth + 34)
        sidebarTitle.isHidden = item.isCollapsed
        sidebarCaption.isHidden = item.isCollapsed
        moreButton.isHidden = item.isCollapsed
    }

    func refresh() {
        guard isViewLoaded else { return }
        let store = AppStore.shared
        sidebarTitle.stringValue = root.selection?.isSettings == true ? L("Settings") : L("Library")
        sidebarCaption.stringValue = root.selection?.isSettings == true ? L("Your workspace") : L("Your AI team")
        switch root.selection {
        case let .chat(id):
            if let chat = store.chat(id) {
                titleLabel.stringValue = store.title(for: chat)
                subtitleLabel.stringValue = store.subtitle(for: chat)
            }
        case let .settings(pane):
            titleLabel.stringValue = pane.title
            subtitleLabel.stringValue = L("Make yourself at home")
        case nil:
            titleLabel.stringValue = L("Teammates")
            subtitleLabel.stringValue = L("%d teammates", store.bots.count)
        }
        for button in railButtons { button.selected = false }
        if case .chat = root.selection { railButtons[1].selected = true }
        else if case .settings(.device) = root.selection { railButtons[3].selected = true }
        else if root.selection?.isSettings == true { railButtons[4].selected = true }
        else { railButtons[0].selected = true }
        inspectorButton.isHidden = root.selection == nil || root.selection?.isSettings == true
        backButton.isHidden = root.selection?.isSettings != true
        forwardButton.isHidden = root.selection?.isSettings != true
        backButton.isEnabled = root.canGoBack
        forwardButton.isEnabled = root.canGoForward
        newButton.isHidden = root.selection?.isSettings == true
        mount(root.floatingComposer)
        splitChanged()
    }

    func languageChanged() {
        let labels = [L("All Teammates"), L("Chats"), L("Marketplace"), L("Devices"), L("Settings"), L("Search")]
        for (button, label) in zip(railButtons, labels) {
            button.toolTip = label
            button.setAccessibilityLabel(label)
        }
        for (button, label) in [(backButton, L("Back")), (forwardButton, L("Forward")), (moreButton, L("More")), (inspectorButton, L("Inspector")), (newButton, L("Create New Bot…")), (sidebarButton, L("Toggle Sidebar (⌘B)"))] {
            button.toolTip = label
            button.setAccessibilityLabel(label)
        }
        refresh()
    }

    private func showWindowMenu() {
        let menu = NSMenu()
        for (title, selector) in [
            (L("Create New Bot…"), #selector(AppDelegate.newBot(_:))),
            (L("Create Group Chat…"), #selector(AppDelegate.newGroupChat(_:))),
            (L("Pair a Device…"), #selector(AppDelegate.pairDevice(_:))),
        ] { menu.addItem(withTitle: title, action: selector, keyEquivalent: "") }
        menu.addItem(.separator())
        for (title, selector) in [(L("Minimize"), #selector(NSWindow.performMiniaturize(_:))), (L("Zoom"), #selector(NSWindow.performZoom(_:))), (L("Close"), #selector(NSWindow.performClose(_:)))] {
            let item = menu.addItem(withTitle: title, action: selector, keyEquivalent: "")
            item.target = view.window
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: moreButton.bounds.maxY), in: moreButton)
    }

    private func mount(_ composer: ComposerView?) {
        guard mountedComposer !== composer else { return }
        NSLayoutConstraint.deactivate(composerConstraints)
        mountedComposer?.removeFromSuperview()
        mountedComposer = composer
        composerConstraints = []
        dock.isHidden = composer == nil
        guard let composer else { return }
        dock.addSubview(composer)
        composerConstraints = [
            composer.leadingAnchor.constraint(equalTo: dock.leadingAnchor),
            composer.trailingAnchor.constraint(equalTo: dock.trailingAnchor),
            composer.topAnchor.constraint(equalTo: dock.topAnchor),
            composer.bottomAnchor.constraint(equalTo: dock.bottomAnchor),
        ]
        NSLayoutConstraint.activate(composerConstraints)
    }
}
