import { resolve } from "node:path"

const root = resolve(import.meta.dir, "..")
for (const script of [
  "test-composer-drafts.ts", "test-attachment-retry.ts",
  "test-watched-chat.ts", "test-newbot-submission.ts",
]) {
  const test = Bun.spawn(["bun", "run", `scripts/${script}`], {
    cwd: root, stdout: "inherit", stderr: "inherit",
  })
  if (await test.exited !== 0) throw new Error(`${script} failed`)
}
