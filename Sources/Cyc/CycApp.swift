import AppKit
import CycCore
import SwiftUI

/// Entry point: the settings window, the projector output window that
/// `OutputController` opens on demand, the Art-Net input, and the saved settings.
@main
struct CycApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var input: DMXInputController
    @StateObject private var output: OutputController
    @State private var settingsKeeper: SettingsKeeper

    init() {
        let input = DMXInputController()
        let output = OutputController(input: input)
        _input = StateObject(wrappedValue: input)
        _output = StateObject(wrappedValue: output)
        _settingsKeeper = State(initialValue: SettingsKeeper(input: input, output: output))
    }

    var body: some Scene {
        Window(CycInfo.name, id: "settings") {
            SettingsView()
                .environmentObject(output)
                .environmentObject(input)
        }
        .windowResizability(.contentSize)

        Window("Mapping", id: "mapping") {
            MappingWindowView()
                .environmentObject(output)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // `swift run` starts us as a plain command-line process. Ask macOS to
        // treat it as a normal app, with a Dock icon and a focused window.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
