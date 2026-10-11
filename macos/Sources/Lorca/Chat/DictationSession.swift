import Foundation

/// Authorization and recognition callbacks belong to one recording, never the next one.
struct DictationSession {
    private(set) var token: UUID?
    var isActive: Bool { token != nil }

    mutating func begin() -> UUID {
        let token = UUID()
        self.token = token
        return token
    }

    func contains(_ token: UUID) -> Bool { self.token == token }

    mutating func end() { token = nil }
}
