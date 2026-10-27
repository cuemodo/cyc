import CycCore
import XCTest

final class RGBTests: XCTestCase {
    func testKeepsValuesInRange() {
        let color = RGB(red: 0.25, green: 0.5, blue: 1)
        XCTAssertEqual(color.red, 0.25)
        XCTAssertEqual(color.green, 0.5)
        XCTAssertEqual(color.blue, 1)
    }

    func testClampsValuesOutOfRange() {
        XCTAssertEqual(RGB(red: -0.5, green: 1.5, blue: 2), RGB(red: 0, green: 1, blue: 1))
    }

    func testNamedColors() {
        XCTAssertEqual(RGB.black, RGB(red: 0, green: 0, blue: 0))
        XCTAssertEqual(RGB.white, RGB(red: 1, green: 1, blue: 1))
    }
}
