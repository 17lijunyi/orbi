import AppKit

// Compile the production controllers unchanged against a controllable async store.
struct Bot { typealias ID = String; var id: ID; var name: String }
struct Device {
    typealias ID = String
    var id: ID
    var name: String
    var isThisDevice = true
    var plugins: [InstalledPlugin] = []
}
struct InstalledPlugin {
    var id = "plugin", name = "Plugin", description = "", detail = "Ready"
    var stateColor: NSColor { .systemGreen }
}
struct PluginDetail {
    struct Variable: Hashable {
        var name: String, description: String
        var secret: Bool, required: Bool, isSet: Bool
        var value: String?
    }
    struct Server {
        var name: String, oauth: Bool, signedIn: Bool
        var code: String?, link: String?
    }
    var status = InstalledPlugin()
    var homepage: String?
    var variables: [Variable]
    var servers: [Server] = []
    var skills: [(name: String, description: String)] = []
}
struct BotMemory {
    var text: String
    var hash = "original", maxLines = 200, maxBytes = 24_000
}
struct AutoReview { struct Rule { var tool: String? }; var rules: [Rule] = [] }
enum StoreEvent { case rosterChanged, snapshotReplaced, other }
@MainActor final class AppStore {
    static let shared = AppStore()
    var autoReview = AutoReview()
    var observers: [(StoreEvent) -> Void] = []
    var details: [CheckedContinuation<PluginDetail, Error>] = []
    var variableWrites: [(values: [String: String], answer: CheckedContinuation<InstalledPlugin, Error>)] = []
    var memoryWrites: [(text: String, hash: String?, answer: CheckedContinuation<String, Error>)] = []
    func observe(_ owner: AnyObject, _ handler: @escaping (StoreEvent) -> Void) { observers.append(handler) }
    func emit(_ event: StoreEvent) { observers.forEach { $0(event) } }
    func setAutoReview(_ review: AutoReview) { autoReview = review }
    func pluginDetail(_ id: String, on runner: String) async throws -> PluginDetail {
        try await withCheckedThrowingContinuation { details.append($0) }
    }
    func setPluginVariables(_ id: String, on runner: String, variables: [String: String]) async throws -> InstalledPlugin {
        try await withCheckedThrowingContinuation { variableWrites.append((variables, $0)) }
    }
    func connectPlugin(_ id: String, on runner: String) async throws {}
    func uninstallPlugin(_ id: String, on runner: String) async throws {}
    func writeBotMemory(_ id: String, text: String, expectedHash: String?) async throws -> String {
        try await withCheckedThrowingContinuation { memoryWrites.append((text, expectedHash, $0)) }
    }
    func botMemory(_ id: String) async throws -> BotMemory { .init(text: "fresh") }
}
func L(_ value: String, _ arguments: CVarArg...) -> String { String(format: value, arguments: arguments) }
func L(_ value: String, context: String) -> String { value }
enum Theme { enum Font { static var caption: NSFont { .systemFont(ofSize: 11) } } }
enum Format { static func kilobytes(_ value: Int) -> String { "\(value) bytes" } }
enum Build {
    @MainActor static func label(_ title: String, font: NSFont, color: NSColor = .labelColor, lines: Int = 1) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = font; label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    @MainActor static func stack(_ views: [NSView], orientation: NSUserInterfaceLayoutOrientation = .vertical, spacing: CGFloat = 0) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = orientation; stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }
}
final class SectionView: NSView {
    init(title: String) { super.init(frame: .zero); translatesAutoresizingMaskIntoConstraints = false }
    required init?(coder: NSCoder) { fatalError() }
    func setRows(_ rows: [NSView]) { subviews.forEach { $0.removeFromSuperview() }; rows.forEach(addSubview) }
}
final class KeyValueRow: NSView {
    init(key: String, value: String, tint: NSColor = .labelColor) { super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }
}
final class ActionRow: NSView {
    var onAction: (() -> Void)?
    init(key: String, value: String, tint: NSColor, actionTitle: String, monospaced: Bool = false) { super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }
    func showCopied() {}
}
@MainActor class SheetViewController: NSViewController {
    let contentStack = Build.stack([])
    var confirmButton = NSButton(), cancelButton: NSButton? = NSButton()
    var didDismiss = false
    init(title: String, subtitle: String, width: CGFloat) { super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func loadView() { view = NSView(); view.addSubview(contentStack) }
    func setButtons(confirm: String, cancel: String? = "Cancel") { confirmButton.title = confirm }
    func fitSheetToContent() {}
    override func dismiss(_ sender: Any?) { didDismiss = true }
    @objc func dismissSheet() { dismiss(nil) }
    @objc func confirmTapped() { dismiss(nil) }
}

@main struct SheetDraftTests {
    @MainActor static func main() async {
        _ = NSApplication.shared
        let store = AppStore.shared
        let plugin = PluginViewController(pluginID: "plugin", runner: Device(id: "runner", name: "Runner"), bot: nil)
        _ = plugin.view
        await wait { store.details.count == 1 }
        store.details[0].resume(returning: detail("initial", "remote-a"))
        await wait { descendants(plugin.view).contains { $0 is NSSecureTextField } }
        let inputs = descendants(plugin.view).compactMap { $0 as? NSTextField }.filter(\.isEditable)
        let secret = inputs.first { $0 is NSSecureTextField }!
        let edited = inputs.first { $0.stringValue == "initial" }!
        let untouched = inputs.first { $0.stringValue == "remote-a" }!
        secret.stringValue = "draft-secret"
        edited.stringValue = "draft-value"
        store.emit(.rosterChanged)
        await wait { store.details.count == 2 }
        store.details[1].resume(returning: detail("changed-remotely", "remote-b"))
        await wait { untouched.stringValue == "remote-b" }
        precondition(secret.stringValue == "draft-secret" && edited.stringValue == "draft-value")
        precondition(descendants(plugin.view).contains { $0 === edited })
        print("PASS: plugin refresh preserves unsaved secret/text and field identity; clean values refresh")

        let save = descendants(plugin.view).compactMap { $0 as? NSButton }.first { $0.title == "Save" }!
        save.performClick(nil)
        await wait { store.variableWrites.count == 1 }
        plugin.confirmTapped(); plugin.dismissSheet()
        precondition(!plugin.didDismiss && !save.isEnabled && !edited.isEnabled)
        precondition(store.variableWrites[0].values["TOKEN"] == "draft-secret")
        precondition(store.variableWrites[0].values["EDITED"] == "draft-value")
        store.variableWrites[0].answer.resume(returning: InstalledPlugin())
        await wait { store.details.count == 3 }
        store.details[2].resume(returning: detail("draft-value", "remote-b", secretSet: true))
        await wait { secret.placeholderString == "Set · type to replace" }
        precondition(secret.stringValue.isEmpty && save.isEnabled && edited.isEnabled)
        print("PASS: plugin save locks submission and clears secret drafts only after acknowledgement")

        secret.stringValue = "retry-secret"
        edited.stringValue = "retry-value"
        save.performClick(nil)
        await wait { store.variableWrites.count == 2 }
        store.variableWrites[1].answer.resume(throwing: NSError(domain: "test", code: 1))
        await wait { save.isEnabled }
        precondition(secret.stringValue == "retry-secret" && edited.stringValue == "retry-value")
        save.performClick(nil)
        await wait { store.variableWrites.count == 3 }
        plugin.viewDidDisappear()
        store.variableWrites[2].answer.resume(returning: InstalledPlugin())
        store.emit(.rosterChanged)
        for _ in 0..<20 { await Task.yield() }
        precondition(secret.stringValue == "retry-secret" && store.details.count == 3)
        print("PASS: failed plugin save keeps drafts; dismissed plugin ignores late save and roster callbacks")

        let memory = MemoryViewController(bot: Bot(id: "bot", name: "Bot"), memory: BotMemory(text: "original"))
        _ = memory.view
        let editor = descendants(memory.view).compactMap { $0 as? NSTextView }.first!
        editor.string = "draft memory"
        memory.confirmTapped(); memory.confirmTapped(); memory.dismissSheet()
        await wait { store.memoryWrites.count == 1 }
        precondition(!memory.didDismiss && !editor.isEditable && memory.cancelButton?.isEnabled == false)
        precondition(store.memoryWrites[0].text == "draft memory" && store.memoryWrites[0].hash == "original")
        store.memoryWrites[0].answer.resume(throwing: NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "runner unavailable"]))
        await wait { memory.confirmButton.isEnabled }
        precondition(editor.string == "draft memory" && editor.isEditable && !memory.didDismiss)
        precondition(descendants(memory.view).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "runner unavailable" && !$0.isHidden })
        print("PASS: memory pending save blocks duplicates/cancel; failure without a window preserves draft and shows error")

        var saved = false
        memory.onSaved = { saved = true }
        memory.confirmTapped()
        await wait { store.memoryWrites.count == 2 }
        memory.viewDidDisappear()
        store.memoryWrites[1].answer.resume(returning: "new hash")
        for _ in 0..<20 { await Task.yield() }
        precondition(!saved && !memory.didDismiss)
        print("PASS: memory callback after sheet disappears cannot dismiss or notify a new context")

        let focusedPlugin = PluginViewController(pluginID: "plugin", runner: Device(id: "runner", name: "Runner"), bot: nil)
        let hiddenWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 480), styleMask: [.titled], backing: .buffered, defer: false)
        let initialLoad = store.details.count
        hiddenWindow.contentViewController = focusedPlugin
        await wait { store.details.count == initialLoad + 1 }
        store.details[initialLoad].resume(returning: detail("initial", "untouched"))
        await wait { descendants(focusedPlugin.view).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "initial" } }
        let activeField = descendants(focusedPlugin.view).compactMap { $0 as? NSTextField }.first { $0.stringValue == "initial" }!
        precondition(hiddenWindow.makeFirstResponder(activeField))
        let fieldEditor = activeField.currentEditor() as! NSTextView
        fieldEditor.insertText("typed in the live field editor", replacementRange: NSRange(location: 0, length: fieldEditor.string.utf16.count))
        precondition(activeField.stringValue == "typed in the live field editor")
        store.emit(.rosterChanged)
        await wait { store.details.count == initialLoad + 2 }
        store.details[initialLoad + 1].resume(returning: detail("remote replacement", "updated"))
        await wait { descendants(focusedPlugin.view).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "updated" } }
        precondition(activeField.currentEditor() === fieldEditor && hiddenWindow.firstResponder === fieldEditor)
        precondition(fieldEditor.string == "typed in the live field editor" && activeField.stringValue == fieldEditor.string)
        hiddenWindow.close()
        print("PASS: active AppKit field-editor typing and keyboard focus survive plugin roster refresh")
    }

    static func detail(_ edited: String, _ untouched: String, secretSet: Bool = false) -> PluginDetail {
        PluginDetail(variables: [
            .init(name: "TOKEN", description: "secret", secret: true, required: false, isSet: secretSet, value: nil),
            .init(name: "EDITED", description: "edited", secret: false, required: false, isSet: true, value: edited),
            .init(name: "UNTOUCHED", description: "untouched", secret: false, required: false, isSet: true, value: untouched),
        ])
    }
    @MainActor static func wait(_ condition: () -> Bool) async {
        for _ in 0..<1000 { if condition() { return }; await Task.yield() }
        preconditionFailure("Timed out waiting for controller request/result")
    }
    @MainActor static func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
}
