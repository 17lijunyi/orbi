import Foundation

/// A logout invalidates pending callbacks even if the same account signs in again later.
struct DraftIdentityScope {
    private var identityID: String?
    private var signedIn = false
    private(set) var token = UUID()

    @discardableResult
    mutating func useIdentity(_ identityID: String?, signedIn: Bool) -> Bool {
        let identityID = signedIn ? identityID : nil
        guard self.identityID != identityID || self.signedIn != signedIn else { return false }
        self.identityID = identityID
        self.signedIn = signedIn
        token = UUID()
        return true
    }
}

/// Late requests may navigate only during the visit that initiated them.
struct PageVisit {
    private(set) var token = UUID()
    private(set) var isVisible = false

    mutating func appear() { isVisible = true }
    mutating func leave() { isVisible = false; token = UUID() }
    func contains(_ token: UUID) -> Bool { isVisible && self.token == token }
}

/// The whole unsent message travels together when its conversation changes.
struct MessageDraft<File: Hashable, Mention: Hashable>: Equatable {
    var text = ""
    var files: [File] = []
    var mentions: [Mention] = []

    /// A failed send must not replace text or files entered while it was in flight.
    func recovering(_ failed: Self) -> Self {
        let combinedText: String
        if text.isEmpty { combinedText = failed.text }
        else if failed.text.isEmpty { combinedText = text }
        else { combinedText = failed.text + "\n\n" + text }
        var combined = Self(text: combinedText, files: failed.files, mentions: failed.mentions)
        for file in files where !combined.files.contains(file) { combined.files.append(file) }
        for mention in mentions where !combined.mentions.contains(mention) { combined.mentions.append(mention) }
        return combined
    }
}

/// Keeps the visible composer and late send failures attached to their conversation.
struct ConversationDrafts<Key: Hashable, File: Hashable, Mention: Hashable> {
    typealias Draft = MessageDraft<File, Mention>
    private(set) var active: Key?
    private var saved: [Key: Draft] = [:]

    mutating func select(_ key: Key, current: Draft) -> Draft {
        guard key != active else { return current }
        if let active { saved[active] = current }
        active = key
        return saved.removeValue(forKey: key) ?? Draft()
    }

    /// Returns a replacement only when the failed message belongs to the visible composer.
    mutating func recover(_ failed: Draft, for key: Key, current: Draft) -> Draft? {
        if key == active { return current.recovering(failed) }
        saved[key] = (saved[key] ?? Draft()).recovering(failed)
        return nil
    }
}
