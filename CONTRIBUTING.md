# Contributing to Cuemodo Cyc

Thanks for your interest. This page is for building Cuemodo Cyc from source and changing it. To
simply use the app, download it from the [releases page](https://github.com/cuemodo/cyc/releases)
and see the [README](README.md).

## Build and run

Needs macOS 14 or later and Xcode (for the Swift toolchain).

```sh
swift build
swift run Cyc
swift test
```

Or open `Package.swift` in Xcode and press Run.

When run with `swift run`, macOS asks for network access on behalf of Terminal (or your terminal
app), not Cuemodo Cyc.

## Layout

- `Sources/CycCore/`: logic that needs no screen (DMX, fixture modes, mapping math), unit tested
- `Sources/Cyc/`: the macOS app (windows, Metal drawing, main window UI)
- `Tests/CycCoreTests/`: XCTest tests for CycCore
- `scripts/package.sh`: wraps the build into a signed, notarized .app
- `scripts/make-dmg.sh`: puts that app into a signed, notarized DMG

## Docs

Read these before larger changes:

- [Architecture](docs/architecture.md): how it works, in plain words
- [Roadmap](docs/roadmap.md): the step plan and status
- [Decisions](docs/decisions.md): dated decision log
- [Show checklist](docs/show-checklist.md): setup, CPU/GPU check, before each show

## Conventions

- **Stack:** a Swift package for macOS 14+. SwiftUI for the main window, AppKit for the full-screen
  output window, Metal for drawing.
- **Keep logic out of views:** anything testable without a screen goes in `CycCore`, with XCTest
  tests.
- **Stay light:** the app runs next to QLab, so it draws only when something changes.
- **Small, readable changes:** one roadmap step is one reviewable commit, well under 1000 lines
  including tests.
- **Explain domain terms:** readers may be new to lighting and to Swift. Doc comments define the
  lighting and graphics words they use (DMX, universe, homography...).
- **Values are normalized** (0.0 to 1.0) inside the app; DMX bytes are converted at the edge.
- **Dependencies:** none unless clearly worth it, and only under permissive licenses (MIT, BSD,
  Apache 2.0).
- **Originality:** our own code only; never copy another product's code, UI or manuals.
- **Naming:** write "Cuemodo Cyc" in prose, lowercase `cyc` for the repo and folder names.
- Update the [roadmap](docs/roadmap.md) as steps land and add new decisions to the
  [decision log](docs/decisions.md).

CI runs `swift build` and `swift test` on every push and pull request.

## Releasing (maintainers)

A release is a notarized DMG on the GitHub releases page. Notarization means Apple has scanned the
signed app, so it opens on any Mac without a security warning. It needs the project's Developer ID
certificate, so only maintainers can make one.

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

## License

By contributing, you agree that your contributions are released under the project's
[MIT License](LICENSE).
