import AppKit
import CycCore
import SwiftUI

/// Entry point. For now the app is a single settings window; the projector
/// output window arrives in the next step.
@main
struct CycApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window(CycInfo.name, id: "settings") {
            SettingsView()
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
