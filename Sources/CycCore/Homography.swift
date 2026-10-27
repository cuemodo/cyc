import simd

/// The 3x3 matrix that maps one four-cornered shape onto another, perspective
/// included: like pinning a rubber sheet at four corners and stretching it.
/// Straight lines stay straight; parallel lines may not stay parallel.
///
/// A point (x, y) becomes (x', y') like this:
///
///     [X, Y, W] = matrix * [x, y, 1]
///     x' = X / W,  y' = Y / W
///
/// The division by W is what makes perspective possible: far parts of a shape
/// shrink. Without perspective W is always 1.
public struct Homography: Sendable {
    public let matrix: simd_double3x3

    public init(matrix: simd_double3x3) {
        self.matrix = matrix
    }

    public static let identity = Homography(matrix: matrix_identity_double3x3)

    /// The homography that takes each corner of `source` to the same corner of
    /// `destination`. Nil when a quad is degenerate (corners on one line or on
    /// top of each other), because no mapping exists then.
    public init?(from source: Quad, to destination: Quad) {
        // Go through the unit square: source -> square -> destination.
        guard let squareToSource = Self.squareToQuad(source),
              let squareToDestination = Self.squareToQuad(destination),
              let sourceToSquare = Self.invert(squareToSource) else { return nil }
        self.init(matrix: squareToDestination * sourceToSquare)
    }

    public func apply(to point: PixelPoint) -> PixelPoint {
        let mapped = matrix * SIMD3(point.x, point.y, 1)
        return PixelPoint(x: mapped.x / mapped.z, y: mapped.y / mapped.z)
    }

    /// The mapping the other way round, or nil if there is none.
    public var inverted: Homography? {
        Self.invert(matrix).map(Homography.init(matrix:))
    }

    private static func invert(_ matrix: simd_double3x3) -> simd_double3x3? {
        let determinant = matrix.determinant
        guard determinant.isFinite, abs(determinant) > 1e-12 else { return nil }
        return matrix.inverse
    }

    /// Maps the unit square's corners (0,0), (1,0), (1,1), (0,1) onto the
    /// quad's top-left, top-right, bottom-right and bottom-left corners.
    ///
    /// This is the classic closed-form solution (Paul Heckbert, 1989): `g` and
    /// `h` hold the perspective part and are 0 when the quad is a parallelogram.
    static func squareToQuad(_ quad: Quad) -> simd_double3x3? {
        let (x0, y0) = (quad.topLeft.x, quad.topLeft.y)
        let (x1, y1) = (quad.topRight.x, quad.topRight.y)
        let (x2, y2) = (quad.bottomRight.x, quad.bottomRight.y)
        let (x3, y3) = (quad.bottomLeft.x, quad.bottomLeft.y)

        let dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3
        let dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3
        let denominator = dx1 * dy2 - dx2 * dy1
        guard abs(denominator) > 1e-12 else { return nil }

        let g = (dx3 * dy2 - dx2 * dy3) / denominator
        let h = (dx1 * dy3 - dx3 * dy1) / denominator
        let matrix = simd_double3x3(rows: [
            SIMD3(x1 - x0 + g * x1, x3 - x0 + h * x3, x0),
            SIMD3(y1 - y0 + g * y1, y3 - y0 + h * y3, y0),
            SIMD3(g, h, 1),
        ])
        return invert(matrix) == nil ? nil : matrix
    }
}
