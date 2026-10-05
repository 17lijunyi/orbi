import AppKit

final class QuickNotesViewController: NSViewController, NSTextViewDelegate {
    private let store: WorkbenchStore
    private let editor = NSTextView()
    private let status = Build.label("", font: .systemFont(ofSize: 10.5), color: .secondaryLabelColor)
    private let saveButton = NSButton()
    private let taskButton = NSButton()
    var onShowTasks: (() -> Void)?

    init(store: WorkbenchStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = BackgroundView()
        let field = BackgroundView()
        field.fillColor = Theme.composerField
        field.cornerRadius = 14
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        editor.isRichText = false
        editor.drawsBackground = false
        editor.font = .systemFont(ofSize: 13)
        editor.textColor = .labelColor
        editor.insertionPointColor = .labelColor
        editor.textContainerInset = NSSize(width: 12, height: 12)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.string = store.note
        editor.delegate = self
        editor.setAccessibilityLabel(L("Quick Notes"))
        scroll.documentView = editor
        field.addSubview(scroll)
        for button in [taskButton, saveButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = .rounded
            button.font = .systemFont(ofSize: 11)
            button.target = self
        }
        saveButton.action = #selector(save)
        taskButton.action = #selector(makeTask)
        let buttons = Build.stack([taskButton, saveButton], orientation: .horizontal, spacing: 8)
        container.addSubview(field)
        container.addSubview(status)
        container.addSubview(buttons)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            field.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            field.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -12),
            scroll.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: 2),
            scroll.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -2),
            scroll.topAnchor.constraint(equalTo: field.topAnchor, constant: 2),
            scroll.bottomAnchor.constraint(equalTo: field.bottomAnchor, constant: -2),
            status.leadingAnchor.constraint(equalTo: field.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: field.trailingAnchor),
            buttons.trailingAnchor.constraint(equalTo: field.trailingAnchor),
            buttons.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 12),
            buttons.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
        view = container
        languageChanged()
    }

    func languageChanged() {
        guard isViewLoaded else { return }
        saveButton.title = L("Save Note")
        taskButton.title = L("Turn into Task")
        editor.setAccessibilityLabel(L("Quick Notes"))
        refreshStatus()
    }

    func focus() { view.window?.makeFirstResponder(editor) }
    func flush() { store.saveNote(editor.string) }

    func textDidChange(_ notification: Notification) {
        flush()
        refreshStatus()
    }

    private func refreshStatus() {
        let empty = editor.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        taskButton.isEnabled = !empty
        status.stringValue = empty ? L("Write a thought. It saves automatically on this Mac.") : L("Saved on this Mac")
    }

    @objc private func save() {
        flush()
        status.stringValue = L("Saved on this Mac")
    }

    @objc private func makeTask() {
        flush()
        guard store.addTask(editor.string) else { return }
        status.stringValue = L("Added to To-dos")
        onShowTasks?()
    }
}
