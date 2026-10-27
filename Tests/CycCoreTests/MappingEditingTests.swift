import CycCore
import XCTest

final class MappingEditingTests: XCTestCase {
    private let twoProjectors = Mapping(quads: [
        MappedQuad(source: Quad(x: 0, y: 0, width: 1920, height: 1200),
                   destination: Quad(x: 0, y: 0, width: 1920, height: 1200)),
        MappedQuad(source: Quad(x: 1920, y: 0, width: 1920, height: 1200),
                   destination: Quad(x: 1920, y: 0, width: 1920, height: 1200)),
    ])

    func testCornerSubscript() {
        var quad = Quad(x: 0, y: 0, width: 10, height: 20)
        XCTAssertEqual(quad[corner: .bottomRight], PixelPoint(x: 10, y: 20))
        quad[corner: .topLeft] = PixelPoint(x: 1, y: 2)
        XCTAssertEqual(quad.topLeft, PixelPoint(x: 1, y: 2))
    }

    func testFillingCoversTheOutput() {
        let mapping = Mapping.filling(width: 3840, height: 1200)
        XCTAssertEqual(mapping.quads.count, 1)
        XCTAssertEqual(mapping.quads[0].destination, Quad(x: 0, y: 0, width: 3840, height: 1200))
        XCTAssertEqual(mapping.canvasWidth, 3840)
    }

    func testNearestCornerWithinReach() {
        let hit = twoProjectors.nearestCorner(to: PixelPoint(x: 1925, y: 5), within: 20)
        XCTAssertEqual(hit, CornerID(quad: 1, corner: .topLeft))
        XCTAssertNil(twoProjectors.nearestCorner(to: PixelPoint(x: 960, y: 600), within: 20))
    }

    func testMovingACorner() throws {
        let id = CornerID(quad: 0, corner: .topRight)
        let moved = try XCTUnwrap(twoProjectors.moving(id, to: PixelPoint(x: 1900, y: 15)))
        XCTAssertEqual(moved.corner(id), PixelPoint(x: 1900, y: 15))
        XCTAssertEqual(moved.quads[1], twoProjectors.quads[1])
    }

    func testRefusesMovesThatBreakTheQuad() {
        // Dragging the top-right corner past the bottom-left one crosses the edges.
        let id = CornerID(quad: 0, corner: .topRight)
        XCTAssertNil(twoProjectors.moving(id, to: PixelPoint(x: -100, y: 1300)))
    }

    func testCycleThroughCorners() {
        XCTAssertEqual(twoProjectors.cornerAfter(nil), CornerID(quad: 0, corner: .topLeft))
        XCTAssertEqual(twoProjectors.cornerAfter(CornerID(quad: 0, corner: .bottomLeft)),
                       CornerID(quad: 1, corner: .topLeft))
        XCTAssertEqual(twoProjectors.cornerAfter(CornerID(quad: 1, corner: .bottomLeft)),
                       CornerID(quad: 0, corner: .topLeft))
        XCTAssertEqual(twoProjectors.cornerAfter(CornerID(quad: 0, corner: .topLeft), backwards: true),
                       CornerID(quad: 1, corner: .bottomLeft))
        XCTAssertNil(Mapping().cornerAfter(nil))
    }
}
