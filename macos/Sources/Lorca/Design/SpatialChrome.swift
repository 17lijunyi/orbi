import AppKit

/// Rounded floating surfaces share the locally selected window background.
/// Their opaque fill keeps the chosen colors consistent over any desktop wallpaper.
final class SpatialGlassView: NSView {
    private var gradient: NSGradient?

    init(radius: CGFloat = 28) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        refreshBackground()
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshBackground), name: WindowBackground.didChange, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var allowsVibrancy: Bool { false }

    @objc private func refreshBackground() {
        gradient = NSGradient(colors: WindowBackground.current.colors, atLocations: [0, 0.52, 1], colorSpace: .sRGB)
        layer?.borderColor = (WindowBackground.current.isLight
            ? NSColor.black.withAlphaComponent(0.12)
            : NSColor.white.withAlphaComponent(0.23)).cgColor
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // CSS 135deg runs from upper left to lower right; AppKit's Y axis points up.
        gradient?.draw(in: bounds, angle: -45)
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

final class SpatialSplitView: NSSplitView {
    override var dividerColor: NSColor { Theme.surfaceRule }
}

/// Icon controls on the window's glass header.
final class SpatialButton: NSButton {
    var onPress: (() -> Void)?
    var selected = false { didSet { needsDisplay = true } }
    private var hovered = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    init(_ symbol: String, label: String, size: CGFloat = 19) {
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        symbolConfiguration = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        contentTintColor = .labelColor
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
            Theme.surfaceInk.withAlphaComponent(selected ? 0.20 : 0.10).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 22, yRadius: 22).fill()
        }
        super.draw(dirtyRect)
    }
}

/// Each capsule button has one action, with a visible caption and a native keyboard target.
final class CapsuleActionButton: NSButton {
    override var isFlipped: Bool { false }
    var onPress: (() -> Void)?
    var selected = false { didSet { needsDisplay = true; setAccessibilityValue(selected ? 1 : 0) } }
    private let symbol: String?
    private var caption: String
    private var hovered = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    init(symbol: String?, caption: String, label: String) {
        self.symbol = symbol
        self.caption = caption
        super.init(frame: .zero)
        isBordered = false
        title = ""
        focusRingType = .exterior
        translatesAutoresizingMaskIntoConstraints = false
        target = self
        action = #selector(pressed)
        relabel(caption: caption, label: label)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 52),
            heightAnchor.constraint(equalToConstant: symbol == nil ? 68 : 58),
        ])
        if symbol == nil {
            NotificationCenter.default.addObserver(self, selector: #selector(iconChanged), name: AppIcon.didChange, object: nil)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func relabel(caption: String, label: String) {
        self.caption = caption
        toolTip = label
        setAccessibilityLabel(label)
        needsDisplay = true
    }

    @objc private func pressed() { onPress?() }
    @objc private func iconChanged() { needsDisplay = true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }

    override func draw(_ dirtyRect: NSRect) {
        let ink = selected ? NSColor.systemPink : Theme.surfaceInk.withAlphaComponent(0.78)
        if selected || hovered || isHighlighted {
            (selected ? NSColor.systemPink : Theme.surfaceInk).withAlphaComponent(selected ? 0.08 : 0.05).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 16, yRadius: 16).fill()
        }
        let opacity: CGFloat = isEnabled ? 1 : 0.35
        if let symbol {
            Glyph.symbol(symbol, pointSize: 20, weight: .light, color: ink.withAlphaComponent(opacity))?
                .draw(in: NSRect(x: (bounds.width - 22) / 2, y: 27, width: 22, height: 22))
        } else {
            AppIcon.make(size: 38).draw(in: NSRect(x: (bounds.width - 38) / 2, y: 24, width: 38, height: 38), from: .zero, operation: .sourceOver, fraction: opacity)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        (caption as NSString).draw(in: NSRect(x: 1, y: 7, width: bounds.width - 2, height: 15), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: ink.withAlphaComponent(opacity), .paragraphStyle: paragraph,
        ])
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
    private let notesButton = CapsuleActionButton(symbol: "note.text", caption: L("Notes", context: "capsule"), label: L("Quick Notes"))
    private let todosButton = CapsuleActionButton(symbol: "checklist", caption: L("To-dos"), label: L("To-dos"))
    private let floatingButton = CapsuleActionButton(symbol: "pip", caption: L("Float", context: "capsule"), label: L("Floating Chat"))
    private let createButton = CapsuleActionButton(symbol: nil, caption: L("Create", context: "capsule"), label: L("Create New Bot…"))
    private let windowControls = NSView()
    private weak var mountedComposer: ComposerView?
    private var composerConstraints: [NSLayoutConstraint] = []
    private var dockHeight: NSLayoutConstraint!
    private var titleLeading: NSLayoutConstraint!
    private var sidebarWidth: CGFloat = 256
    private let backButton = SpatialButton("chevron.left", label: L("Back"), size: 15)
    private let forwardButton = SpatialButton("chevron.right", label: L("Forward"), size: 15)
    private let sidebarButton = SpatialButton("sidebar.leading", label: L("Toggle Sidebar (⌘B)"), size: 17)

    var onTasks: (() -> Void)?
    var onNotes: (() -> Void)?
    var onTodos: (() -> Void)?
    var onFloatingChat: (() -> Void)?
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
        windowControls.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(windowControls)
        let workspaceName = Build.label(AppInfo.name, font: .systemFont(ofSize: 12, weight: .semibold), color: .secondaryLabelColor)
        surface.addSubview(workspaceName)
        titleLeading = heading.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 286)
        dockHeight = dock.heightAnchor.constraint(greaterThanOrEqualToConstant: 78)

        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: stage.leadingAnchor, constant: 102),
            surface.trailingAnchor.constraint(equalTo: stage.trailingAnchor, constant: -22),
            surface.topAnchor.constraint(equalTo: stage.topAnchor, constant: 28),
            surface.bottomAnchor.constraint(equalTo: stage.bottomAnchor, constant: -74),
            rail.leadingAnchor.constraint(equalTo: stage.leadingAnchor, constant: 14),
            rail.centerYAnchor.constraint(equalTo: surface.centerYAnchor),
            rail.widthAnchor.constraint(equalToConstant: 66),
            rail.heightAnchor.constraint(equalToConstant: 306),
            windowControls.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 24),
            windowControls.topAnchor.constraint(equalTo: surface.topAnchor, constant: 16),
            windowControls.widthAnchor.constraint(equalToConstant: 60),
            windowControls.heightAnchor.constraint(equalToConstant: 14),
            workspaceName.leadingAnchor.constraint(equalTo: windowControls.trailingAnchor, constant: 16),
            workspaceName.centerYAnchor.constraint(equalTo: windowControls.centerYAnchor),
            brand.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 24),
            brand.topAnchor.constraint(equalTo: surface.topAnchor, constant: 52),
            brand.widthAnchor.constraint(equalToConstant: 232),
            heading.topAnchor.constraint(equalTo: brand.topAnchor),
            titleLeading,
            heading.trailingAnchor.constraint(lessThanOrEqualTo: actions.leadingAnchor, constant: -12),
            actions.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -26),
            actions.centerYAnchor.constraint(equalTo: heading.centerYAnchor),
            root.view.topAnchor.constraint(equalTo: surface.topAnchor, constant: 120),
            root.view.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 10),
            root.view.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -10),
            root.view.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -20),
            dock.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
            dock.widthAnchor.constraint(equalTo: surface.widthAnchor, multiplier: 0.64),
            dock.bottomAnchor.constraint(equalTo: stage.bottomAnchor, constant: -22),
            dockHeight,
        ])

        notesButton.onPress = { [weak self] in self?.onNotes?() }
        todosButton.onPress = { [weak self] in self?.onTodos?() }
        floatingButton.onPress = { [weak self] in self?.onFloatingChat?() }
        createButton.onPress = { [weak root] in root?.presentNewBot() }
        let divider = HairlineView()
        divider.widthAnchor.constraint(equalToConstant: 32).isActive = true
        let buttons = Build.stack([notesButton, todosButton, floatingButton, divider, createButton], spacing: 9)
        buttons.alignment = .centerX
        rail.addSubview(buttons)
        NSLayoutConstraint.activate([buttons.centerXAnchor.constraint(equalTo: rail.centerXAnchor), buttons.centerYAnchor.constraint(equalTo: rail.centerYAnchor)])

        tasksButton.onPress = { [weak self] in self?.onTasks?() }
        backButton.onPress = { [weak root] in root?.goBack() }
        forwardButton.onPress = { [weak root] in root?.goForward() }
        inspectorButton.onPress = { [weak root] in root?.toggleInspector(nil) }
        devicePicker.isBordered = false
        devicePicker.font = .systemFont(ofSize: 12)
        devicePicker.translatesAutoresizingMaskIntoConstraints = false
        devicePicker.widthAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true
        sidebarButton.onPress = { [weak root] in root?.toggleSidebar(nil) }
        for button in [backButton, forwardButton, sidebarButton, tasksButton, inspectorButton] {
            NSLayoutConstraint.activate([button.widthAnchor.constraint(equalToConstant: 34), button.heightAnchor.constraint(equalToConstant: 34)])
        }
        actions.addArrangedSubview(backButton)
        actions.addArrangedSubview(forwardButton)
        actions.addArrangedSubview(devicePicker)
        [sidebarButton, tasksButton, inspectorButton].forEach { actions.addArrangedSubview($0) }
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
    }

    /// AppKit creates native controls for this surface; their actions operate on the window.
    func installWindowControls(in window: NSWindow) {
        guard windowControls.subviews.isEmpty else { return }
        let controls: [(NSWindow.ButtonType, String, Selector)] = [
            (.closeButton, L("Close"), #selector(NSWindow.performClose(_:))),
            (.miniaturizeButton, L("Minimize"), #selector(NSWindow.performMiniaturize(_:))),
            (.zoomButton, L("Zoom"), #selector(NSWindow.performZoom(_:))),
        ]
        for (index, entry) in controls.enumerated() {
            guard let button = NSWindow.standardWindowButton(entry.0, for: window.styleMask) else { continue }
            button.translatesAutoresizingMaskIntoConstraints = false
            button.isHidden = false
            button.target = window
            button.action = entry.2
            button.toolTip = entry.1
            button.setAccessibilityLabel(entry.1)
            windowControls.addSubview(button)
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: windowControls.leadingAnchor, constant: CGFloat(index) * 22),
                button.centerYAnchor.constraint(equalTo: windowControls.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 14),
                button.heightAnchor.constraint(equalToConstant: 14),
            ])
        }
    }

    func refresh() {
        guard isViewLoaded else { return }
        let store = AppStore.shared
        sidebarTitle.stringValue = root.isTeamDrawerOpen ? L("Build a team") : root.selection?.isSettings == true ? L("Settings") : L("Library")
        sidebarCaption.stringValue = root.isTeamDrawerOpen ? L("Pick up to six bots to talk with together.") : root.selection?.isSettings == true ? L("Your workspace") : L("Your AI team")
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
        notesButton.isEnabled = store.hasIdentity == true && (store.identityID != nil || store.isMock)
        todosButton.isEnabled = notesButton.isEnabled
        createButton.isEnabled = store.isConnected && store.hasIdentity == true
        floatingButton.isEnabled = store.hasIdentity == true && root.currentOrRecentChatID != nil
        inspectorButton.isHidden = root.selection == nil || root.selection?.isSettings == true
        backButton.isHidden = root.selection?.isSettings != true
        forwardButton.isHidden = root.selection?.isSettings != true
        backButton.isEnabled = root.canGoBack
        forwardButton.isEnabled = root.canGoForward
        mount(root.floatingComposer)
        splitChanged()
    }

    func languageChanged() {
        for (button, caption, label) in [
            (notesButton, L("Notes", context: "capsule"), L("Quick Notes")),
            (todosButton, L("To-dos"), L("To-dos")),
            (floatingButton, L("Float", context: "capsule"), L("Floating Chat")),
            (createButton, L("Create", context: "capsule"), L("Create New Bot…")),
        ] {
            button.relabel(caption: caption, label: label)
        }
        for (button, label) in [(backButton, L("Back")), (forwardButton, L("Forward")), (inspectorButton, L("Inspector")), (sidebarButton, L("Toggle Sidebar (⌘B)"))] {
            button.toolTip = label
            button.setAccessibilityLabel(label)
        }
        refresh()
    }

    func setToolVisibility(notes: Bool, todos: Bool, chat: Bool) {
        notesButton.selected = notes
        todosButton.selected = todos
        floatingButton.selected = chat
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
