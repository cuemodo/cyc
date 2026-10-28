import CycCore
import XCTest

final class SignalLossTests: XCTestCase {
    func testHoldKeepsTheLookForever() {
        XCTAssertEqual(SignalLoss.hold.level(silence: 3600, timeout: 5), 1)
        XCTAssertEqual(SignalLoss.hold.level(silence: nil, timeout: 5), 1)
    }

    func testFadeWaitsForTheTimeout() {
        XCTAssertEqual(SignalLoss.fadeToBlack.level(silence: 0, timeout: 5), 1)
        XCTAssertEqual(SignalLoss.fadeToBlack.level(silence: 5, timeout: 5), 1)
    }

    func testFadeThenStaysBlack() {
        XCTAssertEqual(SignalLoss.fadeToBlack.level(silence: 6, timeout: 5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(SignalLoss.fadeToBlack.level(silence: 7, timeout: 5), 0)
        XCTAssertEqual(SignalLoss.fadeToBlack.level(silence: 60, timeout: 5), 0)
    }

    func testNoPacketYetIsBlack() {
        XCTAssertEqual(SignalLoss.fadeToBlack.level(silence: nil, timeout: 5), 0)
    }

    func testLookScalesBothColors() {
        let look = FixtureLook(top: RGB(red: 1, green: 0.5, blue: 0), bottom: .white)
        XCTAssertEqual(look.scaled(by: 0.5),
                       FixtureLook(top: RGB(red: 0.5, green: 0.25, blue: 0), bottom: RGB(red: 0.5, green: 0.5, blue: 0.5)))
        XCTAssertEqual(look.scaled(by: 1), look)
    }
}
