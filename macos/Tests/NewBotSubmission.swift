import AppKit

// Standalone controller regression harness. The real NewBotViewController is compiled
// unchanged; the store lets the test deliver roster events and delayed request results.
struct Bot { typealias ID = String }
struct Device {
    typealias ID = String
    let id: ID
    let name: String
    var isThisDevice = false
}
enum Accent { case indigo, blue, teal, pink, orange, green, purple, red }
struct ProviderCredential {
    var isConnected = true
    enum Kind: String, CaseIterable {
        case test = "Test provider"
        var subtitle: String { "API" }
        var models: [(id: String, label: String)] { [("model", "Model")] }
        var thinkingLevels: [(id: String, label: String)] { [] }
    }
}
enum StoreEvent { case snapshotReplaced, rosterChanged, connectionChanged, other }
@MainActor final class AppStore {
    static let shared = AppStore()
    var runners = [Device(id: "a", name: "A"), Device(id: "b", name: "B")]
    var isConnected = true
    var requests: [(id: String, runnerID: String, completion: (Result<Void, Error>) -> Void)] = []
    var observers: [(StoreEvent) -> Void] = []
    func observe(_ owner: AnyObject, _ handler: @escaping (StoreEvent) -> Void) { observers.append(handler) }
    func emit(_ event: StoreEvent) { observers.forEach { $0(event) } }
    func credential(for kind: ProviderCredential.Kind) -> ProviderCredential? { .init() }
    func createBot(name: String, description: String, symbolName: String, accent: Accent,
                   runnerID: Device.ID, provider: ProviderCredential.Kind, model: String?,
                   thinking: String?, avatarFileURL: URL?,
                   completion: ((Result<Void, Error>) -> Void)? = nil) -> Bot.ID {
        let id = "created-\(requests.count)"
        requests.append((id, runnerID, completion!))
        return id
    }
}
func L(_ value: String, _ arguments: CVarArg...) -> String { String(format: value, arguments: arguments) }
enum Theme { enum Font { static var caption: NSFont { .systemFont(ofSize: 11) } } }
enum Build {
    @MainActor static func label(_ title: String, font: NSFont, color: NSColor = .labelColor, lines: Int = 1) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = font
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    @MainActor static func stack(_ views: [NSView], orientation: NSUserInterfaceLayoutOrientation = .vertical, spacing: CGFloat = 0) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = orientation
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }
}
final class WrappingTextField: NSTextField {}
enum Glyph {
    static func symbol(_ name: String, pointSize: CGFloat, color: NSColor) -> NSImage? { nil }
}
enum PlushAvatar {
    struct Configuration {
        var shape = "circle", color = "#f667ad", eyes = "sparkle", glasses = "none", accessory = "none"
    }
    static var shapeOptions: [(id: String, title: String)] { [("circle", "圆形")] }
    static var eyeOptions: [(id: String, title: String)] { [("sparkle", "星星眼")] }
    static var glassesOptions: [(id: String, title: String)] { [("none", "无眼镜")] }
    static var accessoryOptions: [(id: String, title: String)] { [("none", "无配饰")] }
    static var palette: [(hex: String, title: String)] { [("#f667ad", "粉色")] }
    static func randomConfigurations(count: Int) -> [Configuration] { Array(repeating: .init(), count: count) }
    static func writePNG(for value: Configuration, side: Int) throws -> URL { URL(fileURLWithPath: "/unused-test-avatar.png") }
}
enum AvatarView {
    enum Content { case plush(PlushAvatar.Configuration) }
    static func render(_ content: Content, in rect: NSRect) {}
}
@MainActor class SheetViewController: NSViewController {
    let contentStack = Build.stack([])
    var confirmButton = NSButton(), cancelButton: NSButton? = NSButton()
    var didDismiss = false
    init(title: String, subtitle: String, width: CGFloat) { super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func loadView() {
        view = NSView()
        view.addSubview(contentStack)
    }
    func setButtons(confirm: String) { confirmButton.title = confirm }
    func fitSheetToContent() {}
    override func dismiss(_ sender: Any?) { didDismiss = true }
    @objc func dismissSheet() { dismiss(nil) }
    @objc func confirmTapped() {}
}

@main struct NewBotSubmissionTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let store = AppStore.shared
        var createdIDs: [String] = []
        let form = NewBotViewController { createdIDs.append($0) }
        _ = form.view
        let controls = descendants(form.view)
        let name = controls.compactMap { $0 as? NSTextField }.first { $0.placeholderString == "Name" }!
        let runners = controls.compactMap { $0 as? NSPopUpButton }.first!
        name.stringValue = "保留这个草稿"
        form.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: name))
        precondition(form.confirmButton.isEnabled)

        store.runners.reverse()
        store.emit(.rosterChanged)
        precondition(runners.selectedItem?.representedObject as? String == "a")
        precondition(runners.indexOfSelectedItem == 1)
        form.confirmTapped()
        precondition(store.requests.count == 1 && store.requests[0].runnerID == "a")
        form.confirmTapped()
        form.dismissSheet()
        precondition(store.requests.count == 1 && !form.didDismiss && createdIDs.isEmpty)
        precondition(!name.isEnabled && form.cancelButton?.isEnabled == false)
        print("PASS: roster reordering preserves runner ID; pending submit blocks duplicate and cancellation")

        store.requests[0].completion(.failure(NSError(domain: "test", code: 1)))
        precondition(!form.didDismiss && createdIDs.isEmpty)
        precondition(name.stringValue == "保留这个草稿" && name.isEnabled && form.confirmButton.isEnabled)
        print("PASS: failed creation keeps the form and draft available for retry")

        store.runners.removeAll { $0.id == "a" }
        store.emit(.rosterChanged)
        precondition(runners.selectedItem == nil && !form.confirmButton.isEnabled)
        form.confirmTapped()
        precondition(store.requests.count == 1)
        runners.selectItem(at: 0)
        _ = runners.sendAction(runners.action, to: runners.target)
        precondition(form.confirmButton.isEnabled)
        store.isConnected = false
        store.emit(.connectionChanged)
        precondition(!form.confirmButton.isEnabled)
        form.confirmTapped()
        precondition(store.requests.count == 1)
        print("PASS: removed runner and disconnected service cannot submit")

        store.isConnected = true
        store.emit(.connectionChanged)
        form.confirmTapped()
        precondition(store.requests.count == 2 && store.requests[1].runnerID == "b")
        store.requests[1].completion(.success(()))
        precondition(form.didDismiss && createdIDs == [store.requests[1].id])
        print("PASS: retry dismisses and opens the bot only after successful completion")
    }

    @MainActor private static func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
}
