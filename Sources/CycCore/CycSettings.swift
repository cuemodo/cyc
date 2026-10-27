import Foundation

/// What the output shows: the fixture driven by Art-Net, or a fixed test color.
public enum OutputSource: String, CaseIterable, Identifiable, Codable, Sendable {
    case artNet
    case testColor

    public var id: Self { self }

    public var name: String {
        switch self {
        case .artNet: "Art-Net"
        case .testColor: "Test color"
        }
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
    public var testColor = RGB(red: 1, green: 0.7, blue: 0.28)
    /// The output display. macOS display IDs can change after a restart or
    /// replug, so its name is kept as a fallback.
    public var displayID: UInt32?
    public var displayName: String?
    /// Where the canvas lands on the output. Empty means "fill the whole output".
    public var mapping = Mapping()

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
        case format, version, universe, fixture, source, testColor, displayID, displayName, mapping
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
        testColor = try container.decodeIfPresent(RGB.self, forKey: .testColor) ?? testColor
        displayID = try container.decodeIfPresent(UInt32.self, forKey: .displayID)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        mapping = try container.decodeIfPresent(Mapping.self, forKey: .mapping) ?? mapping
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.format, forKey: .format)
        try container.encode(Self.version, forKey: .version)
        try container.encode(universe, forKey: .universe)
        try container.encode(fixture, forKey: .fixture)
        try container.encode(source, forKey: .source)
        try container.encode(testColor, forKey: .testColor)
        try container.encodeIfPresent(displayID, forKey: .displayID)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encode(mapping, forKey: .mapping)
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
