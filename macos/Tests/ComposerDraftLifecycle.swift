import Foundation

@main
struct ComposerDraftLifecycleTests {
    static func main() {
        typealias Draft = MessageDraft<String, String>
        var drafts = ConversationDrafts<String, String, String>()
        let a = Draft(text: "给 A 的中文草稿\n@设计师", files: ["a.png"], mentions: ["bot-a"])
        let b = Draft(text: "给 B 的草稿", files: ["b.pdf"], mentions: ["bot-b"])
        precondition(drafts.select("A", current: Draft()) == Draft())
        precondition(drafts.select("B", current: a) == Draft(), "A's attachments cannot travel to B")
        precondition(drafts.select("A", current: b) == a, "Text, files and selected mentions return together")
        precondition(drafts.select("A", current: a) == a, "Refreshing the same chat preserves its draft")
        precondition(drafts.select("B", current: a) == b)
        print("PASS: Switching chats restores independent text, attachments and mentions")

        // A was submitted; its field is empty. The user starts B before A is rejected.
        _ = drafts.select("A", current: b)
        _ = drafts.select("B", current: Draft())
        precondition(drafts.recover(a, for: "A", current: b) == nil, "A's failed send must not modify B")
        precondition(drafts.select("A", current: b) == a, "Late failure restores its original chat")
        precondition(drafts.select("B", current: a) == b)
        print("PASS: A late failure cannot appear in a different conversation")

        let next = Draft(text: "新输入不能丢", files: ["new.png", "b.pdf"], mentions: ["bot-new", "bot-b"])
        let recovered = drafts.recover(b, for: "B", current: next)!
        precondition(recovered.text == "给 B 的草稿\n\n新输入不能丢")
        precondition(recovered.files == ["b.pdf", "new.png"])
        precondition(recovered.mentions == ["bot-b", "bot-new"])
        precondition(Draft().recovering(a) == a)
        let filesOnly = Draft(files: ["only.png"])
        precondition(next.recovering(filesOnly).text == next.text)
        precondition(next.recovering(filesOnly).files.contains("only.png"))
        print("PASS: Failed sends preserve newer edits, attachment-only messages and mention IDs")

        var identity = DraftIdentityScope()
        precondition(identity.useIdentity("alice", signedIn: true))
        let aliceRequest = identity.token
        precondition(!identity.useIdentity("alice", signedIn: true), "Same-account bootstrap must retain drafts")
        precondition(identity.token == aliceRequest)
        // Use the same reset boundary as the controllers; both visible and saved drafts clear.
        if identity.useIdentity("bob", signedIn: true) { drafts = ConversationDrafts() }
        precondition(identity.token != aliceRequest, "Alice's pending failure cannot restore into Bob")
        precondition(drafts.select("A", current: Draft()) == Draft())
        let bobRequest = identity.token
        precondition(identity.useIdentity("bob", signedIn: false), "Logout invalidates even a stale non-nil identity ID")
        precondition(identity.token != bobRequest)
        precondition(identity.useIdentity("alice", signedIn: true))
        precondition(identity.token != aliceRequest, "Returning to Alice cannot revive her old request")
        print("PASS: Identity changes and logout clear drafts and invalidate old callbacks; bootstrap preserves them")

        var visit = PageVisit()
        visit.appear()
        let librarySend = visit.token
        precondition(visit.contains(librarySend))
        visit.leave()
        precondition(!visit.contains(librarySend), "A hidden library cannot navigate on a late success")
        visit.appear()
        precondition(!visit.contains(librarySend), "Navigating away and back starts a different visit")
        precondition(visit.contains(visit.token))
        print("PASS: Late library sends never override later navigation")

        var recording = DictationSession()
        let first = recording.begin()
        precondition(recording.contains(first))
        recording.end()
        precondition(!recording.contains(first), "Canceled authorization cannot begin capture")
        let second = recording.begin()
        precondition(!recording.contains(first), "An old authorization/result/timer cannot affect a new recording")
        precondition(recording.contains(second))
        recording.end()
        precondition(!recording.isActive && !recording.contains(second))
        print("PASS: Cancellation invalidates authorization, recognition and delayed-stop sessions")
    }
}
