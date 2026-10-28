<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/cuemodo-lockup-horizontal-on-dark.svg">
  <img src="docs/images/cuemodo-lockup-horizontal-on-light.svg" alt="Cuemodo" width="400">
</picture>

# Cuemodo Cyc

Turn projectors into one DMX-controlled light. Cuemodo Cyc is a small macOS app that listens for
Art-Net, behaves like a single fixture (a solid RGB color, or a top-to-bottom gradient like a
theatre cyc), and fills the projector output with that color. A simple quad mapper keeps the light
inside the wash area and stops overlapping projectors from doubling up.

Part of the [Cuemodo](https://cuemodo.io) family of show-control tools. Early development.

## Build and run

Needs macOS 14 or later and Xcode (for the Swift toolchain).

```
swift build
swift run Cyc
swift test
```

Or open `Package.swift` in Xcode and press Run.

## Release

A release is a notarized DMG on the GitHub releases page. Notarization means Apple has scanned the
signed app, so it opens on any Mac without a security warning.

### One-time setup

1. Install the tools:
   ```sh
   brew install create-dmg gh
   ```
2. Check that a **Developer ID Application** certificate is in your keychain:
   ```sh
   security find-identity -v -p codesigning
   ```
   If none is listed, create one in Xcode → Settings → Accounts → Manage Certificates → **+** →
   Developer ID Application.
3. Save notarization credentials as a keychain profile named `notary`, using an app-specific
   password from [account.apple.com](https://account.apple.com). One profile serves all your apps:
   ```sh
   xcrun notarytool store-credentials "notary" \
     --apple-id you@example.com --team-id TEAMID
   ```

### Versioning

The version (`X.Y.Z`) lives in `Sources/CycCore/CycInfo.swift`. The build number is the commit
count, so it goes up by itself and never resets.

### Making a release

The tag is created first, so it names exactly what gets built, but pushed last, once Apple has
accepted the build. If a step fails before the push, delete the local tag
(`git tag -d vX.Y.Z`), fix, commit, and start again from step 2.

1. Set the new version in `CycInfo.version` and commit only that change:
   `Bump version to X.Y.Z`.
2. Tag that commit locally (do not push yet):
   ```sh
   git tag -a vX.Y.Z -m "Cuemodo Cyc X.Y.Z"
   ```
3. Build, sign and notarize the app (writes `dist/Cuemodo Cyc.app` and a zip of it):
   ```sh
   scripts/package.sh
   ```
   It stops straight away if there are uncommitted changes, if the current commit is not tagged
   `vX.Y.Z` (the version in `CycInfo.version`), or if that tag is already on GitHub (the version
   was released already).
4. Put the app in a signed, notarized DMG with a drag-to-Applications window (writes
   `dist/Cuemodo-Cyc-X.Y.Z.dmg`):
   ```sh
   scripts/make-dmg.sh
   ```
5. Push the tag:
   ```sh
   git push origin vX.Y.Z
   ```
6. Create a draft release on GitHub, then edit the notes there and click **Publish**:
   ```sh
   gh release create vX.Y.Z dist/Cuemodo-Cyc-X.Y.Z.dmg --verify-tag \
     --title "Cuemodo Cyc X.Y.Z" --notes-from-tag --draft
   ```

Both scripts take `--no-notarize` to stop after signing, for a quick check of the app or the DMG
window. Both read these environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SIGN_IDENTITY` | `Developer ID Application` | Code-signing certificate. Use the full name if you have more than one, e.g. `Developer ID Application: Your Name (TEAMID)`. |
| `NOTARY_PROFILE` | `notary` | Keychain profile used by `notarytool`. |

## Layout

- `Sources/CycCore/`: logic that needs no screen (DMX, fixture modes, mapping math), unit tested
- `Sources/Cyc/`: the macOS app (windows, Metal drawing, main window UI)
- `Tests/CycCoreTests/`: XCTest tests for CycCore
- `scripts/package.sh`: wraps the build into a signed, notarized .app
- `scripts/make-dmg.sh`: puts that app into a signed, notarized DMG

## Docs

- [Architecture](docs/architecture.md): how it works, in plain words
- [Roadmap](docs/roadmap.md): the step plan and status
- [Decisions](docs/decisions.md): dated decision log
- [Show checklist](docs/show-checklist.md): setup, CPU/GPU check, before each show

## License

MIT, see [LICENSE](LICENSE).
