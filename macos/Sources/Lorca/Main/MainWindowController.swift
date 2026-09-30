import AppKit

final class MainWindowController: NSWindowController, NSWindowDelegate {
    let root = RootSplitViewController()
    private lazy var workspace = GlassWorkspaceViewController(root: root)
    private var devicePicker: NSPopUpButton { workspace.devicePicker }
    private var tasksButton: SpatialButton { workspace.tasksButton }
    private var palette: CommandPalette?
    private var tasksPopover: NSPopover?
    private var tasksClosedAt = Date.distantPast

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1340, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: true)
        window.title = AppInfo.name
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = NSSize(width: 1040, height: 650)
        window.tabbingMode = .disallowed
        window.animationBehavior = .none
        window.setFrameAutosaveName("LorcaGlassWorkspace")
        window.center()
        for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(type)?.isHidden = true
        }
        super.init(window: window)
        window.delegate = self
        if let contentView = window.contentView { workspace.view.frame = contentView.frame }
        window.contentViewController = workspace
        devicePicker.target = self
        devicePicker.action = #selector(pickDevice)
        workspace.onSearch = { [weak self] in self?.toggleCommandPalette() }
        workspace.onTasks = { [weak self] in self?.toggleRunningTasks(nil) }
        root.onContentChange = { [weak self] in self?.workspace.refresh() }
        root.onSelectionChange = { [weak self] in
            self?.updateTitle()
            self?.updateToolbar()
            Notifier.shared.watchingChanged()
        }
        AppStore.shared.observe(self) { [weak self] event in
            switch event {
            case .rosterChanged, .snapshotReplaced, .connectionChanged: self?.updateToolbar()
            case .messageAdded, .messageChanged, .messageRemoved, .chatsChanged, .runningTasksChanged: self?.updateRunningTasks()
            default: break
            }
        }
        updateTitle()
        updateToolbar()
        StartupTrace.mark("glass workspace configured")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func languageChanged() {
        palette?.close()
        palette = nil
        tasksPopover?.close()
        root.languageChanged()
        workspace.languageChanged()
        updateTitle()
        updateToolbar()
    }

    private func updateToolbar() {
        workspace.refresh()
        updateRunningTasks()
        var scoped = false
        if case let .settings(pane) = root.selection { scoped = pane.isDeviceScoped }
        devicePicker.isHidden = !scoped
        guard scoped else { return }
        devicePicker.removeAllItems()
        for device in AppStore.shared.devices {
            devicePicker.addItem(withTitle: device.isThisDevice ? L("%@ (This computer)", device.name) : device.name)
            devicePicker.lastItem?.representedObject = device.id
            devicePicker.lastItem?.image = NSImage(systemSymbolName: device.symbolName, accessibilityDescription: nil)
        }
        selectPickedDevice()
        devicePicker.menu?.addItem(.separator())
        let pair = NSMenuItem(title: L("Pair a Device…"), action: #selector(pairDevice), keyEquivalent: "")
        pair.target = self
        devicePicker.menu?.addItem(pair)
    }

    private func selectPickedDevice() {
        if let item = devicePicker.itemArray.first(where: { $0.representedObject as? String == root.settingsDeviceID }) {
            devicePicker.select(item)
        }
    }
    @objc private func pickDevice() {
        guard let id = devicePicker.selectedItem?.representedObject as? String else { return }
        root.showSettingsDevice(id)
    }
    @objc private func pairDevice() {
        selectPickedDevice()
        NSApp.sendAction(#selector(AppDelegate.pairDevice(_:)), to: nil, from: nil)
    }

    // MARK: - Running tasks

    /// The chat on screen, when a chat is.
    private var selectedChatID: Chat.ID? {
        if case let .chat(id) = root.selection { return id }
        return nil
    }

    /// Shows the Running tasks button with how many commands the chat on screen has running,
    /// and closes the popover when it belongs to a chat no longer on screen.
    private func updateRunningTasks() {
        let chatID = selectedChatID
        if let popover = tasksPopover, (popover.contentViewController as? RunningTasksViewController)?.chatID != chatID {
            popover.close()
        }
        let count = chatID.map { AppStore.shared.runningCommands(in: $0).count } ?? 0
        // While its popover is open the button stays, for the popover to point at.
        tasksButton.isHidden = count == 0 && tasksPopover == nil
        tasksButton.toolTip = count > 0 ? L("Running tasks (%d)", count) : L("Running tasks")
        tasksButton.setAccessibilityLabel(L("Running tasks (%d)", count))
    }

    @objc private func toggleRunningTasks(_ sender: Any?) {
        if let popover = tasksPopover {
            popover.close()
            return
        }
        // The click that closed the popover.
        guard Date().timeIntervalSince(tasksClosedAt) > 0.3, let chatID = selectedChatID else { return }
        let content = RunningTasksViewController(chatID: chatID)
        _ = content.view
        guard !content.tasks.isEmpty else { return }
        content.onShowCommand = { [weak self] title, command in
            guard let self else { return }
            tasksPopover?.close()
            root.presentAsSheet(CommandSheetViewController(title: title, command: command))
        }
        content.onEmpty = { [weak self] in self?.tasksPopover?.close() }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = content
        popover.delegate = self
        tasksPopover = popover
        popover.show(relativeTo: tasksButton.bounds, of: tasksButton, preferredEdge: .maxY)
    }

    func focusSearch() {
        root.focusSearch()
    }

    func toggleCommandPalette() {
        guard let window else { return }
        let palette = palette ?? CommandPalette(parent: window, root: root)
        self.palette = palette
        palette.toggle()
    }

    /// A window coming on screen starts with the keyboard in its content, whatever held it when
    /// the window closed and whichever key view AppKit would pick for a new one.
    override func showWindow(_ sender: Any?) {
        let isOpening = window?.isVisible != true
        super.showWindow(sender)
        StartupTrace.mark("window ordered front")
        if isOpening { root.focusContent() }
    }

    private func updateTitle() {
        guard let window else { return }
        switch root.selection {
        case let .chat(id):
            guard let chat = AppStore.shared.chat(id) else { return }
            window.title = AppStore.shared.title(for: chat)
            window.subtitle = AppStore.shared.subtitle(for: chat)
        case let .settings(pane):
            window.title = pane.title
            window.subtitle = ""
        case nil:
            window.title = AppInfo.name
            window.subtitle = ""
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        root.windowBecameKey()
        Notifier.shared.watchingChanged()
    }

    func windowDidMiniaturize(_ notification: Notification) {
        Notifier.shared.watchingChanged()
    }

    func windowWillClose(_ notification: Notification) {
        // The window still counts as visible here; report once it has gone.
        DispatchQueue.main.async { Notifier.shared.watchingChanged() }
    }
}

extension MainWindowController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        guard (notification.object as? NSPopover) === tasksPopover else { return }
        tasksPopover = nil
        tasksClosedAt = Date()
        updateRunningTasks()
    }
}
