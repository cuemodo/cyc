import CycCore
import XCTest

final class FixtureTests: XCTestCase {
    /// A universe with the given levels starting at `address`, everything else 0.
    private func universe(at address: Int, _ values: [UInt8]) -> [UInt8] {
        var levels = [UInt8](repeating: 0, count: 512)
        for (offset, value) in values.enumerated() {
            levels[address - 1 + offset] = value
        }
        return levels
    }

    func testChannelCounts() {
        XCTAssertEqual(FixtureMode.rgb.channelCount, 3)
        XCTAssertEqual(FixtureMode.dimRGB.channelCount, 4)
        XCTAssertEqual(FixtureMode.gradient.channelCount, 6)
        XCTAssertEqual(FixtureMode.dimGradient.channelCount, 8)
        XCTAssertEqual(FixtureMode.dimGradient.channelNames,
                       ["top dimmer", "top red", "top green", "top blue",
                        "bottom dimmer", "bottom red", "bottom green", "bottom blue"])
    }

    func testRGBReadsThreeChannelsFromItsAddress() {
        let fixture = Fixture(address: 10, mode: .rgb)
        let look = fixture.look(from: universe(at: 10, [255, 0, 51]))
        XCTAssertEqual(look, FixtureLook(solid: RGB(red: 1, green: 0, blue: 0.2)))
    }

    func testDimmerScalesTheColor() {
        let fixture = Fixture(address: 1, mode: .dimRGB)
        let look = fixture.look(from: universe(at: 1, [0, 255, 255, 255]))
        XCTAssertEqual(look, .black)

        let full = fixture.look(from: universe(at: 1, [255, 255, 0, 0]))
        XCTAssertEqual(full, FixtureLook(solid: RGB(red: 1, green: 0, blue: 0)))
    }

    func testGradientReadsTopThenBottom() {
        let fixture = Fixture(address: 101, mode: .gradient)
        let look = fixture.look(from: universe(at: 101, [0, 0, 255, 255, 0, 0]))
        XCTAssertEqual(look.top, RGB(red: 0, green: 0, blue: 1))
        XCTAssertEqual(look.bottom, RGB(red: 1, green: 0, blue: 0))
    }

    func testDimGradientHasOneDimmerPerColor() {
        let fixture = Fixture(address: 1, mode: .dimGradient)
        // Top: dimmer 0, white. Bottom: dimmer full, green.
        let look = fixture.look(from: universe(at: 1, [0, 255, 255, 255, 255, 0, 255, 0]))
        XCTAssertEqual(look.top, .black)
        XCTAssertEqual(look.bottom, RGB(red: 0, green: 1, blue: 0))
    }

    func testFitsInUniverse() {
        XCTAssertTrue(Fixture(address: 510, mode: .rgb).fitsInUniverse)
        XCTAssertFalse(Fixture(address: 511, mode: .rgb).fitsInUniverse)
        XCTAssertFalse(Fixture(address: 0, mode: .rgb).fitsInUniverse)
    }

    func testChannelsPastTheUniverseReadZero() {
        let fixture = Fixture(address: 511, mode: .rgb)
        let look = fixture.look(from: universe(at: 511, [255, 255]))
        XCTAssertEqual(look, FixtureLook(solid: RGB(red: 1, green: 1, blue: 0)))
    }
}
