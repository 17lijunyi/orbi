import Foundation

@main
struct WorkbenchPersistenceTests {
    @MainActor
    static func main() {
        let suite = "orbi.workbench.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = WorkbenchStore(defaults: defaults)
        original.useIdentity("alice")
        original.saveNote("会议想法\n保留中文与换行 🌱")
        precondition(!original.addTask(" \n "), "Whitespace cannot become a task")
        precondition(original.addTask("准备设计方案"))
        precondition(original.addTask("完成原型"))
        let first = original.tasks[0].id
        let second = original.tasks[1].id
        precondition(first != second)
        original.toggleTask(first)

        // A new store represents a restarted app, reading persisted identity data.
        let restarted = WorkbenchStore(defaults: defaults)
        restarted.useIdentity("alice")
        precondition(restarted.note == original.note)
        precondition(restarted.tasks == original.tasks)
        precondition(restarted.tasks[0].isCompleted)
        print("PASS: Unicode notes, task IDs and completion survive restart")

        restarted.useIdentity("bob")
        precondition(restarted.note.isEmpty && restarted.tasks.isEmpty)
        restarted.saveNote("Bob's private draft")
        precondition(restarted.addTask("Bob's task"))
        restarted.useIdentity(nil)
        restarted.saveNote("A logged-out edit")
        precondition(!restarted.addTask("A logged-out task"))
        precondition(restarted.note.isEmpty && restarted.tasks.isEmpty)
        restarted.useIdentity("alice")
        precondition(restarted.note == original.note && restarted.tasks == original.tasks)
        restarted.useIdentity("bob")
        precondition(restarted.note == "Bob's private draft" && restarted.tasks.count == 1)
        print("PASS: Account switching and logout isolate local documents")

        restarted.useIdentity("alice")
        restarted.clearCompleted()
        precondition(restarted.tasks.map(\.id) == [second])
        restarted.removeTask(second)
        let afterRemoval = WorkbenchStore(defaults: defaults)
        afterRemoval.useIdentity("alice")
        precondition(afterRemoval.tasks.isEmpty)
        precondition(afterRemoval.note == original.note)
        print("PASS: Clearing and deletion persist without altering notes")
    }
}
