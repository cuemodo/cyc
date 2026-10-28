import AppKit
import CycCore
import SwiftUI
import UniformTypeIdentifiers

/// File menu: start fresh, open settings saved earlier, save a copy.
///
/// The app keeps working from its own settings file, which saves itself.
/// Save As writes a copy anywhere (one per show, a backup before trying
/// something); Open loads such a copy back in.
struct SettingsCommands: Commands {
    let keeper: SettingsKeeper
    @ObservedObject var output: OutputController

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            // Nothing changes while the show is locked; saving a copy is harmless.
            Button("New Settings") { newSettings() }
                .keyboardShortcut("n")
                .disabled(output.isLocked)
            Button("Open Settings…") { openSettings() }
                .keyboardShortcut("o")
                .disabled(output.isLocked)
            Divider()
            Button("Save Settings As…") { saveSettingsAs() }
                .keyboardShortcut("s")
            Divider()
            Button("Show Settings File in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([SettingsFile.defaultURL])
            }
        }
    }

    private func newSettings() {
        guard !output.isLocked, confirm(
            "Start with new settings?",
            "The mapping, patch and colors go back to their defaults. Use Save Settings As… first to keep a copy.",
            button: "New Settings") else { return }
        keeper.resetToDefaults()
    }

    private func openSettings() {
        guard !output.isLocked else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.message = "Open Cuemodo Cyc settings. They replace the current ones."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try keeper.load(from: url)
        } catch {
            show(error, doing: "open \(url.lastPathComponent)")
        }
    }

    private func saveSettingsAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Cyc settings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try keeper.save(to: url)
        } catch {
            show(error, doing: "save \(url.lastPathComponent)")
        }
    }

    private func confirm(_ message: String, _ details: String, button: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = details
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func show(_ error: Error, doing action: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not \(action)."
        alert.informativeText = "\(error)"
        alert.runModal()
    }
}
