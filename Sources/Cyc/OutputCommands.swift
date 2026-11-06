import SwiftUI

/// Output menu: Start (Cmd-U) and Stop (Cmd-T), the shortcuts other
/// projection apps use. They work from any of our windows, including the
/// output itself, as long as Cyc is the active app.
struct OutputCommands: Commands {
    @ObservedObject var output: OutputController

    var body: some Commands {
        CommandMenu("Output") {
            Button("Start Output") { output.start() }
                .keyboardShortcut("u")
                .disabled(output.isOpen || output.isLocked || output.selectedDisplayID == nil)
            Button("Stop Output") { output.stop() }
                .keyboardShortcut("t")
                .disabled(!output.isOpen || output.isLocked)
        }
    }
}
