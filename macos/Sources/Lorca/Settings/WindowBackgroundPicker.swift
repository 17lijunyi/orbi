import AppKit

/// A compact gallery uses the actual background colors to preview the app's window.
/// Four columns also fit the standalone 560-point onboarding Settings window.
final class WindowBackgroundPicker: NSView {
    private var buttons: [WindowBackgroundButton] = []

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        identifier = NSUserInterfaceItemIdentifier("orbi.settings.window-background")
        setAccessibilityLabel(SettingsEntry.windowBackground.row)

        let label = Build.label(SettingsEntry.windowBackground.row, font: .systemFont(ofSize: 12.5))
        addSubview(label)
        let grid = NSStackView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 10
        grid.setHuggingPriority(.init(1), for: .horizontal)
        addSubview(grid)

        let choices = WindowBackground.allCases
        for start in stride(from: 0, to: choices.count, by: 4) {
            let row = NSStackView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.orientation = .horizontal
            row.distribution = .fillEqually
            row.spacing = 10
            row.setHuggingPriority(.init(1), for: .horizontal)
            grid.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true
            for offset in 0..<4 {
                let index = start + offset
                if choices.indices.contains(index) {
                    let button = WindowBackgroundButton(background: choices[index])
                    button.onChoose = { [weak self] in self?.choose(index) }
                    button.onMove = { [weak self] delta in self?.choose(index + delta, focus: true) }
                    buttons.append(button)
                    row.addArrangedSubview(button)
                } else {
                    let spacer = NSView()
                    spacer.translatesAutoresizingMaskIntoConstraints = false
                    row.addArrangedSubview(spacer)
                }
            }
        }

        let fillWidth = grid.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        fillWidth.priority = .defaultLow - 1
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            grid.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
            grid.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            grid.widthAnchor.constraint(lessThanOrEqualToConstant: 540),
            fillWidth,
            grid.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: WindowBackground.didChange, object: nil)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func choose(_ index: Int, focus: Bool = false) {
        guard buttons.indices.contains(index) else { return }
        WindowBackground.choose(buttons[index].background)
        refresh()
        if focus { window?.makeFirstResponder(buttons[index]) }
    }

    @objc private func refresh() {
        for button in buttons { button.isChosen = button.background == WindowBackground.current }
    }
}

private final class WindowBackgroundButton: NSButton {
    let background: WindowBackground
    var onChoose: (() -> Void)?
    var onMove: ((Int) -> Void)?
    var isChosen = false {
        didSet {
            state = isChosen ? .on : .off
            setAccessibilityValue(isChosen ? 1 : 0)
            needsDisplay = true
        }
    }

    init(background: WindowBackground) {
        self.background = background
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        title = background.title
        isBordered = false
        setContentHuggingPriority(.init(1), for: .horizontal)
        setButtonType(.momentaryChange)
        target = self
        action = #selector(choose)
        focusRingType = .exterior
        identifier = NSUserInterfaceItemIdentifier("orbi.settings.background.\(background.rawValue)")
        setAccessibilityLabel("\(background.title)窗口背景")
        setAccessibilityHelp("立即应用；使用方向键切换，空格选择。")
        toolTip = "\(background.title) · 立即应用"
        heightAnchor.constraint(equalToConstant: 78).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    @objc private func choose() { onChoose?() }
    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override var allowsVibrancy: Bool { false }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: onMove?(-1)
        case 124: onMove?(1)
        case 125: onMove?(4)
        case 126: onMove?(-4)
        default: super.keyDown(with: event)
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 9, yRadius: 9).fill()
    }

    override func draw(_ dirtyRect: NSRect) {
        let preview = NSRect(x: 4, y: 23, width: bounds.width - 8, height: 51)
        let path = NSBezierPath(roundedRect: preview, xRadius: 8, yRadius: 8)
        let colors = background.colors
        if colors.count == 3 {
            let gradient = NSGradient(colorsAndLocations: (colors[0], 0), (colors[1], 0.52), (colors[2], 1))
            gradient?.draw(in: path, angle: -45)
        }
        let ink: NSColor = background.isLight ? .black : .white
        ink.withAlphaComponent(0.16).setStroke()
        path.lineWidth = 0.7
        path.stroke()

        // A small sidebar and transcript make the swatch read as a window background.
        ink.withAlphaComponent(0.14).setFill()
        NSBezierPath(roundedRect: NSRect(x: preview.minX + 6, y: preview.minY + 6, width: preview.width * 0.23, height: preview.height - 20), xRadius: 3, yRadius: 3).fill()
        for index in 0..<3 {
            ink.withAlphaComponent(0.5).setFill()
            let dot = NSRect(x: preview.minX + 7 + CGFloat(index) * 5, y: preview.maxY - 9, width: 2.5, height: 2.5)
            NSBezierPath(ovalIn: dot).fill()
        }
        for index in 0..<3 {
            ink.withAlphaComponent(index == 0 ? 0.55 : 0.28).setFill()
            let line = NSRect(x: preview.minX + preview.width * 0.34, y: preview.maxY - 21 - CGFloat(index) * 8,
                              width: preview.width * (index == 2 ? 0.36 : 0.48), height: 2.5)
            NSBezierPath(roundedRect: line, xRadius: 1.2, yRadius: 1.2).fill()
        }
        if isChosen {
            NSColor.controlAccentColor.setStroke()
            let border = NSBezierPath(roundedRect: preview.insetBy(dx: -2, dy: -2), xRadius: 10, yRadius: 10)
            border.lineWidth = 2
            border.stroke()
        } else if isHighlighted {
            NSColor.labelColor.withAlphaComponent(0.6).setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11.5, weight: isChosen ? .semibold : .regular),
            .foregroundColor: NSColor.labelColor,
        ]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: 2), withAttributes: attributes)
    }
}
