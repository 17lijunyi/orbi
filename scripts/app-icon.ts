import { mkdir } from "node:fs/promises"
import { join } from "node:path"
import { ROOT, RESOURCES_DIR, APP_ICON_NAME } from "./app.ts"

// Package the selected full-bleed artwork at every native macOS icon size.
// sips only resamples it; the source contains the final composition and background.
const source = join(RESOURCES_DIR, "Orbi.png")
const iconset = join(ROOT, "temp", "Orbi.iconset")
await mkdir(iconset, { recursive: true })

async function run(command: string[]) {
  const process = Bun.spawn(command, { stdout: "ignore", stderr: "inherit" })
  if (await process.exited !== 0) throw new Error(`${command[0]} failed`)
}

for (const size of [16, 32, 128, 256, 512]) {
  for (const scale of [1, 2]) {
    const pixels = String(size * scale)
    const filename = `icon_${size}x${size}${scale === 2 ? "@2x" : ""}.png`
    await run(["sips", "-z", pixels, pixels, source, "--out", join(iconset, filename)])
  }
}

const destination = join(RESOURCES_DIR, APP_ICON_NAME)
await run(["iconutil", "-c", "icns", "-o", destination, iconset])
console.log(`Built ${destination}`)
