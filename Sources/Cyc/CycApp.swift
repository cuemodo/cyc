import AppKit
import CycCore
import SwiftUI

/// Entry point: the main window, the projector output window that
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
        AppDelegate.output = output
    }

    var body: some Scene {
        Window(CycInfo.name, id: "main") {
            MainView()
                .environmentObject(output)
                .environmentObject(input)
                .cuemodoWindow()
        }
        .windowResizability(.contentSize)
        .commands {
            // Built with SwiftPM there is no Info.plist, so the standard About
            // panel would show no version: give it ours.
            CommandGroup(replacing: .appInfo) {
                Button("About \(CycInfo.name)") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: CycInfo.name,
                        .applicationVersion: CycInfo.version,
                        .version: "",
                        .credits: aboutCredits,
                    ])
                }
            }
            SettingsCommands(keeper: settingsKeeper, output: output)
            CommandGroup(replacing: .help) {
                Button("Cuemodo Website") {
                    NSWorkspace.shared.open(CycInfo.website)
                }
                Button("\(CycInfo.name) on GitHub") {
                    NSWorkspace.shared.open(CycInfo.sourceCode)
                }
            }
        }

        Window("Mapping", id: "mapping") {
            MappingWindowView()
                .environmentObject(output)
                .disabled(output.isLocked)
                .cuemodoWindow()
        }
    }
}

extension NSImage {
    /// A PNG from Sources/Cyc/Resources.
    static func resource(_ name: String) -> NSImage? {
        Bundle.module.url(forResource: name, withExtension: "png").flatMap(NSImage.init(contentsOf:))
    }
}

/// The About panel's small print: a link to cuemodo.io, centered like the
/// rest of the panel.
private var aboutCredits: NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    return NSAttributedString(string: "cuemodo.io", attributes: [
        .link: CycInfo.website,
        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
        .paragraphStyle: paragraph,
    ])
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by `CycApp`, so quitting can check whether the output is live.
    @MainActor static weak var output: OutputController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // `swift run` starts us as a plain command-line process. Ask macOS to
        // treat it as a normal app, with a Dock icon and a focused window.
        NSApp.setActivationPolicy(.regular)
        // No .app bundle yet, so set the Dock icon by hand.
        NSApp.applicationIconImage = NSImage.resource("AppIcon")
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// A stray Cmd-Q mid-show would black out the wall: ask first while the
    /// output is open.
    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard Self.output?.isOpen == true else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "The output is live."
        alert.informativeText = "Quitting \(CycInfo.name) turns the projectors' image off."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Quit")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}
