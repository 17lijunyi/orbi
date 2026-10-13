import { mkdtemp, rm } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"

const root = resolve(import.meta.dir, "..")
const temporary = await mkdtemp(join(tmpdir(), "orbi-sheet-tests-"))
try {
  const executable = join(temporary, "test-sheet-drafts")
  const compile = Bun.spawn([
    "swiftc", "-parse-as-library", "-swift-version", "5",
    "macos/Tests/SheetDrafts.swift",
    "macos/Sources/Lorca/Sheets/PluginViewController.swift",
    "macos/Sources/Lorca/Sheets/MemoryViewController.swift",
    "-o", executable,
  ], { cwd: root, stdout: "inherit", stderr: "inherit" })
  if (await compile.exited !== 0) throw new Error("Sheet draft regression harness compilation failed")
  const test = Bun.spawn([executable], { stdout: "inherit", stderr: "inherit" })
  if (await test.exited !== 0) throw new Error("Sheet draft regressions failed")
} finally {
  await rm(temporary, { recursive: true, force: true })
}
