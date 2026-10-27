# Cuemodo Cyc

A macOS app that makes projectors act as one DMX fixture: it receives Art-Net (sACN later), turns
the fixture's channels into a color or a top-to-bottom gradient, and draws it full screen on the
projector output through a few mapped quads. It runs next to QLab on the same Mac, so it must stay
light: draw only when something changes.

Read these before larger changes:

- [docs/architecture.md](docs/architecture.md): how the app works, in plain words
- [docs/roadmap.md](docs/roadmap.md): the step plan and current status (update it as steps land)
- [docs/decisions.md](docs/decisions.md): dated log of decisions (append new ones)

## Stack

- Swift Package (`Package.swift`), macOS 14+. SwiftUI for the settings window, AppKit for the
  fullscreen output window, Metal for drawing.
- `CycCore` holds everything testable without a screen; `Cyc` is the app. Keep logic out of views.
- Tests use XCTest (`swift test`).
- No third-party dependencies unless clearly worth it, and only permissive licenses (MIT, BSD,
  Apache 2.0).

## Conventions

- **Small, readable changes.** One step of the plan is one reviewable commit, well under 1000
  lines including tests.
- **Explain domain terms.** Readers may be new to lighting and to Swift. Doc comments define the
  lighting and graphics words they use (DMX, universe, homography...).
- **Values are normalized** (0.0 to 1.0) inside the app; DMX bytes are converted at the edge.
- **Originality.** Our own code only; never copy another product's code, UI or manuals.

## Naming

Write "Cuemodo Cyc" in prose. Lowercase `cyc` for the repo and folder names.
