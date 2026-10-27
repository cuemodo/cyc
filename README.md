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

## Layout

- `Sources/CycCore/`: logic that needs no screen (DMX, fixture modes, mapping math), unit tested
- `Sources/Cyc/`: the macOS app (windows, Metal drawing, settings UI)
- `Tests/CycCoreTests/`: XCTest tests for CycCore

## Docs

- [Architecture](docs/architecture.md): how it works, in plain words
- [Roadmap](docs/roadmap.md): the step plan and status
- [Decisions](docs/decisions.md): dated decision log

## License

MIT, see [LICENSE](LICENSE).
