import AppKit
import CycCore
import SwiftUI

/// A small window shown just before the output covers the screen the
/// controls are on (usually a Mac with one display). Once the output is up the
/// main window is hidden behind it, so this says how to get back: Cmd-T.
///
/// It closes itself after a few seconds, or when OK is pressed, and only then
/// does the output open.
@MainActor
final class ExitReminder {
    private var panel: NSPanel?
    private var timer: Timer?
    private var onDone: (() -> Void)?

    var isShowing: Bool { panel != nil }

    /// Shows the reminder, then calls `onDone` after `seconds` or on OK.
    func show(for seconds: TimeInterval = 5, then onDone: @escaping () -> Void) {
        guard panel == nil else { return }
        self.onDone = onDone
        let content = NSHostingView(rootView: ExitReminderView { [weak self] in self?.finish() }
            .cuemodoWindow())
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = CycInfo.name
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        let timer = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        panel?.close()
        panel = nil
        let onDone = self.onDone
        self.onDone = nil
        onDone?()
    }
}

/// The reminder's content: the shortcut in big letters on an amber background,
/// so it is noticed before the screen goes to the projector look.
private struct ExitReminderView: View {
    let onOK: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 34))
                .foregroundStyle(Brand.amber)
            Text("Press ⌘T to stop the output")
                .font(.title2.bold())
            Text("The output is about to cover this screen and hide the controls.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("OK", action: onOK)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(24)
        .frame(width: 360)
        .background(Brand.amber.opacity(0.15))
    }
}
