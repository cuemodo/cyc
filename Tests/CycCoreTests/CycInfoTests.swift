import CycCore
import XCTest

final class CycInfoTests: XCTestCase {
    func testNameUsesBrandSpelling() {
        XCTAssertEqual(CycInfo.name, "Cyc")
    }

    func testVersionIsThreeNumbers() {
        let parts = CycInfo.version.split(separator: ".")
        XCTAssertEqual(parts.count, 3)
        XCTAssertTrue(parts.allSatisfy { Int($0) != nil })
    }
}
