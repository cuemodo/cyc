import CycCore
import XCTest

final class CycSettingsTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("CycSettingsTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func decode(_ json: String) throws -> CycSettings {
        try JSONDecoder().decode(CycSettings.self, from: Data(json.utf8))
    }

    func testSaveThenLoadGivesTheSameSettings() throws {
        var settings = CycSettings()
        settings.universe = 3
        settings.fixture = Fixture(address: 101, mode: .dimGradient)
        settings.source = .testColor
        settings.testColor = RGB(red: 0, green: 0.5, blue: 1)
        settings.displayID = 42
        settings.displayName = "Matrox DualHead2Go"

        let url = folder.appendingPathComponent("nested/settings.json")
        try SettingsFile.save(settings, to: url)
        XCTAssertEqual(try SettingsFile.load(from: url), settings)
    }

    func testFileStartsWithFormatAndVersion() throws {
        let data = try JSONEncoder().encode(CycSettings())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["format"] as? String, "cuemodo-cyc-settings")
        XCTAssertEqual(object["version"] as? Int, 1)
    }

    func testMissingValuesKeepDefaults() throws {
        let settings = try decode(#"{"format": "cuemodo-cyc-settings", "version": 1, "universe": 5}"#)
        XCTAssertEqual(settings.universe, 5)
        XCTAssertEqual(settings.fixture, Fixture())
        XCTAssertNil(settings.displayID)
    }

    func testRejectsOtherFiles() {
        XCTAssertThrowsError(try decode(#"{"format": "cuemodo-show", "version": 1}"#)) { error in
            XCTAssertEqual(error as? SettingsError, .notCycSettings)
        }
    }

    func testRejectsNewerVersions() {
        XCTAssertThrowsError(try decode(#"{"format": "cuemodo-cyc-settings", "version": 99}"#)) { error in
            XCTAssertEqual(error as? SettingsError, .newerVersion(99))
        }
    }

    func testColorsFromAFileAreClamped() throws {
        let settings = try decode(#"""
            {"format": "cuemodo-cyc-settings", "version": 1,
             "testColor": {"red": 2, "green": -1, "blue": 0.5}}
            """#)
        XCTAssertEqual(settings.testColor, RGB(red: 1, green: 0, blue: 0.5))
    }
}
