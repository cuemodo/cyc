import CycCore
import XCTest

final class MappingTests: XCTestCase {
    private let leftHalf = Quad(x: 0, y: 0, width: 1920, height: 1200)

    func testNoQuadsFillsTheWholeOutput() {
        let (quads, canvasHeight) = Mapping().drawableQuads(outputWidth: 3840, outputHeight: 1200)
        XCTAssertEqual(quads.count, 1)
        XCTAssertEqual(quads[0].destination, Quad(x: 0, y: 0, width: 3840, height: 1200))
        XCTAssertEqual(canvasHeight, 1200)
    }

    func testOutputPixelsMapBackToTheCanvas() throws {
        let destination = Quad(
            topLeft: PixelPoint(x: 40, y: 30),
            topRight: PixelPoint(x: 1900, y: 0),
            bottomRight: PixelPoint(x: 1920, y: 1200),
            bottomLeft: PixelPoint(x: 0, y: 1170))
        let mapping = Mapping(quads: [MappedQuad(source: leftHalf, destination: destination)])
        let (quads, canvasHeight) = mapping.drawableQuads(outputWidth: 3840, outputHeight: 1200)
        let quad = try XCTUnwrap(quads.first)
        XCTAssertEqual(canvasHeight, 1200)
        for (output, canvas) in zip(destination.corners, leftHalf.corners) {
            let mapped = quad.outputToCanvas.apply(to: output)
            XCTAssertEqual(mapped.x, canvas.x, accuracy: 1e-6)
            XCTAssertEqual(mapped.y, canvas.y, accuracy: 1e-6)
        }
    }

    func testBadQuadsAreSkipped() {
        let bowTie = Quad(
            topLeft: PixelPoint(x: 0, y: 0),
            topRight: PixelPoint(x: 100, y: 0),
            bottomRight: PixelPoint(x: 0, y: 100),
            bottomLeft: PixelPoint(x: 100, y: 100))
        let mapping = Mapping(quads: [
            MappedQuad(source: leftHalf, destination: leftHalf),
            MappedQuad(source: leftHalf, destination: bowTie),
        ])
        XCTAssertEqual(mapping.drawableQuads(outputWidth: 3840, outputHeight: 1200).quads.count, 1)
        XCTAssertEqual(mapping.invalidQuadCount, 1)
    }

    func testShortHandWrittenMappingLoads() throws {
        let json = #"{"quads": []}"#
        let mapping = try JSONDecoder().decode(Mapping.self, from: Data(json.utf8))
        XCTAssertEqual(mapping, Mapping())
    }

    func testSettingsKeepTheMapping() throws {
        var settings = CycSettings()
        settings.mapping = Mapping(quads: [MappedQuad(source: leftHalf, destination: leftHalf)])
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(CycSettings.self, from: data), settings)
    }
}
