import Foundation

/// One request per file, with bounded backoff after failures. Tokens keep completions from
/// an earlier connection or account from changing the current state.
struct AttachmentRetryState {
    private struct Entry {
        var failures = 0
        var token: UUID?
        var retryAt: Date?
    }
    private var entries: [String: Entry] = [:]

    mutating func begin(_ id: String, now: Date = Date()) -> UUID? {
        var entry = entries[id] ?? Entry()
        guard entry.token == nil, entry.retryAt.map({ $0 <= now }) ?? true else { return nil }
        let token = UUID()
        entry.token = token
        entry.retryAt = nil
        entries[id] = entry
        return token
    }

    mutating func succeeded(_ id: String, token: UUID) -> Bool {
        guard entries[id]?.token == token else { return false }
        entries[id] = nil
        return true
    }

    mutating func failed(_ id: String, token: UUID, now: Date = Date()) -> Bool {
        guard var entry = entries[id], entry.token == token else { return false }
        entry.token = nil
        entry.failures = min(entry.failures + 1, 6)
        entry.retryAt = now.addingTimeInterval(min(pow(2, Double(entry.failures - 1)), 30))
        entries[id] = entry
        return true
    }

    var nextRetry: Date? { entries.values.compactMap(\.retryAt).min() }

    /// A due file becomes ready to fetch when a visible avatar or message asks for it again.
    /// An offscreen file does not keep waking the app after its deadline.
    mutating func takeDue(now: Date = Date()) -> [String] {
        let due = entries.compactMap { id, entry in entry.retryAt.map { $0 <= now } == true ? id : nil }
        for id in due { entries[id]?.retryAt = nil }
        return due
    }

    mutating func reset() { entries.removeAll() }
}
