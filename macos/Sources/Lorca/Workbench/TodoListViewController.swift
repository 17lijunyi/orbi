import AppKit

final class TodoListViewController: NSViewController {
    private let store: WorkbenchStore
    private let input = NSTextField()
    private let list = Build.stack([], spacing: 8)
    private let count = Build.label("", font: .systemFont(ofSize: 10.5), color: .secondaryLabelColor)
    private let clearButton = NSButton()
    private let addButton = SpatialButton("plus", label: L("Add To-do"), size: 14)

    init(store: WorkbenchStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = BackgroundView()
        input.translatesAutoresizingMaskIntoConstraints = false
        input.font = .systemFont(ofSize: 12)
        input.bezelStyle = .roundedBezel
        input.target = self
        input.action = #selector(addTask)
        addButton.onPress = { [weak self] in self?.addTask() }
        addButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        addButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let entry = Build.stack([input, addButton], orientation: .horizontal, spacing: 6)
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(list)
        list.alignment = .leading
        scroll.documentView = document
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.bezelStyle = .inline
        clearButton.font = .systemFont(ofSize: 10.5)
        clearButton.target = self
        clearButton.action = #selector(clearCompleted)
        container.addSubview(entry)
        container.addSubview(scroll)
        container.addSubview(count)
        container.addSubview(clearButton)
        NSLayoutConstraint.activate([
            entry.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            entry.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            entry.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: entry.bottomAnchor, constant: 14),
            scroll.leadingAnchor.constraint(equalTo: entry.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: entry.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: count.topAnchor, constant: -14),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            list.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            list.topAnchor.constraint(equalTo: document.topAnchor),
            list.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            count.leadingAnchor.constraint(equalTo: entry.leadingAnchor),
            count.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18),
            count.trailingAnchor.constraint(lessThanOrEqualTo: clearButton.leadingAnchor, constant: -6),
            clearButton.trailingAnchor.constraint(equalTo: entry.trailingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: count.centerYAnchor),
        ])
        view = container
        languageChanged()
    }

    func languageChanged() {
        guard isViewLoaded else { return }
        input.placeholderString = L("Add a task, then press Return")
        input.setAccessibilityLabel(L("Add To-do"))
        addButton.toolTip = L("Add To-do")
        addButton.setAccessibilityLabel(L("Add To-do"))
        clearButton.title = L("Clear Completed")
        reload()
    }

    func focus() { view.window?.makeFirstResponder(input) }

    func reload() {
        guard isViewLoaded else { return }
        for row in list.arrangedSubviews { list.removeArrangedSubview(row); row.removeFromSuperview() }
        if store.tasks.isEmpty {
            let empty = Build.label(L("A little space for what comes next."), font: .systemFont(ofSize: 12), color: .secondaryLabelColor, lines: 2)
            list.addArrangedSubview(empty)
            empty.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }
        for task in store.tasks {
            let check = SpatialButton(task.isCompleted ? "checkmark.circle.fill" : "circle", label: task.isCompleted ? L("Mark Incomplete") : L("Mark Complete"), size: 17)
            check.contentTintColor = task.isCompleted ? .systemPink : .secondaryLabelColor
            check.onPress = { [weak self] in self?.store.toggleTask(task.id) }
            let label = Build.label(task.title, font: .systemFont(ofSize: 12), color: task.isCompleted ? .secondaryLabelColor : .labelColor, lines: 0)
            if task.isCompleted {
                label.attributedStringValue = NSAttributedString(string: task.title, attributes: [
                    .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                ])
            }
            let remove = SpatialButton("xmark", label: L("Delete To-do"), size: 10)
            remove.onPress = { [weak self] in self?.store.removeTask(task.id) }
            for button in [check, remove] {
                button.widthAnchor.constraint(equalToConstant: 28).isActive = true
                button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            }
            let row = Build.stack([check, label, remove], orientation: .horizontal, spacing: 6)
            list.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }
        count.stringValue = L("%d remaining", store.tasks.filter { !$0.isCompleted }.count)
        clearButton.isEnabled = store.tasks.contains(where: \.isCompleted)
    }

    @objc private func addTask() {
        guard store.addTask(input.stringValue) else { return }
        input.stringValue = ""
        focus()
    }
    @objc private func clearCompleted() { store.clearCompleted() }
}
