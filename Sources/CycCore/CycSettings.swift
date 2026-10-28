import Foundation

/// What the output shows: the fixture driven by Art-Net, colors picked by hand
/// in the app, or a test pattern (for now a grid drawn on the canvas) for
/// lining up the mapping on the wall.
public enum OutputSource: String, CaseIterable, Identifiable, Codable, Sendable {
    case artNet
    case manual
    case testPattern

    public var id: Self { self }

    public var name: String {
        switch self {
        case .artNet: "Art-Net"
        case .manual: "Manual"
        case .testPattern: "Test Pattern"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        // Names used before 0.0.10: "testColor" (Manual) and "grid".
        let renamed = ["testColor": "manual", "grid": "testPattern"]
        guard let source = OutputSource(rawValue: renamed[raw] ?? raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Unknown output source \(raw)"))
        }
        self = source
    }
}

/// Everything Cyc remembers between launches. Saved as one JSON file that starts
/// with `"format": "cuemodo-cyc-settings"` and a version number, like Cuemodo's
/// show files. Values missing from a file keep their defaults, so files from
/// older versions still load.
public struct CycSettings: Equatable, Sendable {
    public static let format = "cuemodo-cyc-settings"
    public static let version = 1

    /// Art-Net Port-Address, counted from 0.
    public var universe = 0
    public var fixture = Fixture()
    public var source = OutputSource.artNet
    /// The Manual look: one color, or a top-to-bottom gradient. Separate from
    /// the fixture mode, so testing never changes the desk patch.
    public var manualGradient = false
    public var manualTop = RGB(red: 1, green: 0.7, blue: 0.28)
    public var manualBottom = RGB(red: 0.1, green: 0.2, blue: 0.8)
    /// The output display. macOS display IDs can change after a restart or
    /// replug, so its name is kept as a fallback.
    public var displayID: UInt32?
    public var displayName: String?
    /// Where the canvas lands on the output. Empty means "fill the whole output".
    public var mapping = Mapping()
    /// What to do when Art-Net stops, and after how many seconds of silence.
    public var signalLoss = SignalLoss.hold
    public var signalLossTimeout = 5.0
    /// Show lock: the windows ignore clicks and keys until unlocked.
    public var locked = false

    public init() {}
}

public enum SettingsError: Error, Equatable, CustomStringConvertible {
    case notCycSettings
    case newerVersion(Int)

    public var description: String {
        switch self {
        case .notCycSettings:
            "This is not a Cuemodo Cyc settings file."
        case .newerVersion(let version):
            "This settings file is version \(version), made by a newer Cuemodo Cyc."
        }
    }
}

extension CycSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case format, version, universe, fixture, source, manualGradient, manualTop, manualBottom, displayID, displayName, mapping
        case signalLoss, signalLossTimeout, locked
        case testColor  // before 0.0.10, read only
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(String.self, forKey: .format) == Self.format else {
            throw SettingsError.notCycSettings
        }
        let version = try container.decode(Int.self, forKey: .version)
        guard version <= Self.version else { throw SettingsError.newerVersion(version) }

        self.init()
        universe = try container.decodeIfPresent(Int.self, forKey: .universe) ?? universe
        fixture = try container.decodeIfPresent(Fixture.self, forKey: .fixture) ?? fixture
        source = try container.decodeIfPresent(OutputSource.self, forKey: .source) ?? source
        manualGradient = try container.decodeIfPresent(Bool.self, forKey: .manualGradient) ?? manualGradient
        manualTop = try container.decodeIfPresent(RGB.self, forKey: .manualTop)
            ?? container.decodeIfPresent(RGB.self, forKey: .testColor) ?? manualTop
        manualBottom = try container.decodeIfPresent(RGB.self, forKey: .manualBottom) ?? manualBottom
        displayID = try container.decodeIfPresent(UInt32.self, forKey: .displayID)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        mapping = try container.decodeIfPresent(Mapping.self, forKey: .mapping) ?? mapping
        signalLoss = try container.decodeIfPresent(SignalLoss.self, forKey: .signalLoss) ?? signalLoss
        signalLossTimeout = try container.decodeIfPresent(Double.self, forKey: .signalLossTimeout) ?? signalLossTimeout
        locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? locked
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.format, forKey: .format)
        try container.encode(Self.version, forKey: .version)
        try container.encode(universe, forKey: .universe)
        try container.encode(fixture, forKey: .fixture)
        try container.encode(source, forKey: .source)
        try container.encode(manualGradient, forKey: .manualGradient)
        try container.encode(manualTop, forKey: .manualTop)
        try container.encode(manualBottom, forKey: .manualBottom)
        try container.encodeIfPresent(displayID, forKey: .displayID)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encode(mapping, forKey: .mapping)
        try container.encode(signalLoss, forKey: .signalLoss)
        try container.encode(signalLossTimeout, forKey: .signalLossTimeout)
        try container.encode(locked, forKey: .locked)
    }
}

/// Reading and writing the settings file.
public enum SettingsFile {
    /// ~/Library/Application Support/Cuemodo Cyc/settings.json
    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(CycInfo.name, isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    public static func load(from url: URL) throws -> CycSettings {
        try JSONDecoder().decode(CycSettings.self, from: Data(contentsOf: url))
    }

    /// Writes to a temporary file first, then swaps it in ("atomic"), so a
    /// crash mid-save never leaves a half-written file.
    public static func save(_ settings: CycSettings, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }
}
