// swift-tools-version:5.10
// Build with `swift build`, run with `swift run Cyc`, test with `swift test`,
// or open this file in Xcode.

import PackageDescription

let package = Package(
    name: "Cyc",
    platforms: [.macOS(.v14)],
    targets: [
        // Everything that can be tested without a screen: DMX parsing,
        // fixture modes, mapping math, settings.
        .target(name: "CycCore"),
        // The macOS app itself: windows, Metal drawing, settings UI. The
        // logo images come from the Cuemodo brand kit.
        .executableTarget(name: "Cyc", dependencies: ["CycCore"], resources: [.process("Resources")]),
        .testTarget(name: "CycCoreTests", dependencies: ["CycCore"]),
    ]
)
