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
    @Published var mapping = Mapping() {
        didSet {
            renderer?.mapping = mapping
            editor?.mapping = mapping
        }
    }
    /// True while the mapping is being edited on the output.
    @Published private(set) var isEditing = false

    private var dmxLevels = DMXInputController.blackout
    private var window: OutputWindow?
    private var renderer: Renderer?
    private var editor: MappingEditorView?
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
        window.onEscape = { [weak self] in
            guard let self else { return }
            if isEditing { stopEditing() } else { close() }
        }

        // The editor sits on top of the image, hidden until editing starts.
        let editor = MappingEditorView(frame: renderer.view.bounds)
        editor.autoresizingMask = [.width, .height]
        editor.isHidden = true
        editor.mapping = mapping
        editor.onChange = { [weak self] mapping in self?.mapping = mapping }
        renderer.view.addSubview(editor)
        renderer.look = currentLook
        renderer.mapping = mapping
        window.orderFrontRegardless()

        // Stop the display from sleeping mid-show while nobody touches the Mac.
        keepAwake = ProcessInfo.processInfo.beginActivity(
            options: [.idleDisplaySleepDisabled, .userInitiated],
            reason: "Projector output is open")
        self.window = window
        self.renderer = renderer
        self.editor = editor
        isOpen = true
    }

    func close() {
        stopEditing()
        window?.close()
        window = nil
        renderer = nil
        editor = nil
        if let keepAwake {
            ProcessInfo.processInfo.endActivity(keepAwake)
        }
        keepAwake = nil
        isOpen = false
    }

    /// Shows the test grid and corner handles on the output, and gives it the
    /// keyboard so the arrow keys nudge corners. This takes focus away from
    /// QLab, so do it before the show, not during.
    func startEditing() {
        guard let window, let renderer, let editor, !isEditing else { return }
        if mapping.quads.isEmpty {
            let size = renderer.view.drawableSize
            mapping = .filling(width: size.width, height: size.height)
        }
        renderer.isEditing = true
        editor.isHidden = false
        window.hidesCursor = false
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(editor)
        isEditing = true
    }

    func stopEditing() {
        guard isEditing else { return }
        renderer?.isEditing = false
        editor?.isHidden = true
        window?.hidesCursor = true
        isEditing = false
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
