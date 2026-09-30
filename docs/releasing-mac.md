# Releasing the Mac app

Orbi.app embeds [Sparkle](https://sparkle-project.org). Release builds enable updates when
the publisher provides both `FEED_URL` and `SPARKLE_PUBLIC_KEY`. The publishing script uses
an explicitly configured Cloudflare R2 bucket and download domain: a notarized `.dmg` for a
first download, a `.zip` Sparkle installs (with binary deltas from recent versions), and
`appcast.xml`, the feed the app polls. Sparkle checks every archive against the EdDSA public
key inside the app before it installs. After the setup below, one command produces all of it:

```sh
bun run release-mac 1.0.8
```

- Updater: [`macos/Sources/Lorca/App/Updater.swift`](../macos/Sources/Lorca/App/Updater.swift).
  **Check for Updates…** in the app menu, and the Updates rows in Settings ▸ General.
- Bundle: [`scripts/app.ts`](../scripts/app.ts) writes the version, `SUFeedURL`, and
  `SUPublicEDKey` into Info.plist, embeds Sparkle.framework, and signs.
- Release: [`scripts/release-mac.ts`](../scripts/release-mac.ts),
  [`scripts/generate-appcast.ts`](../scripts/generate-appcast.ts),
  [`scripts/changelog.ts`](../scripts/changelog.ts).

## One-time setup

The scripts run on [Bun](https://bun.sh). The disk image comes from
[`create-dmg`](https://github.com/create-dmg/create-dmg) and uploads go through
[rclone](https://rclone.org):

```sh
brew install create-dmg rclone
```

Sparkle's command-line tools arrive with the package. `swift package resolve` in `macos/` (or any
build) puts them in `macos/.build/artifacts/sparkle/Sparkle/bin`.

### 1. Sparkle signing key

Every update is signed with an Ed25519 key. The private key is the login keychain's Sparkle item
(Sparkle's default account, `ed25519`), and `generate_appcast` reads it from there; its public
half is the `SPARKLE_PUBLIC_KEY` build environment variable read by
[`scripts/app.ts`](../scripts/app.ts), which ships inside the app.

```sh
macos/.build/artifacts/sparkle/Sparkle/bin/generate_keys      # creates the keychain key on first setup
export SPARKLE_PUBLIC_KEY="$(macos/.build/artifacts/sparkle/Sparkle/bin/generate_keys -p)"
```

A Mac without the item imports it from a backup:

```sh
macos/.build/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle_private_key.txt   # export, for a password manager
macos/.build/artifacts/sparkle/Sparkle/bin/generate_keys -f sparkle_private_key.txt   # import on another Mac
```

Without the private key, no install in the field can be updated again.

### 2. Developer ID and notarization

The release workflow uses Developer ID signing and notarization, with the hardened runtime.
`release-mac.ts` passes the identity to `buildApp`, which signs innermost first: Sparkle's
XPC services, `Updater.app`, and `Autoupdate`, the framework, the bundled CLI (as `app.lorca.cli`),
then the app with the `com.apple.security.device.audio-input` entitlement Dictate needs.

- Install the **Developer ID Application** certificate in the login keychain. With more than one,
  set `SIGN_IDENTITY` to the full name or the SHA-1.
- Store notarization credentials once, as a keychain profile named `NOTARY`:

  ```sh
  xcrun notarytool store-credentials NOTARY --apple-id you@example.com --team-id XXXXXXXXXX
  ```

  It asks for an app-specific password; `--key` takes an App Store Connect API key instead.

### 3. R2 bucket and domain

1. Create your own R2 bucket, for example `orbi-mac-releases`, and set `R2_BUCKET`.
2. Attach a domain you own to it (R2 ▸ the bucket ▸ Settings ▸ Custom Domains).
   `DOWNLOAD_URL_PREFIX` is its public HTTPS base URL, ending in `/`.
3. Create an R2 API token with Object Read & Write on that bucket.

Configure the publisher's addresses before building. These example addresses are placeholders:

```sh
export R2_BUCKET="orbi-mac-releases"
export DOWNLOAD_URL_PREFIX="https://downloads.example.com/"
export FEED_URL="${DOWNLOAD_URL_PREFIX}appcast.xml"
```

The publishing script checks these values and `SPARKLE_PUBLIC_KEY` before building or uploading.

### 4. rclone remote

Add a remote named `r2` with `rclone config` (type S3, provider Cloudflare), or put this in
`~/.config/rclone/rclone.conf`:

```ini
[r2]
type = s3
provider = Cloudflare
access_key_id = <R2 access key id>
secret_access_key = <R2 secret access key>
endpoint = https://<ACCOUNT_ID>.r2.cloudflarestorage.com
region = auto
no_check_bucket = true
```

Check it:

```sh
rclone lsf "r2:$R2_BUCKET" --s3-no-check-bucket
```

## Cutting a release

1. Add a `## [1.0.8]` section at the top of [`CHANGELOG.md`](../CHANGELOG.md). The heading matches
   the version; the section becomes the notes Sparkle shows in the update window.
2. Run it:

   ```sh
   bun run release-mac 1.0.8
   ```

   The argument bumps `"version"` in the root [`package.json`](../package.json). Without an
   argument the script releases the version already there.
3. Commit `package.json` and `CHANGELOG.md`.

The script:

1. calls `buildApp("release")` from `scripts/app.ts`, the same build as `bun run build`: `cargo build
   --release` for the `lorca` CLI and the Markdown library, `swift build -c release` for the app,
   the CLI copied into `Contents/Resources/bin`, Sparkle embedded, and everything signed with the
   Developer ID under the hardened runtime (`macos/.build/bundle/release/Orbi.app`);
2. packs the app into `Orbi-<version>.dmg` and signs the image;
3. notarizes the image and staples the ticket to the image and to the app (notarizing the image
   covers the code inside it), then runs `codesign --verify` and `spctl --assess`;
4. pulls the 15 most recent archives and the published `appcast.xml` from R2, so
   `generate_appcast` can build deltas and keep the older entries;
5. zips the stapled app as `Orbi-<version>.zip`, writes the changelog section beside it as
   `Orbi-<version>.md`, and regenerates `appcast.xml`, signing with the keychain key;
6. uploads the image, the archives, the deltas, and the notes as immutable, and `appcast.xml` with
   a five-minute cache.

Everything is staged under `dist/mac/`.

To test an update, keep an older build in /Applications and choose **Check for Updates…**.
`bun run release-mac --local` stops after step 3: a notarized app and `.dmg` to try on another Mac,
with nothing published.

### Options

| Env | Default | Purpose |
| --- | --- | --- |
| `R2_BUCKET` | required for publishing | R2 bucket |
| `R2_REMOTE` | `r2` | rclone remote |
| `NOTARY_PROFILE` | `NOTARY` | `notarytool` keychain profile |
| `SIGN_IDENTITY` | `Developer ID Application` | codesigning identity |
| `SPARKLE_BIN` | the SwiftPM copy | directory holding `generate_appcast` |
| `DOWNLOAD_URL_PREFIX` | required for publishing | public base URL of the appcast's archive links, ending in `/` |
| `FEED_URL` | empty | full HTTPS URL of the publisher's appcast |
| `SPARKLE_PUBLIC_KEY` | empty | publisher's EdDSA public key |
| `HISTORY_COUNT` | `15` | recent archives pulled for deltas |
| `FORCE=1` | | replace a version that is already published |
| `NO_HISTORY=1` | | skip the old archives: a full download, no deltas |

## Notes

- **One version.** `"version"` in the root `package.json` is what `scripts/app.ts` writes into both
  `CFBundleShortVersionString` and `CFBundleVersion`.
  Sparkle compares `CFBundleVersion`, so it goes up with every release.
- **The update replaces the whole bundle**, the CLI in `Contents/Resources/bin` included. The app
  stops its CLI when it quits for the install and starts the new one on relaunch.
- **Sparkle lives in the bundle.** SwiftPM links against the framework under
  `macos/.build/artifacts`; `buildApp` copies it into `Contents/Frameworks`, which the
  `@executable_path/../Frameworks` rpath in `Package.swift` resolves against. Debug bundles carry it
  too, since the binary links it.
- **Configured release builds enable automatic checks** (`SUEnableAutomaticChecks`). Settings ▸
  General ▸ Updates turns them off, and has the switch for installing updates without asking.
  Both `FEED_URL` and `SPARKLE_PUBLIC_KEY` must be present to include the update configuration.
- **A debug build never updates.** `Updater.isEnabled` is false under `DEBUG`: the menu item and
  the settings rows leave themselves out of the dev loop's bundle.
- **The build is for the Mac that runs it.** `cargo build` and `swift build` target the host
  architecture, so a release cut on Apple silicon is an arm64 app.
- Old archives stay in R2, so an install far behind still has a full archive to move to.
