import AppKit
import CycCore
import SwiftUI

/// One display the projector output can go to.
struct Display: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    /// Real pixels, e.g. 3840 x 1200 for two WUXGA projectors behind a Matrox splitter.
    let pixelSize: CGSize

    var label: String {
        "\(name) (\(Int(pixelSize.width)) x \(Int(pixelSize.height)))"
    }
}

/// Opens and closes the output window, keeps the list of displays fresh, and
/// turns incoming DMX into the look on the projectors.
@MainActor
final class OutputController: ObservableObject {
    @Published private(set) var displays: [Display] = []
    @Published var selectedDisplayID: CGDirectDisplayID?
    @Published private(set) var isOpen = false
    @Published var source = OutputSource.artNet {
        didSet { updateLook() }
    }
    @Published var fixture = Fixture() {
        didSet { updateLook() }
    }
    @Published var testColor = RGB(red: 1, green: 0.7, blue: 0.28) {
        didSet { updateLook() }
    }

    private var dmxLevels = DMXInputController.blackout
    private var window: OutputWindow?
    private var renderer: Renderer?
    private var keepAwake: NSObjectProtocol?

    init(input: DMXInputController) {
        // Every packet for our universe updates the look straight away (not
        // throttled like the settings window), so fades on the desk stay smooth.
        input.onLevels = { [weak self] levels in
            self?.dmxLevels = levels
            self?.updateLook()
        }
        refreshDisplays()
        // Plugging or unplugging a projector changes the list.
        _ = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshDisplays() }
        }
    }

    func refreshDisplays() {
        displays = NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID else { return nil }
            let scale = screen.backingScaleFactor
            return Display(
                id: id,
                name: screen.localizedName,
                pixelSize: CGSize(width: screen.frame.width * scale, height: screen.frame.height * scale))
        }
        if let selected = selectedDisplayID, !displays.contains(where: { $0.id == selected }) {
            close()
            selectedDisplayID = nil
        }
        if selectedDisplayID == nil {
            // Prefer an external display: the main one is usually the laptop.
            let main = NSScreen.main?.displayID
            selectedDisplayID = displays.last(where: { $0.id != main })?.id ?? displays.first?.id
        }
    }

    /// Picks a saved display: the same ID if it is still connected, otherwise
    /// one with the same name (IDs can change after a restart or replug).
    func selectDisplay(id: CGDirectDisplayID?, name: String?) {
        if let match = displays.first(where: { $0.id == id }) ?? displays.first(where: { $0.name == name }) {
            selectedDisplayID = match.id
        }
    }

    func open() {
        guard !isOpen,
              let screen = NSScreen.screens.first(where: { $0.displayID == selectedDisplayID }),
              let renderer = Renderer(frame: CGRect(origin: .zero, size: screen.frame.size)) else { return }
        let window = OutputWindow(screen: screen)
        window.contentView = renderer.view
        window.hideCursor(over: renderer.view)
        window.onEscape = { [weak self] in self?.close() }
        renderer.look = currentLook
        window.orderFrontRegardless()

        // Stop the display from sleeping mid-show while nobody touches the Mac.
        keepAwake = ProcessInfo.processInfo.beginActivity(
            options: [.idleDisplaySleepDisabled, .userInitiated],
            reason: "Projector output is open")
        self.window = window
        self.renderer = renderer
        isOpen = true
    }

    func close() {
        window?.close()
        window = nil
        renderer = nil
        if let keepAwake {
            ProcessInfo.processInfo.endActivity(keepAwake)
        }
        keepAwake = nil
        isOpen = false
    }

    private var currentLook: FixtureLook {
        switch source {
        case .artNet: fixture.look(from: dmxLevels)
        case .testColor: FixtureLook(solid: testColor)
        }
    }

    private func updateLook() {
        renderer?.look = currentLook
    }
}

extension NSScreen {
    /// The CoreGraphics number macOS uses to identify this display.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

extension RGB {
    /// Converts a SwiftUI color (from the color picker) to our 0...1 sRGB numbers.
    init(_ color: Color) {
        let srgb = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent)
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }
}
