import Foundation

/// Small local tools belong to the signed-in identity on this Mac.
@MainActor
final class WorkbenchStore {
    struct Task: Codable, Identifiable, Equatable {
        let id: UUID
        let title: String
        var isCompleted: Bool
    }

    private struct Document: Codable {
        var note = ""
        var tasks: [Task] = []
    }

    private let defaults: UserDefaults
    private var document = Document()
    private(set) var identityID: String?
    var onChange: (() -> Void)?
    var note: String { document.note }
    var tasks: [Task] { document.tasks }

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func useIdentity(_ identityID: String?) {
        guard identityID != self.identityID else { return }
        self.identityID = identityID
        document = identityID.flatMap { id in
            defaults.data(forKey: key(id)).flatMap { try? JSONDecoder().decode(Document.self, from: $0) }
        } ?? Document()
        onChange?()
    }

    func saveNote(_ text: String) {
        guard identityID != nil, text != document.note else { return }
        document.note = text
        persist()
    }

    @discardableResult
    func addTask(_ text: String) -> Bool {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard identityID != nil, !title.isEmpty else { return false }
        document.tasks.append(Task(id: UUID(), title: title, isCompleted: false))
        persist()
        return true
    }

    func toggleTask(_ id: UUID) {
        guard let index = document.tasks.firstIndex(where: { $0.id == id }) else { return }
        document.tasks[index].isCompleted.toggle()
        persist()
    }

    func removeTask(_ id: UUID) {
        guard document.tasks.contains(where: { $0.id == id }) else { return }
        document.tasks.removeAll { $0.id == id }
        persist()
    }

    func clearCompleted() {
        guard document.tasks.contains(where: \.isCompleted) else { return }
        document.tasks.removeAll(where: \.isCompleted)
        persist()
    }

    private func key(_ id: String) -> String { "orbi.workbench.\(id)" }

    private func persist() {
        guard let identityID, let data = try? JSONEncoder().encode(document) else { return }
        defaults.set(data, forKey: key(identityID))
        onChange?()
    }
}
