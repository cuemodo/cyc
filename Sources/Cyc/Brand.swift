import SwiftUI

/// Cuemodo's look, matching cuemodo.io: amber for the name and accents, the
/// system font, on the standard macOS dark window background.
enum Brand {
    static let amber = Color(hex: 0xffb347)
    static let label = Color(hex: 0xa09ab0)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xff) / 255,
                  green: Double(hex >> 8 & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255)
    }
}

extension View {
    /// Standard dark window, amber accents.
    func cuemodoWindow() -> some View {
        self
            .preferredColorScheme(.dark)
            .tint(Brand.amber)
    }

    /// A section title in the site's small-caps label style ("COMING SOON").
    func sectionTitle() -> some View {
        self
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(2.5)
            .foregroundStyle(Brand.label)
    }

    /// The app name, like the site's amber heading.
    func brandTitle() -> some View {
        self
            .font(.title.bold())
            .tracking(-0.5)
            .foregroundStyle(Brand.amber)
    }
}
