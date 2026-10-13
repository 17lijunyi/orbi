import AppKit

// Production drawer, notes editor and AppStore mutation methods run against a delayed CLI.
struct Bot {
    typealias ID = String
    let id: ID
    var name: String { id }
    var description: String { "" }
    var runnerID: String { "runner" }
}
struct Device {
    enum Status { case online, offline }
    var name = "Runner"
    var status = Status.online
}
struct Chat {
    typealias ID = String
    enum Kind: String { case dm, group }
    static let maxGroupBots = 6
    let id: ID
    let kind: Kind
    let customTitle: String?
    let botIDs: [Bot.ID]
    var messages: [String]
    var unreadCount: Int
    var isPinned: Bool
    let createdAt: Date
    var isDM: Bool { kind == .dm }
    var lastActivity: Date { createdAt }
}
enum Wire { struct Snapshot { let identityId: String?; let chats: [Chat] } }
enum StoreEvent { case snapshotReplaced, rosterChanged, connectionChanged, chatsChanged, identityChanged }
@MainActor final class CLIClient {
    struct RequestError: LocalizedError { let message: String; var errorDescription: String? { message } }
    var pending: [CheckedContinuation<Void, Error>] = []
    var requestCount = 0
    var authoritativeSnapshot: Wire.Snapshot?
    func request(_ method: String, _ params: [String: Any]) async throws {
        requestCount += 1
        try await withCheckedThrowingContinuation { pending.append($0) }
    }
    func request(_ method: String, as type: Wire.Snapshot.Type) async throws -> Wire.Snapshot {
        guard let authoritativeSnapshot else { throw RequestError(message: "offline") }
        return authoritativeSnapshot
    }
    func finish(_ success: Bool) {
        let request = pending.removeFirst()
        if success { request.resume() }
        else { request.resume(throwing: RequestError(message: "CLI rejected the group")) }
    }
}
@MainActor final class AppStore {
    static let shared = AppStore()
    var identityID: String? = "alice"
    var hasIdentity: Bool? = true
    var identityGeneration = 0
    var isMock = false
    var isConnected = true
    var bots = [Bot(id: "one"), Bot(id: "two")]
    var chats: [Chat] = []
    let client = CLIClient()
    var observers: [(StoreEvent) -> Void] = []
    func observe(_ owner: AnyObject, _ handler: @escaping (StoreEvent) -> Void) { observers.append(handler) }
    func emit(_ event: StoreEvent) { observers.forEach { $0(event) } }
    func bot(_ id: Bot.ID) -> Bot? { bots.first { $0.id == id } }
    func device(_ id: String) -> Device? { Device() }
    func apply(snapshot: Wire.Snapshot) { chats = snapshot.chats; emit(.snapshotReplaced) }
    func switchIdentity(_ id: String) {
        identityID = id; identityGeneration += 1; chats = []; emit(.identityChanged)
    }
    func signedIn(_ value: Bool) {
        hasIdentity = value; identityGeneration += 1; chats = []; emit(.identityChanged)
    }
    // INSERT_CHAT_MUTATIONS
}
func L(_ value: String, _ arguments: CVarArg...) -> String { String(format: value, arguments: arguments) }
enum Theme { static let composerField = NSColor.textBackgroundColor }
enum Build {
    @MainActor static func label(_ title: String, font: NSFont, color: NSColor = .labelColor,
                                lines: Int = 1, alignment: NSTextAlignment = .left) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = font; label.textColor = color; label.maximumNumberOfLines = lines
        label.alignment = alignment; label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    @MainActor static func stack(_ views: [NSView], orientation: NSUserInterfaceLayoutOrientation = .vertical,
                                spacing: CGFloat = 0) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = orientation; stack.spacing = spacing; stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }
}
class BackgroundView: NSView {
    var fillColor = NSColor.clear
    var cornerRadius: CGFloat = 0
    override init(frame: NSRect) { super.init(frame: frame); translatesAutoresizingMaskIntoConstraints = false }
    required init?(coder: NSCoder) { fatalError() }
}
final class FlippedView: NSView { override var isFlipped: Bool { true } }
final class SelectableBotRow: NSView {
    var onToggle: (() -> Void)?
    var isEnabled = true, isSelected = false
    func configure(bot: Bot, detail: String, isOffline: Bool) {}
}
extension NSView {
    func pin(to parent: NSView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor), topAnchor.constraint(equalTo: parent.topAnchor),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor)])
    }
}

@main struct GroupSubmissionTests {
    @MainActor static func main() async {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        let store = AppStore.shared
        let form = TeammateDrawerViewController()
        _ = form.view
        let fields = descendants(form.view).compactMap { $0 as? NSTextField }
        let name = fields.first { $0.placeholderString == "Group name (optional)" }!
        let buttons = descendants(form.view).compactMap { $0 as? NSButton }
        let create = buttons.first { $0.title == "Create Group Chat" }!
        let back = buttons.first { $0.title == "Back" }!
        var opened: [String] = []
        form.onCreate = { opened.append($0) }
        name.stringValue = "保留项目小组"
        click(create)
        await until { store.client.pending.count == 1 }
        let firstID = store.chats[0].id
        click(create)
        precondition(store.client.requestCount == 1 && !name.isEnabled && !back.isEnabled && opened.isEmpty)
        store.client.finish(false)
        await until { create.isEnabled }
        precondition(store.chats.isEmpty && name.stringValue == "保留项目小组" && opened.isEmpty)
        precondition(fields.contains { $0.stringValue.contains("Your draft was kept") && !$0.isHidden })
        print("PASS: failed group creation rolls back its optimistic row and preserves the pending draft")

        click(create)
        await until { store.client.pending.count == 1 }
        let saved = store.chats[0]
        precondition(saved.id != firstID)
        store.client.authoritativeSnapshot = Wire.Snapshot(identityId: "alice", chats: [saved])
        store.client.finish(false)
        await until { !opened.isEmpty }
        precondition(opened == [saved.id] && store.chats.count == 1 && name.stringValue.isEmpty)
        print("PASS: a lost acknowledgement confirms the existing group from the authoritative snapshot")

        store.client.authoritativeSnapshot = nil
        name.stringValue = "Old account draft"
        click(create)
        await until { store.client.pending.count == 1 }
        store.switchIdentity("bob")
        store.switchIdentity("alice")
        name.stringValue = "New account draft"
        store.client.finish(true)
        await Task.yield()
        await Task.yield()
        precondition(opened.count == 1 && name.stringValue == "New account draft" && create.isEnabled && store.chats.isEmpty)
        print("PASS: switching accounts clears the group draft and rejects late submission callbacks")

        click(create)
        await until { store.client.pending.count == 1 }
        store.signedIn(false)
        precondition(!create.isEnabled && name.stringValue.isEmpty)
        store.signedIn(true)
        name.stringValue = "New signed-in draft"
        store.client.finish(true)
        await Task.yield()
        await Task.yield()
        precondition(opened.count == 1 && name.stringValue == "New signed-in draft")
        print("PASS: logout invalidates submissions even when the same identity ID remains cached")

        var originalVisit = 0, laterVisit = 0
        form.onCreate = { _ in originalVisit += 1 }
        click(create)
        await until { store.client.pending.count == 1 }
        form.onCreate = { _ in laterVisit += 1 }
        store.client.finish(true)
        await until { originalVisit == 1 }
        precondition(laterVisit == 0)
        print("PASS: a late creation result keeps its original drawer visit callback")

        checkNotesUndo()
    }

    @MainActor private static func checkNotesUndo() {
        let suite = "orbi.notes.undo.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkbenchStore(defaults: defaults)
        store.useIdentity("test")
        let form = QuickNotesViewController(store: store)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 360),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentViewController = form
        let editor = descendants(form.view).compactMap { $0 as? NSTextView }.first!
        window.makeFirstResponder(editor)
        editor.undoManager?.groupsByEvent = false
        editor.undoManager?.removeAllActions()
        editor.undoManager?.beginUndoGrouping()
        editor.insertText("可撤销的便笺", replacementRange: NSRange(location: 0, length: 0))
        editor.breakUndoCoalescing()
        editor.undoManager?.endUndoGrouping()
        precondition(store.note == "可撤销的便笺" && editor.undoManager?.canUndo == true,
                     "note=\(store.note), editor=\(editor.string), undo=\(String(describing: editor.undoManager?.canUndo))")
        editor.undoManager?.undo()
        precondition(editor.string.isEmpty && store.note.isEmpty,
                     "After undo: note=\(store.note), editor=\(editor.string)")
        editor.undoManager?.redo()
        precondition(editor.string == "可撤销的便笺" && store.note == editor.string)
        print("PASS: note undo and redo update the editor and its autosaved document")
    }

    @MainActor private static func click(_ button: NSButton) { _ = button.sendAction(button.action, to: button.target) }
    @MainActor private static func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
    @MainActor private static func until(_ predicate: () -> Bool) async {
        for _ in 0..<1000 {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        preconditionFailure("Timed out waiting for the controlled CLI")
    }
}
