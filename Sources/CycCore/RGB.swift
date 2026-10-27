/// A color as three numbers from 0.0 (off) to 1.0 (full): red, green, blue.
///
/// This is how colors travel inside the app. DMX bytes (0 to 255) are
/// converted at the edge, when packets come in. Values outside 0...1 are
/// clamped, so a bad input can never ask the GPU for "more than full".
public struct RGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    public static let black = RGB(red: 0, green: 0, blue: 0)
    public static let white = RGB(red: 1, green: 1, blue: 1)

    /// True when every component differs by less than half an 8-bit step
    /// (1/510), i.e. the two colors would look identical on the output.
    public func isClose(to other: RGB) -> Bool {
        let tolerance = 1.0 / 510
        return abs(red - other.red) < tolerance
            && abs(green - other.green) < tolerance
            && abs(blue - other.blue) < tolerance
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
