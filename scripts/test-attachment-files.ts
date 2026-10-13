import { mkdtemp, rm } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"

const root = resolve(import.meta.dir, "..")
const temporary = await mkdtemp(join(tmpdir(), "orbi-attachment-files-tests-"))
try {
  const executable = join(temporary, "test-attachment-files")
  const compile = Bun.spawn([
    "swiftc", "-parse-as-library", "-swift-version", "5",
    "macos/Tests/AttachmentFileBehavior.swift", "macos/Sources/Lorca/Chat/AttachmentFiles.swift",
    "-o", executable,
  ], { cwd: root, stdout: "inherit", stderr: "inherit" })
  if (await compile.exited !== 0) throw new Error("Attachment file test compilation failed")
  let failed = false
  for (const scenario of ["paste", "thumbnail"]) {
    const test = Bun.spawn([executable, scenario], {
      env: { ...process.env, TMPDIR: temporary }, stdout: "inherit", stderr: "inherit",
    })
    if (await test.exited !== 0) failed = true
  }
  if (failed) throw new Error("Attachment file tests failed")
} finally {
  await rm(temporary, { recursive: true, force: true })
}
