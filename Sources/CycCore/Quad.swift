/// A position in pixels. x grows to the right, y grows downwards, and (0, 0) is
/// the top-left corner, as on screen.
///
/// (Named `PixelPoint` because macOS already has an old `Point` type.)
public struct PixelPoint: Equatable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A four-cornered shape, corners listed clockwise on screen: top-left,
/// top-right, bottom-right, bottom-left. The corners can be anywhere, so a quad
/// can be a rectangle, a trapezoid or any other four-sided shape.
public struct Quad: Equatable, Codable, Sendable {
    public var topLeft: PixelPoint
    public var topRight: PixelPoint
    public var bottomRight: PixelPoint
    public var bottomLeft: PixelPoint

    public init(topLeft: PixelPoint, topRight: PixelPoint, bottomRight: PixelPoint, bottomLeft: PixelPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    /// An upright rectangle.
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(
            topLeft: PixelPoint(x: x, y: y),
            topRight: PixelPoint(x: x + width, y: y),
            bottomRight: PixelPoint(x: x + width, y: y + height),
            bottomLeft: PixelPoint(x: x, y: y + height))
    }

    public var corners: [PixelPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    /// True when the quad has no dent and its edges do not cross (no "bow tie").
    /// Only such quads map sensibly; the mapping editor should refuse the others.
    ///
    /// Walking around the corners, a convex quad turns the same way at every
    /// corner. The turn direction is the sign of a cross product.
    public var isConvex: Bool {
        let points = corners
        var turns: [Double] = []
        for index in 0..<4 {
            let a = points[index]
            let b = points[(index + 1) % 4]
            let c = points[(index + 2) % 4]
            turns.append((b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x))
        }
        return turns.allSatisfy { $0 > 0 } || turns.allSatisfy { $0 < 0 }
    }
}
