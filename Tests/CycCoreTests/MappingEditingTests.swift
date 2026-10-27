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

    func testEditingTheSourceSide() throws {
        let id = CornerID(quad: 1, corner: .bottomLeft)
        let moved = try XCTUnwrap(twoProjectors.moving(id, to: PixelPoint(x: 2000, y: 1100), on: .source))
        XCTAssertEqual(moved.corner(id, on: .source), PixelPoint(x: 2000, y: 1100))
        XCTAssertEqual(moved.quads[1].destination, twoProjectors.quads[1].destination)
        XCTAssertEqual(moved.nearestCorner(to: PixelPoint(x: 1995, y: 1095), within: 20, on: .source), id)
    }

    func testPointInQuad() {
        let quad = Quad(x: 0, y: 0, width: 100, height: 50)
        XCTAssertTrue(quad.contains(PixelPoint(x: 50, y: 25)))
        XCTAssertTrue(quad.contains(PixelPoint(x: 0, y: 0)))
        XCTAssertFalse(quad.contains(PixelPoint(x: 150, y: 25)))
        XCTAssertEqual(twoProjectors.quadIndex(at: PixelPoint(x: 3000, y: 600)), 1)
        XCTAssertNil(twoProjectors.quadIndex(at: PixelPoint(x: 5000, y: 600)))
    }

    func testAddAndRemoveQuads() {
        let four = twoProjectors
            .addingQuad(outputWidth: 3840, outputHeight: 1200)
            .addingQuad(outputWidth: 3840, outputHeight: 1200)
        XCTAssertEqual(four.quads.count, 4)
        XCTAssertEqual(four.quads[3].source, Quad(x: 960, y: 300, width: 1920, height: 600))
        XCTAssertEqual(four.quads[3].destination, Quad(x: 960, y: 300, width: 1920, height: 600))

        let three = four.removingQuad(at: 0)
        XCTAssertEqual(three.quads.count, 3)
        XCTAssertEqual(three.quads[0], twoProjectors.quads[1])
        XCTAssertEqual(three.removingQuad(at: 9), three)
    }
}
