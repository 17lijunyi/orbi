import { mkdtemp, rm } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"

const root = resolve(import.meta.dir, "..")
const temporary = await mkdtemp(join(tmpdir(), "orbi-watched-chat-tests-"))
try {
  const executable = join(temporary, "test-watched-chat")
  const compile = Bun.spawn([
    "swiftc", "-parse-as-library", "-swift-version", "5",
    "macos/Tests/WatchedChatReadState.swift",
    "macos/Sources/Lorca/App/Notifier.swift",
    "-o", executable,
  ], { cwd: root, stdout: "inherit", stderr: "inherit" })
  if (await compile.exited !== 0) throw new Error("Watched chat test compilation failed")
  const test = Bun.spawn([executable], { stdout: "inherit", stderr: "inherit" })
  if (await test.exited !== 0) throw new Error("Watched chat tests failed")
} finally {
  await rm(temporary, { recursive: true, force: true })
}
