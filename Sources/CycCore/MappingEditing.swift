/// One of a quad's four corners.
public enum Corner: Int, CaseIterable, Sendable {
    case topLeft, topRight, bottomRight, bottomLeft
}

extension Quad {
    // `corner corner:` makes the label required at the call site: quad[corner: .topLeft].
    public subscript(corner corner: Corner) -> PixelPoint {
        get {
            switch corner {
            case .topLeft: topLeft
            case .topRight: topRight
            case .bottomRight: bottomRight
            case .bottomLeft: bottomLeft
            }
        }
        set {
            switch corner {
            case .topLeft: topLeft = newValue
            case .topRight: topRight = newValue
            case .bottomRight: bottomRight = newValue
            case .bottomLeft: bottomLeft = newValue
            }
        }
    }
}

extension Quad {
    /// True when `point` lies inside the quad (or on its edge). Meant for
    /// convex quads: the point must be on the same side of all four edges.
    public func contains(_ point: PixelPoint) -> Bool {
        let points = corners
        var sides: [Double] = []
        for index in 0..<4 {
            let a = points[index]
            let b = points[(index + 1) % 4]
            sides.append((b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x))
        }
        return sides.allSatisfy { $0 >= 0 } || sides.allSatisfy { $0 <= 0 }
    }
}

/// The two sides of a mapped quad: its patch of the canvas (input), or where
/// that patch lands on the output.
public enum MappingSide: Sendable {
    case source
    case destination
}

extension MappedQuad {
    public subscript(side side: MappingSide) -> Quad {
        get { side == .source ? source : destination }
        set {
            switch side {
            case .source: source = newValue
            case .destination: destination = newValue
            }
        }
    }
}

/// Names one corner of a quad in a mapping: which quad, which corner.
public struct CornerID: Hashable, Sendable {
    public var quad: Int
    public var corner: Corner

    public init(quad: Int, corner: Corner) {
        self.quad = quad
        self.corner = corner
    }
}

/// What the mapping editors do to quads and corners. `side` says whether a
/// corner is on the canvas (`.source`) or on the output (`.destination`, the
/// default). Kept here, away from the UI, so it can be tested.
extension Mapping {
    /// One quad showing the whole canvas on the whole output: the starting
    /// point when editing a mapping that has no quads yet.
    public static func filling(width: Double, height: Double) -> Mapping {
        let full = Quad(x: 0, y: 0, width: width, height: height)
        return Mapping(canvasWidth: width, canvasHeight: height,
                       quads: [MappedQuad(source: full, destination: full)])
    }

    public func corner(_ id: CornerID, on side: MappingSide = .destination) -> PixelPoint? {
        quads.indices.contains(id.quad) ? quads[id.quad][side: side][corner: id.corner] : nil
    }

    /// Every corner, quad by quad, clockwise from top-left.
    public var allCorners: [CornerID] {
        quads.indices.flatMap { quad in Corner.allCases.map { CornerID(quad: quad, corner: $0) } }
    }

    /// The corner closest to `point`, if one is within `maxDistance` pixels.
    public func nearestCorner(to point: PixelPoint, within maxDistance: Double,
                              on side: MappingSide = .destination) -> CornerID? {
        func distance(_ id: CornerID) -> Double {
            guard let corner = corner(id, on: side) else { return .infinity }
            return ((corner.x - point.x) * (corner.x - point.x) + (corner.y - point.y) * (corner.y - point.y)).squareRoot()
        }
        guard let nearest = allCorners.min(by: { distance($0) < distance($1) }),
              distance(nearest) <= maxDistance else { return nil }
        return nearest
    }

    /// The mapping with one corner moved, or nil when the move would dent the
    /// quad or cross its edges (the corner then stays put).
    public func moving(_ id: CornerID, to point: PixelPoint, on side: MappingSide = .destination) -> Mapping? {
        guard quads.indices.contains(id.quad) else { return nil }
        var moved = self
        moved.quads[id.quad][side: side][corner: id.corner] = point
        return moved.quads[id.quad][side: side].isConvex ? moved : nil
    }

    /// The last (topmost) quad containing `point`, if any.
    public func quadIndex(at point: PixelPoint, on side: MappingSide = .destination) -> Int? {
        quads.indices.last { quads[$0][side: side].contains(point) }
    }

    /// The mapping with one more quad: a rectangle half the size of the canvas
    /// in its middle, landing in the middle of the output at half its size.
    public func addingQuad(outputWidth: Double, outputHeight: Double) -> Mapping {
        var mapping = self
        mapping.quads.append(MappedQuad(
            source: Quad(x: canvasWidth / 4, y: canvasHeight / 4, width: canvasWidth / 2, height: canvasHeight / 2),
            destination: Quad(x: outputWidth / 4, y: outputHeight / 4, width: outputWidth / 2, height: outputHeight / 2)))
        return mapping
    }

    public func removingQuad(at index: Int) -> Mapping {
        var mapping = self
        if mapping.quads.indices.contains(index) {
            mapping.quads.remove(at: index)
        }
        return mapping
    }

    /// The corner after `id` (or before it, going `backwards`), wrapping from
    /// the last quad to the first. The first corner when nothing is selected.
    public func cornerAfter(_ id: CornerID?, backwards: Bool = false) -> CornerID? {
        let corners = allCorners
        guard !corners.isEmpty else { return nil }
        guard let id, let index = corners.firstIndex(of: id) else { return corners.first }
        let step = backwards ? corners.count - 1 : 1
        return corners[(index + step) % corners.count]
    }
}
