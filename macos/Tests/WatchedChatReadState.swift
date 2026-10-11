import AppKit
import Foundation

// A local store double exercises the production Notifier without a CLI, account, or windows.
// markRead emits the same nested chatsChanged event as AppStore, covering reentrancy too.
struct Message {
    typealias ID = String
    var id: ID
    enum Body { case permission(Permission), tool(Tool), text }
    var body: Body
}
struct Permission { var isPending = false }
struct Tool {
    struct Run { enum State { case asking }; var state: State }
    var run: Run?
}
struct Bot { typealias ID = String; var name: String }
struct Chat {
    typealias ID = String
    var id: ID
    var unreadCount: Int
    var messages: [Message] = []
    var isDM = true
}
enum StoreEvent {
    case connectionChanged, snapshotReplaced, identityChanged, chatsChanged
    case messageAdded(Chat.ID, Message.ID), messageChanged(Chat.ID, Message.ID)
    case messageRemoved(Chat.ID, Message.ID), turnFinished(Chat.ID, Bot.ID, Date)
    case unrelated
}
@MainActor
final class AppStore {
    static let shared = AppStore()
    var chats: [Chat] = []
    var identityID: String? = "test-account"
    var watchedChat: Chat.ID?
    var clearedChats: [Chat.ID] = []
    private var observers: [(StoreEvent) -> Void] = []
    func observe(_ owner: AnyObject, _ handler: @escaping (StoreEvent) -> Void) { observers.append(handler) }
    func emit(_ event: StoreEvent) { observers.forEach { $0(event) } }
    func chat(_ id: Chat.ID) -> Chat? { chats.first { $0.id == id } }
    func bot(_ id: Bot.ID) -> Bot? { nil }
    func title(for chat: Chat) -> String { chat.id }
    func setWatchedChat(_ id: Chat.ID?) { watchedChat = id }
    func markRead(_ id: Chat.ID) {
        guard let index = chats.firstIndex(where: { $0.id == id }), chats[index].unreadCount > 0 else { return }
        chats[index].unreadCount = 0
        clearedChats.append(id)
        emit(.chatsChanged)
    }
    func unread(_ id: Chat.ID, _ count: Int) { chats[chats.firstIndex { $0.id == id }!].unreadCount = count }
}
struct ChatNotification {
    enum Kind { case permission }
    let kind = Kind.permission
    let botID = "bot"
    let messageID = "message"
    let body = ""
    init?(_ message: Message) { return nil }
    static func finishedTurn(in chat: Chat, botID: Bot.ID, startedAt: Date) -> ChatNotification? { nil }
    func canDeliver(in chat: Chat, watchedChat: Chat.ID?) -> Bool { false }
}

@main
struct WatchedChatReadStateTests {
    @MainActor
    static func main() {
        var active = false
        var focusedChat: Chat.ID? = "floating-a"
        let store = AppStore.shared
        store.chats = [Chat(id: "floating-a", unreadCount: 4), Chat(id: "main-b", unreadCount: 2)]
        let notifier = Notifier(isApplicationActive: { active })
        notifier.visibleChat = { focusedChat }
        notifier.start()
        precondition(store.clearedChats.isEmpty, "An inactive app must not mark a visible floating chat read")

        active = true
        notifier.watchingChanged()
        precondition(store.chat("floating-a")?.unreadCount == 0)
        precondition(store.chat("main-b")?.unreadCount == 2)
        precondition(store.watchedChat == "floating-a")
        let afterFocus = store.clearedChats.count
        notifier.watchingChanged()
        precondition(store.clearedChats.count == afterFocus, "Repeated focus must not resend a read mark")
        print("PASS: Focusing a floating chat clears only its unread count, without recursive read writes")

        for event in [StoreEvent.messageAdded("floating-a", "new"), .messageChanged("floating-a", "new"), .chatsChanged] {
            store.unread("floating-a", 3)
            store.emit(event)
            precondition(store.chat("floating-a")?.unreadCount == 0, "Live message and late roster updates must clear while reading")
        }
        store.emit(.messageAdded("main-b", "other"))
        precondition(store.chat("main-b")?.unreadCount == 2, "A message in an unfocused chat must stay unread")
        print("PASS: Messages and late unread metadata clear for the watched chat only")

        active = false
        store.unread("floating-a", 5)
        notifier.watchingChanged()
        store.emit(.messageAdded("floating-a", "background"))
        store.emit(.chatsChanged)
        precondition(store.chat("floating-a")?.unreadCount == 5)
        precondition(store.watchedChat == nil)
        active = true
        focusedChat = nil
        notifier.watchingChanged()
        store.emit(.chatsChanged)
        precondition(store.chat("floating-a")?.unreadCount == 5, "A tool panel or settings focus must not clear an unfocused floating chat")
        print("PASS: App deactivation and non-chat focus retain unread counts")

        focusedChat = "floating-a"
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        precondition(store.chat("floating-a")?.unreadCount == 0, "Reactivating the app must mark the focused chat read")
        precondition(store.chat("main-b")?.unreadCount == 2)
        print("PASS: App activation marks the focused floating chat read")
    }
}
