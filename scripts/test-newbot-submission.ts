import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"

const root = resolve(import.meta.dir, "..")
const temporary = await mkdtemp(join(tmpdir(), "orbi-newbot-tests-"))
try {
  const source = await readFile(join(root, "macos/Sources/Lorca/Sheets/NewBotViewController.swift"), "utf8")
  const pairingMarker = source.indexOf("// MARK: - Pairing")
  if (pairingMarker < 0) throw new Error("New Bot controller boundary was not found")
  const controller = join(temporary, "NewBotViewController.swift")
  await writeFile(controller, source.slice(0, pairingMarker))
  const executable = join(temporary, "test-newbot-submission")
  const compile = Bun.spawn([
    "swiftc", "-parse-as-library", "-swift-version", "5",
    "macos/Tests/NewBotSubmission.swift", controller, "-o", executable,
  ], { cwd: root, stdout: "inherit", stderr: "inherit" })
  if (await compile.exited !== 0) throw new Error("New Bot regression harness compilation failed")
  const test = Bun.spawn([executable], { stdout: "inherit", stderr: "inherit" })
  if (await test.exited !== 0) throw new Error("New Bot regressions failed")
} finally {
  await rm(temporary, { recursive: true, force: true })
}
