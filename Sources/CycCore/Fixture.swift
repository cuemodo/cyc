/// How Cyc reads its DMX channels, like the "mode" (or "personality") of a real
/// fixture. The desk must be patched with the same mode.
public enum FixtureMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case rgb
    case dimRGB
    case gradient
    case dimGradient

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .rgb: "RGB (3 ch)"
        case .dimRGB: "DRGB (4 ch)"
        case .gradient: "Gradient RGB (6 ch)"
        case .dimGradient: "Gradient DRGB (8 ch)"
        }
    }

    /// What each channel does, in order from the fixture's DMX address.
    ///
    /// Gradient modes are two RGB (or dimmer + RGB) blocks in a row, top then
    /// bottom, so the desk can patch them as two ordinary LED fixtures on
    /// consecutive addresses instead of needing a custom profile.
    public var channelNames: [String] {
        let block = (hasDimmer ? ["dimmer"] : []) + ["red", "green", "blue"]
        guard isGradient else { return block }
        return block.map { "top \($0)" } + block.map { "bottom \($0)" }
    }

    public var channelCount: Int { channelNames.count }

    /// A dimmer channel (also called intensity) scales its color: at 50% the
    /// color keeps its mix but gives half the light. Gradient modes have one
    /// dimmer per color.
    public var hasDimmer: Bool { self == .dimRGB || self == .dimGradient }

    /// Gradient modes blend a top color into a bottom color, like the top lights
    /// and ground row on a theatre cyc.
    public var isGradient: Bool { self == .gradient || self == .dimGradient }
}

/// What the projectors should show: a color at the top and one at the bottom,
/// blended in between. A solid color has the same top and bottom.
public struct FixtureLook: Equatable, Sendable {
    public let top: RGB
    public let bottom: RGB

    public init(top: RGB, bottom: RGB) {
        self.top = top
        self.bottom = bottom
    }

    public init(solid color: RGB) {
        self.init(top: color, bottom: color)
    }

    public static let black = FixtureLook(solid: .black)

    /// The same look at `level` (0...1) of its brightness.
    public func scaled(by level: Double) -> FixtureLook {
        FixtureLook(top: top.scaled(by: level), bottom: bottom.scaled(by: level))
    }
}

/// The virtual fixture: where it sits in the DMX universe and how it reads its channels.
public struct Fixture: Equatable, Codable, Sendable {
    /// First DMX channel the fixture uses, 1 to 512, as patched on the desk.
    public var address: Int
    public var mode: FixtureMode

    public init(address: Int = 1, mode: FixtureMode = .rgb) {
        self.address = address
        self.mode = mode
    }

    public var lastChannel: Int { address + mode.channelCount - 1 }

    /// False when the address is so high that some channels would fall past 512.
    public var fitsInUniverse: Bool {
        (1...ArtDmxPacket.channelCount).contains(address) && lastChannel <= ArtDmxPacket.channelCount
    }

    /// Turns the 512 levels of a universe into what the projectors should show.
    /// Channels that fall outside the universe read as 0.
    public func look(from levels: [UInt8]) -> FixtureLook {
        var next = address - 1
        func take() -> Double {
            defer { next += 1 }
            return levels.indices.contains(next) ? Double(levels[next]) / 255 : 0
        }
        func color() -> RGB {
            let dimmer = mode.hasDimmer ? take() : 1
            let red = take(), green = take(), blue = take()
            return RGB(red: red * dimmer, green: green * dimmer, blue: blue * dimmer)
        }
        let top = color()
        let bottom = mode.isGradient ? color() : top
        return FixtureLook(top: top, bottom: bottom)
    }
}
