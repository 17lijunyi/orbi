import AppKit

final class LibraryNavigationView: NSView {
    var onLibrary: (() -> Void)?
    var onRecent: (() -> Void)?
    var onProviders: (() -> Void)?
    var onMarketplace: (() -> Void)?
    private var library: LibraryNavigationButton!

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let rows = Build.stack([], spacing: 4)
        let entries: [(String, String, () -> Void)] = [
            ("square.grid.2x2", L("All Teammates"), { [weak self] in self?.onLibrary?() }),
            ("clock", L("Recent Chats"), { [weak self] in self?.onRecent?() }),
            ("cpu", L("AI Providers"), { [weak self] in self?.onProviders?() }),
            ("sparkles", L("Marketplace"), { [weak self] in self?.onMarketplace?() }),
        ]
        for (index, entry) in entries.enumerated() {
            let button = LibraryNavigationButton(symbol: entry.0, title: entry.1)
            button.onPress = entry.2
            rows.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
            if index == 0 { library = button }
        }
        let heading = Build.label(L("Chats"), font: .systemFont(ofSize: 13, weight: .semibold))
        addSubview(rows)
        addSubview(heading)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: topAnchor),
            rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            rows.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            heading.topAnchor.constraint(equalTo: rows.bottomAnchor, constant: 22),
            heading.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            heading.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    func setLibrarySelected(_ selected: Bool) { library.selected = selected }
}

final class LibraryNavigationButton: NSButton {
    var onPress: (() -> Void)?
    var selected = false { didSet { needsDisplay = true } }
    private let symbol: String
    private let caption: String
    init(symbol: String, title: String) {
        self.symbol = symbol
        caption = title
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 40).isActive = true
        isBordered = false
        self.title = title
        setAccessibilityLabel(title)
        target = self
        action = #selector(pressed)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    @objc private func pressed() { onPress?() }
    override func draw(_ dirtyRect: NSRect) {
        if selected || isHighlighted {
            Theme.surfaceInk.withAlphaComponent(selected ? 0.20 : 0.10).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 0), xRadius: 11, yRadius: 11).fill()
        }
        Glyph.symbol(symbol, pointSize: 16, weight: .regular, color: Theme.surfaceInk.withAlphaComponent(0.8))?.draw(in: NSRect(x: 13, y: (bounds.height - 18) / 2, width: 18, height: 18))
        caption.draw(at: NSPoint(x: 45, y: (bounds.height - 16) / 2), withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: selected ? .medium : .regular), .foregroundColor: NSColor.labelColor])
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 10, yRadius: 10)
            ring.lineWidth = 2
            ring.stroke()
        }
    }
}

final class GlassSelectionRowView: NSTableRowView {
    override var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }
    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        Theme.surfaceInk.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 2), xRadius: 10, yRadius: 10).fill()
    }
}
