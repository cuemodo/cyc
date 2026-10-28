/// What the output does when Art-Net stops arriving (a cable pulled, the desk
/// or the DMX node rebooting): keep the last look, or fade it to black.
public enum SignalLoss: String, CaseIterable, Identifiable, Codable, Sendable {
    case hold
    case fadeToBlack

    public var id: Self { self }

    public var name: String {
        switch self {
        case .hold: "Hold last look"
        case .fadeToBlack: "Fade to black"
        }
    }

    /// How long the fade to black takes once the signal counts as lost.
    public static let fadeDuration = 2.0

    /// How much of the look to show, from 1 (all of it) to 0 (black),
    /// `silence` seconds after the last packet (nil: no packet yet).
    ///
    /// With `fadeToBlack` the signal counts as lost after `timeout` seconds,
    /// then the look fades out over `fadeDuration`. The next packet brings it
    /// straight back.
    public func level(silence: Double?, timeout: Double) -> Double {
        guard self == .fadeToBlack else { return 1 }
        guard let silence else { return 0 }
        let fading = silence - timeout
        guard fading > 0 else { return 1 }
        return max(0, 1 - fading / Self.fadeDuration)
    }
}
