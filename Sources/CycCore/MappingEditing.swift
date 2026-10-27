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

/// Names one destination corner in a mapping: which quad, which corner.
public struct CornerID: Hashable, Sendable {
    public var quad: Int
    public var corner: Corner

    public init(quad: Int, corner: Corner) {
        self.quad = quad
        self.corner = corner
    }
}

/// What the mapping editor does to destination corners (where quads land on
/// the output). Kept here, away from the UI, so it can be tested.
extension Mapping {
    /// One quad showing the whole canvas on the whole output: the starting
    /// point when editing a mapping that has no quads yet.
    public static func filling(width: Double, height: Double) -> Mapping {
        let full = Quad(x: 0, y: 0, width: width, height: height)
        return Mapping(canvasWidth: width, canvasHeight: height,
                       quads: [MappedQuad(source: full, destination: full)])
    }

    public func corner(_ id: CornerID) -> PixelPoint? {
        quads.indices.contains(id.quad) ? quads[id.quad].destination[corner: id.corner] : nil
    }

    /// Every destination corner, quad by quad, clockwise from top-left.
    public var allCorners: [CornerID] {
        quads.indices.flatMap { quad in Corner.allCases.map { CornerID(quad: quad, corner: $0) } }
    }

    /// The destination corner closest to `point`, if one is within `maxDistance` pixels.
    public func nearestCorner(to point: PixelPoint, within maxDistance: Double) -> CornerID? {
        func distance(_ id: CornerID) -> Double {
            guard let corner = corner(id) else { return .infinity }
            return ((corner.x - point.x) * (corner.x - point.x) + (corner.y - point.y) * (corner.y - point.y)).squareRoot()
        }
        guard let nearest = allCorners.min(by: { distance($0) < distance($1) }),
              distance(nearest) <= maxDistance else { return nil }
        return nearest
    }

    /// The mapping with one destination corner moved, or nil when the move
    /// would dent the quad or cross its edges (the corner then stays put).
    public func moving(_ id: CornerID, to point: PixelPoint) -> Mapping? {
        guard quads.indices.contains(id.quad) else { return nil }
        var moved = self
        moved.quads[id.quad].destination[corner: id.corner] = point
        return moved.quads[id.quad].destination.isConvex ? moved : nil
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
