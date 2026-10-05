import AppKit

private final class WorkbenchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class ToolChromeViewController: NSViewController {
    let content: NSViewController
    let heading = Build.label("", font: .systemFont(ofSize: 14, weight: .medium))
    let subtitle = Build.label("", font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
    let closeButton = SpatialButton("xmark", label: L("Close"), size: 11)
    let pinButton = SpatialButton("pin", label: L("Keep on Top"), size: 12)

    init(content: NSViewController) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let surface = SpatialGlassView(radius: 22)
        let title = Build.stack([heading, subtitle], spacing: 3)
        let actions = Build.stack([pinButton, closeButton], orientation: .horizontal, spacing: 2)
        let line = HairlineView()
        surface.addSubview(title)
        surface.addSubview(actions)
        surface.addSubview(line)
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(content.view)
        for button in [pinButton, closeButton] {
            button.widthAnchor.constraint(equalToConstant: 28).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 18),
            title.topAnchor.constraint(equalTo: surface.topAnchor, constant: 17),
            title.trailingAnchor.constraint(lessThanOrEqualTo: actions.leadingAnchor, constant: -10),
            actions.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -12),
            actions.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            line.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 16),
            line.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -16),
            line.topAnchor.constraint(equalTo: surface.topAnchor, constant: 64),
            content.view.topAnchor.constraint(equalTo: line.bottomAnchor),
            content.view.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            content.view.bottomAnchor.constraint(equalTo: surface.bottomAnchor),
        ])
        view = surface
    }
}

/// Independent windows stay usable when the main workspace is minimized.
final class ToolWindowController: NSWindowController, NSWindowDelegate {
    private let chrome: ToolChromeViewController
    private var positioned = false
    private(set) var isPinned = false
    var onWillClose: (() -> Void)?
    var onVisibilityChange: (() -> Void)?
    var onFocusChange: (() -> Void)?
    var isVisible: Bool { window?.isVisible == true }

    init(content: NSViewController, size: NSSize, minimum: NSSize, name: String, canPin: Bool = false) {
        chrome = ToolChromeViewController(content: content)
        let panel = WorkbenchPanel(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .closable, .resizable], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = false
        panel.minSize = minimum
        panel.tabbingMode = .disallowed
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.setFrameAutosaveName(name)
        super.init(window: panel)
        panel.delegate = self
        if let contentView = panel.contentView { chrome.view.frame = contentView.frame }
        panel.contentViewController = chrome
        chrome.pinButton.isHidden = !canPin
        chrome.closeButton.onPress = { [weak self] in self?.close() }
        chrome.pinButton.onPress = { [weak self] in self?.setPinned(!(self?.isPinned ?? false)) }
        if canPin { setPinned(true) }
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setHeading(_ title: String, subtitle: String) {
        chrome.heading.stringValue = title
        chrome.subtitle.stringValue = subtitle
        window?.title = title
        chrome.closeButton.toolTip = L("Close")
        chrome.closeButton.setAccessibilityLabel(L("Close"))
        refreshPinLabel()
    }

    func present(beside parent: NSWindow?, offset: NSPoint) {
        guard let window else { return }
        if !positioned {
            let screen = parent?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let anchor = parent?.frame ?? screen
            let proposed = NSPoint(x: anchor.minX + offset.x, y: anchor.maxY - window.frame.height - offset.y)
            let origin = NSPoint(
                x: min(max(screen.minX + 12, proposed.x), screen.maxX - window.frame.width - 12),
                y: min(max(screen.minY + 12, proposed.y), screen.maxY - window.frame.height - 12))
            window.setFrameOrigin(origin)
            positioned = true
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        onVisibilityChange?()
        onFocusChange?()
    }

    private func setPinned(_ pinned: Bool) {
        isPinned = pinned
        window?.level = pinned ? .floating : .normal
        chrome.pinButton.selected = pinned
        chrome.pinButton.image = NSImage(systemSymbolName: pinned ? "pin.fill" : "pin", accessibilityDescription: nil)
        refreshPinLabel()
    }

    private func refreshPinLabel() {
        let label = isPinned ? L("Unpin Window") : L("Keep on Top")
        chrome.pinButton.toolTip = label
        chrome.pinButton.setAccessibilityLabel(label)
    }

    func windowWillClose(_ notification: Notification) {
        onWillClose?()
        DispatchQueue.main.async { [weak self] in
            self?.onVisibilityChange?()
            self?.onFocusChange?()
        }
    }
    func windowDidBecomeKey(_ notification: Notification) { onFocusChange?() }
    func windowDidResignKey(_ notification: Notification) { onFocusChange?() }
}
