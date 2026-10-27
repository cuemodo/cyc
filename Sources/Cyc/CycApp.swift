import AppKit
import CycCore
import SwiftUI

/// Entry point: the settings window, the projector output window that
/// `OutputController` opens on demand, and the Art-Net input.
@main
struct CycApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var output = OutputController()
    @StateObject private var input = DMXInputController()

    var body: some Scene {
        Window(CycInfo.name, id: "settings") {
            SettingsView()
                .environmentObject(output)
                .environmentObject(input)
        }
        .windowResizability(.contentSize)
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
