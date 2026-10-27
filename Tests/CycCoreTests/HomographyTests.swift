import CycCore
import XCTest

final class HomographyTests: XCTestCase {
    /// One WUXGA projector's worth of canvas.
    private let rectangle = Quad(x: 0, y: 0, width: 1920, height: 1200)
    /// The same area as it might land on a wall: tilted and keystoned.
    private let keystoned = Quad(
        topLeft: PixelPoint(x: 100, y: 50),
        topRight: PixelPoint(x: 1800, y: 120),
        bottomRight: PixelPoint(x: 1700, y: 1100),
        bottomLeft: PixelPoint(x: 200, y: 1180))

    private func assertClose(_ a: PixelPoint, _ b: PixelPoint, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.x, b.x, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(a.y, b.y, accuracy: 1e-6, file: file, line: line)
    }

    func testSameQuadGivesIdentity() throws {
        let homography = try XCTUnwrap(Homography(from: keystoned, to: keystoned))
        let point = PixelPoint(x: 640, y: 480)
        assertClose(homography.apply(to: point), point)
    }

    func testCornersLandExactly() throws {
        let homography = try XCTUnwrap(Homography(from: rectangle, to: keystoned))
        for (source, destination) in zip(rectangle.corners, keystoned.corners) {
            assertClose(homography.apply(to: source), destination)
        }
    }

    func testRectangleToRectangleIsAScaleAndShift() throws {
        let destination = Quad(x: 1920, y: 0, width: 960, height: 600)
        let homography = try XCTUnwrap(Homography(from: rectangle, to: destination))
        assertClose(homography.apply(to: PixelPoint(x: 960, y: 600)), PixelPoint(x: 2400, y: 300))
    }

    /// With perspective the middle of the source does not land on the average of
    /// the destination corners, but where the destination's diagonals cross.
    func testCenterFollowsPerspective() throws {
        let homography = try XCTUnwrap(Homography(from: rectangle, to: keystoned))
        assertClose(homography.apply(to: PixelPoint(x: 960, y: 600)),
                    PixelPoint(x: 1007.10900474, y: 645.29028436))
    }

    func testInvertedMapsBack() throws {
        let homography = try XCTUnwrap(Homography(from: rectangle, to: keystoned))
        let back = try XCTUnwrap(homography.inverted)
        let point = PixelPoint(x: 333, y: 777)
        assertClose(back.apply(to: homography.apply(to: point)), point)
    }

    func testDegenerateQuadsHaveNoMapping() {
        let squashed = Quad(x: 0, y: 0, width: 1920, height: 0)
        XCTAssertNil(Homography(from: rectangle, to: squashed))
        XCTAssertNil(Homography(from: squashed, to: rectangle))
    }

    func testConvexCheck() {
        XCTAssertTrue(rectangle.isConvex)
        XCTAssertTrue(keystoned.isConvex)
        let bowTie = Quad(
            topLeft: PixelPoint(x: 0, y: 0),
            topRight: PixelPoint(x: 100, y: 0),
            bottomRight: PixelPoint(x: 0, y: 100),
            bottomLeft: PixelPoint(x: 100, y: 100))
        XCTAssertFalse(bowTie.isConvex)
        let dented = Quad(
            topLeft: PixelPoint(x: 0, y: 0),
            topRight: PixelPoint(x: 100, y: 0),
            bottomRight: PixelPoint(x: 30, y: 30),
            bottomLeft: PixelPoint(x: 0, y: 100))
        XCTAssertFalse(dented.isConvex)
    }

    func testQuadSavesAsJSON() throws {
        let data = try JSONEncoder().encode(keystoned)
        XCTAssertEqual(try JSONDecoder().decode(Quad.self, from: data), keystoned)
    }
}
