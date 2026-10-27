/// One quad of the mapping: a patch of the canvas (`source`) and where that
/// patch lands on the output (`destination`), both in pixels.
public struct MappedQuad: Equatable, Codable, Sendable {
    public var source: Quad
    public var destination: Quad

    public init(source: Quad, destination: Quad) {
        self.source = source
        self.destination = destination
    }
}

/// A quad ready to draw: its corners on the output, and the homography that
/// takes an output pixel back to its spot on the canvas.
public struct DrawableQuad: Sendable {
    public let destination: Quad
    public let outputToCanvas: Homography
}

/// How the canvas lands on the output: a few mapped quads, black everywhere else.
///
/// The canvas is the imaginary picture the fixture paints (the color or the
/// top-to-bottom gradient). With no quads, the whole canvas simply fills the
/// whole output.
public struct Mapping: Equatable, Sendable {
    public var canvasWidth: Double
    public var canvasHeight: Double
    public var quads: [MappedQuad]

    public init(canvasWidth: Double = 3840, canvasHeight: Double = 1200, quads: [MappedQuad] = []) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.quads = quads
    }

    /// Quads that can be drawn on an output of the given size, and the canvas
    /// height the gradient runs over. Quads with a dent, crossed edges or
    /// squashed corners are skipped, because they have no sensible mapping.
    public func drawableQuads(outputWidth: Double, outputHeight: Double) -> (quads: [DrawableQuad], canvasHeight: Double) {
        guard !quads.isEmpty else {
            let full = Quad(x: 0, y: 0, width: outputWidth, height: outputHeight)
            return ([DrawableQuad(destination: full, outputToCanvas: .identity)], outputHeight)
        }
        let drawable = quads.compactMap { quad -> DrawableQuad? in
            guard quad.source.isConvex, quad.destination.isConvex,
                  let homography = Homography(from: quad.destination, to: quad.source) else { return nil }
            return DrawableQuad(destination: quad.destination, outputToCanvas: homography)
        }
        return (drawable, canvasHeight)
    }

    /// How many quads `drawableQuads` skips.
    public var invalidQuadCount: Int {
        quads.filter { !$0.source.isConvex || !$0.destination.isConvex
            || Homography(from: $0.destination, to: $0.source) == nil }.count
    }
}

extension Mapping: Codable {
    private enum CodingKeys: String, CodingKey {
        case canvasWidth, canvasHeight, quads
    }

    /// Missing values keep their defaults, so a hand-written mapping can be short.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        canvasWidth = try container.decodeIfPresent(Double.self, forKey: .canvasWidth) ?? canvasWidth
        canvasHeight = try container.decodeIfPresent(Double.self, forKey: .canvasHeight) ?? canvasHeight
        quads = try container.decodeIfPresent([MappedQuad].self, forKey: .quads) ?? quads
    }
}
