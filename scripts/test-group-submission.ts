import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"

const root = resolve(import.meta.dir, "..")
const temporary = await mkdtemp(join(tmpdir(), "orbi-group-tests-"))
try {
  // Compile the actual request/rollback and chat-creation methods against a controlled CLI.
  const source = await readFile(join(root, "macos/Sources/Lorca/Model/AppStore.swift"), "utf8")
  const begin = source.indexOf("    private func perform(")
  const end = source.indexOf("    @discardableResult\n    func createBot(", begin)
  if (begin < 0 || end < 0) throw new Error("Chat mutation boundaries were not found")
  const harness = await readFile(join(root, "macos/Tests/GroupSubmission.swift"), "utf8")
  const testSource = join(temporary, "GroupSubmission.swift")
  await writeFile(testSource, harness.replace("    // INSERT_CHAT_MUTATIONS", source.slice(begin, end)))
  const executable = join(temporary, "test-group-submission")
  const compile = Bun.spawn([
    "swiftc", "-parse-as-library", "-swift-version", "5", testSource,
    "macos/Sources/Lorca/Sidebar/TeammateDrawerViewController.swift",
    "macos/Sources/Lorca/Chat/DraftState.swift",
    "macos/Sources/Lorca/Workbench/QuickNotesViewController.swift",
    "macos/Sources/Lorca/Model/WorkbenchStore.swift", "-o", executable,
  ], { cwd: root, stdout: "inherit", stderr: "inherit" })
  if (await compile.exited !== 0) throw new Error("Group regression harness compilation failed")
  const test = Bun.spawn([executable], { stdout: "inherit", stderr: "inherit" })
  if (await test.exited !== 0) throw new Error("Group regressions failed")
} finally {
  await rm(temporary, { recursive: true, force: true })
}
