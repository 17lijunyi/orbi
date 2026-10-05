import AppKit

final class MainWindowController: NSWindowController, NSWindowDelegate {
    let root = RootSplitViewController()
    private lazy var workspace = GlassWorkspaceViewController(root: root)
    private var devicePicker: NSPopUpButton { workspace.devicePicker }
    private var tasksButton: SpatialButton { workspace.tasksButton }
    private var palette: CommandPalette?
    private var tasksPopover: NSPopover?
    private var tasksClosedAt = Date.distantPast
    private let workbench = WorkbenchStore()
    private var notesContent: QuickNotesViewController?
    private var notesWindow: ToolWindowController?
    private var todosContent: TodoListViewController?
    private var todosWindow: ToolWindowController?
    private var floatingContent: FloatingChatViewController?
    private var floatingWindow: ToolWindowController?

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
        workspace.installWindowControls(in: window)
        devicePicker.target = self
        devicePicker.action = #selector(pickDevice)
        workspace.onTasks = { [weak self] in self?.toggleRunningTasks(nil) }
        workspace.onNotes = { [weak self] in self?.toggleNotes() }
        workspace.onTodos = { [weak self] in self?.toggleTodos() }
        workspace.onFloatingChat = { [weak self] in self?.toggleFloatingChat() }
        workbench.onChange = { [weak self] in self?.todosContent?.reload() }
        root.onContentChange = { [weak self] in self?.workspace.refresh() }
        root.onSelectionChange = { [weak self] in
            self?.updateTitle()
            self?.updateToolbar()
            Notifier.shared.watchingChanged()
        }
        AppStore.shared.observe(self) { [weak self] event in
            switch event {
            case .identityChanged, .snapshotReplaced:
                self?.syncWorkbenchIdentity()
                self?.updateToolbar()
                self?.refreshFloatingTitle()
            case .rosterChanged, .connectionChanged: self?.updateToolbar(); self?.refreshFloatingTitle()
            case .chatsChanged, .chatChanged: self?.updateRunningTasks(); self?.refreshFloatingTitle()
            case .messageAdded, .messageChanged, .messageRemoved, .runningTasksChanged: self?.updateRunningTasks()
            default: break
            }
        }
        syncWorkbenchIdentity()
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
        notesContent?.languageChanged()
        todosContent?.languageChanged()
        floatingContent?.languageChanged()
        notesWindow?.setHeading(L("Quick Notes"), subtitle: L("A thought, kept close"))
        todosWindow?.setHeading(L("To-dos"), subtitle: L("One thing at a time"))
        refreshFloatingTitle()
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
    // MARK: - Running tasks

    /// The chat on screen, when a chat is.
    private var selectedChatID: Chat.ID? {
        if case let .chat(id) = root.selection { return id }
        return nil
    }

    /// Notification watching follows the window the user is reading, including the mini chat.
    var visibleChatID: Chat.ID? {
        if floatingWindow?.isVisible == true, floatingWindow?.window?.isKeyWindow == true {
            return floatingContent?.chatID
        }
        if window?.isVisible == true, window?.isMiniaturized != true, let selectedChatID {
            return selectedChatID
        }
        return floatingWindow?.isVisible == true ? floatingContent?.chatID : nil
    }

    // MARK: - Floating workbench

    private func syncWorkbenchIdentity() {
        let store = AppStore.shared
        let identity = store.hasIdentity == true ? (store.identityID ?? (store.isMock ? "preview" : nil)) : nil
        guard identity != workbench.identityID else { return }
        // Flush to the old identity before switching the local document.
        notesContent?.flush()
        notesWindow?.close()
        todosWindow?.close()
        floatingWindow?.close()
        notesContent = nil
        notesWindow = nil
        todosContent = nil
        todosWindow = nil
        floatingContent = nil
        floatingWindow = nil
        workbench.useIdentity(identity)
        refreshToolVisibility()
    }

    private func configureTool(_ tool: ToolWindowController) {
        tool.onVisibilityChange = { [weak self] in self?.refreshToolVisibility() }
        tool.onFocusChange = { Notifier.shared.watchingChanged() }
    }

    private func refreshToolVisibility() {
        workspace.setToolVisibility(notes: notesWindow?.isVisible == true,
            todos: todosWindow?.isVisible == true, chat: floatingWindow?.isVisible == true)
        Notifier.shared.watchingChanged()
    }

    private func toggleNotes() {
        guard workbench.identityID != nil else { return }
        if notesWindow?.isVisible == true { notesWindow?.close(); return }
        if notesWindow == nil {
            let content = QuickNotesViewController(store: workbench)
            let tool = ToolWindowController(content: content, size: NSSize(width: 340, height: 360),
                minimum: NSSize(width: 310, height: 280), name: "OrbiQuickNotes", canPin: true)
            tool.setHeading(L("Quick Notes"), subtitle: L("A thought, kept close"))
            content.onShowTasks = { [weak self] in self?.showTodos() }
            tool.onWillClose = { [weak content] in content?.flush() }
            configureTool(tool)
            notesContent = content
            notesWindow = tool
        }
        notesWindow?.present(beside: window, offset: NSPoint(x: 100, y: 152))
        notesContent?.focus()
    }

    private func toggleTodos() {
        if todosWindow?.isVisible == true { todosWindow?.close(); return }
        showTodos()
    }

    private func showTodos() {
        guard workbench.identityID != nil else { return }
        if todosWindow == nil {
            let content = TodoListViewController(store: workbench)
            let tool = ToolWindowController(content: content, size: NSSize(width: 340, height: 400),
                minimum: NSSize(width: 310, height: 270), name: "OrbiTodos", canPin: true)
            tool.setHeading(L("To-dos"), subtitle: L("One thing at a time"))
            configureTool(tool)
            todosContent = content
            todosWindow = tool
        }
        todosWindow?.present(beside: window, offset: NSPoint(x: 460, y: 152))
        todosContent?.focus()
    }

    private func toggleFloatingChat() {
        guard workbench.identityID != nil else { return }
        if floatingWindow?.isVisible == true { floatingWindow?.close(); return }
        guard let chatID = root.currentOrRecentChatID else { return }
        if floatingWindow == nil {
            let content = FloatingChatViewController()
            let tool = ToolWindowController(content: content, size: NSSize(width: 440, height: 520),
                minimum: NSSize(width: 360, height: 380), name: "OrbiFloatingChat", canPin: true)
            content.onClose = { [weak tool] in tool?.close() }
            content.onChatChange = { [weak self] in self?.refreshFloatingTitle(); Notifier.shared.watchingChanged() }
            tool.onWillClose = { [weak content] in content?.suspend() }
            configureTool(tool)
            floatingContent = content
            floatingWindow = tool
        }
        floatingContent?.show(chatID)
        floatingWindow?.present(beside: window, offset: NSPoint(x: (window?.frame.width ?? 1040) - 468, y: 234))
        floatingContent?.focus()
    }

    private func refreshFloatingTitle() {
        guard let id = floatingContent?.chatID else { return }
        guard let chat = AppStore.shared.chat(id) else { floatingWindow?.close(); return }
        floatingWindow?.setHeading(AppStore.shared.title(for: chat), subtitle: L("Floating Chat"))
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
