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

final class MappingQuadMoveAndHideTests: XCTestCase {
    private let mapping = Mapping(quads: [
        MappedQuad(source: Quad(x: 0, y: 0, width: 100, height: 100),
                   destination: Quad(x: 0, y: 0, width: 100, height: 100)),
        MappedQuad(source: Quad(x: 50, y: 50, width: 100, height: 100),
                   destination: Quad(x: 50, y: 50, width: 100, height: 100)),
    ])

    func testMovingAWholeQuadKeepsItsShape() {
        let moved = mapping.movingQuad(0, dx: -30, dy: 20, on: .source)
        XCTAssertEqual(moved.quads[0].source, Quad(x: -30, y: 20, width: 100, height: 100))
        XCTAssertEqual(moved.quads[0].destination, mapping.quads[0].destination)
        XCTAssertEqual(moved.quads[1], mapping.quads[1])
        XCTAssertEqual(mapping.movingQuad(5, dx: 1, dy: 1), mapping)
    }

    func testCornersMayLeaveTheOutput() throws {
        let id = CornerID(quad: 0, corner: .topLeft)
        let moved = try XCTUnwrap(mapping.moving(id, to: PixelPoint(x: -40, y: -25)))
        XCTAssertEqual(moved.corner(id), PixelPoint(x: -40, y: -25))
    }

    func testHiddenQuadsAreNotDrawnOrPicked() {
        let hidden = mapping.settingHidden(true, quad: 1)
        XCTAssertTrue(hidden.quads[1].isHidden)
        XCTAssertEqual(hidden.drawableQuads(outputWidth: 200, outputHeight: 200).quads.count, 1)
        // Quad 1 is on top where they overlap, but hidden: quad 0 is picked.
        XCTAssertEqual(hidden.quadIndex(at: PixelPoint(x: 75, y: 75)), 0)
        XCTAssertNil(hidden.nearestCorner(to: PixelPoint(x: 150, y: 150), within: 5))
        XCTAssertEqual(hidden.allCorners.count, 4)
        XCTAssertEqual(hidden.cornerAfter(CornerID(quad: 0, corner: .bottomLeft)),
                       CornerID(quad: 0, corner: .topLeft))

        let allHidden = hidden.settingHidden(true, quad: 0)
        XCTAssertTrue(allHidden.drawableQuads(outputWidth: 200, outputHeight: 200).quads.isEmpty)
    }

    func testHiddenIsOptionalInJSON() throws {
        let json = """
        {"source": {"topLeft": {"x": 0, "y": 0}, "topRight": {"x": 1, "y": 0},
                    "bottomRight": {"x": 1, "y": 1}, "bottomLeft": {"x": 0, "y": 1}},
         "destination": {"topLeft": {"x": 0, "y": 0}, "topRight": {"x": 1, "y": 0},
                         "bottomRight": {"x": 1, "y": 1}, "bottomLeft": {"x": 0, "y": 1}}}
        """
        let quad = try JSONDecoder().decode(MappedQuad.self, from: Data(json.utf8))
        XCTAssertFalse(quad.isHidden)

        let hidden = MappedQuad(source: quad.source, destination: quad.destination, isHidden: true)
        let roundTrip = try JSONDecoder().decode(MappedQuad.self, from: JSONEncoder().encode(hidden))
        XCTAssertTrue(roundTrip.isHidden)
    }

    func testHandleUnderThePointer() {
        let tiny = Mapping(quads: [MappedQuad(source: Quad(x: 0, y: 0, width: 10, height: 10),
                                              destination: Quad(x: 0, y: 0, width: 10, height: 10))])
        // Inside a tiny quad, every point is near a corner: the center still wins near the middle.
        XCTAssertEqual(tiny.handle(at: PixelPoint(x: 5, y: 6), cornerReach: 10, centerReach: 6), .quad(0))
        XCTAssertEqual(tiny.handle(at: PixelPoint(x: 9, y: 1), cornerReach: 10, centerReach: 6),
                       .corner(CornerID(quad: 0, corner: .topRight)))
        XCTAssertNil(tiny.handle(at: PixelPoint(x: 50, y: 50), cornerReach: 10, centerReach: 6))

        // Far from any handle, a press inside a quad grabs it; hidden quads are skipped.
        XCTAssertEqual(mapping.handle(at: PixelPoint(x: 30, y: 70), cornerReach: 5, centerReach: 5), .quad(0))
        XCTAssertEqual(mapping.handle(at: PixelPoint(x: 75, y: 75), cornerReach: 5, centerReach: 5), .quad(1))
        let hidden = mapping.settingHidden(true, quad: 1)
        XCTAssertEqual(hidden.handle(at: PixelPoint(x: 75, y: 75), cornerReach: 5, centerReach: 5), .quad(0))
    }
}
