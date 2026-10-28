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
    @Published var manualTop = CycSettings().manualTop {
        didSet { updateLook() }
    }
    @Published var manualBottom = CycSettings().manualBottom {
        didSet { updateLook() }
    }
    @Published var manualGradient = CycSettings().manualGradient {
        didSet { updateLook() }
    }
    @Published var mapping = Mapping() {
        didSet { renderer?.mapping = mapping }
    }
    @Published var signalLoss = SignalLoss.hold
    @Published var signalLossTimeout = 5.0
    /// Show lock: the windows ignore clicks, and Esc no longer closes the output.
    @Published var isLocked = false
    /// True after `signalLossTimeout` seconds without Art-Net.
    @Published private(set) var signalLost = false

    private let input: DMXInputController
    private var dmxLevels = DMXInputController.blackout
    /// 1 normally, going down to 0 while fading to black after signal loss.
    private var signalLevel = 1.0
    /// A display we want but that is not connected (yet): the saved one at
    /// launch (selected when it shows up), or the one the output was on when
    /// it disappeared (the output reopens on it).
    private var pendingDisplay: (id: CGDirectDisplayID?, name: String?, reopen: Bool)?
    private var window: OutputWindow?
    private var renderer: Renderer?
    private var keepAwake: NSObjectProtocol?
    private var signalTimer: Timer?

    init(input: DMXInputController) {
        self.input = input
        // Every packet for our universe updates the look straight away (not
        // throttled like the main window), so fades on the desk stay smooth.
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
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkSignal() }
        }
        RunLoop.main.add(timer, forMode: .common)
        signalTimer = timer
    }

    func refreshDisplays() {
        let previous = displays.first { $0.id == selectedDisplayID }
        displays = NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID else { return nil }
            let scale = screen.backingScaleFactor
            return Display(
                id: id,
                name: screen.localizedName,
                pixelSize: CGSize(width: screen.frame.width * scale, height: screen.frame.height * scale))
        }
        if let selected = selectedDisplayID, !displays.contains(where: { $0.id == selected }) {
            // The projectors went away (Matrox or cable glitch): wait for them
            // to come back, and reopen the output if it was open.
            pendingDisplay = (previous?.id, previous?.name, isOpen)
            close()
            selectedDisplayID = nil
        }
        if let pending = pendingDisplay,
           let match = displays.first(where: { $0.id == pending.id }) ?? displays.first(where: { $0.name == pending.name }) {
            selectedDisplayID = match.id
            pendingDisplay = nil
            if pending.reopen {
                open()
            }
        }
        if selectedDisplayID == nil {
            // Prefer an external display: the main one is usually the laptop.
            let main = NSScreen.main?.displayID
            selectedDisplayID = displays.last(where: { $0.id != main })?.id ?? displays.first?.id
        }
    }

    /// The output size in real pixels: the chosen display's, even while the
    /// output is closed (3840 x 1200 if no display is chosen).
    var outputPixelSize: CGSize {
        displays.first { $0.id == selectedDisplayID }?.pixelSize ?? CGSize(width: 3840, height: 1200)
    }

    /// Changes the mapping as one undoable step (Edit > Undo, Cmd-Z).
    func setMapping(_ newMapping: Mapping, undoManager: UndoManager?, actionName: String) {
        let oldMapping = mapping
        guard newMapping != oldMapping else { return }
        mapping = newMapping
        undoManager?.registerUndo(withTarget: self) { controller in
            MainActor.assumeIsolated {
                controller.setMapping(oldMapping, undoManager: undoManager, actionName: actionName)
            }
        }
        undoManager?.setActionName(actionName)
    }

    /// Picks a saved display: the same ID if it is still connected, otherwise
    /// one with the same name (IDs can change after a restart or replug).
    func selectDisplay(id: CGDirectDisplayID?, name: String?) {
        if let match = displays.first(where: { $0.id == id }) ?? displays.first(where: { $0.name == name }) {
            selectedDisplayID = match.id
        } else if id != nil || name != nil {
            pendingDisplay = (id, name, false)
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
            guard let self, !self.isLocked else { return }
            self.close()
        }
        renderer.look = currentLook
        renderer.showsGrid = source == .testPattern
        renderer.mapping = mapping
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
        case .artNet: fixture.look(from: dmxLevels).scaled(by: signalLevel)
        case .manual: FixtureLook(top: manualTop, bottom: manualGradient ? manualBottom : manualTop)
        case .testPattern: .black
        }
    }

    /// Runs 20 times a second: notices when Art-Net stops and drives the fade
    /// to black, if that is what `signalLoss` asks for.
    private func checkSignal() {
        let silence = input.lastPacketUptime.map { ProcessInfo.processInfo.systemUptime - $0 }
        let timeout = max(signalLossTimeout, 1)  // a typo of 0 must not flicker
        let lost = (silence ?? 0) > timeout
        if lost != signalLost {
            signalLost = lost
        }
        let level = signalLoss.level(silence: silence, timeout: timeout)
        guard level != signalLevel else { return }
        signalLevel = level
        if source == .artNet {
            updateLook()
        }
    }

    private func updateLook() {
        renderer?.look = currentLook
        renderer?.showsGrid = source == .testPattern
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
