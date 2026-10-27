import AppKit

/// A borderless window covering one whole display: the projector output.
///
/// It never grabs keyboard focus by itself, so QLab keeps its GO key while
/// the output is open. Click the output first if you want Esc to close it.
final class OutputWindow: NSWindow {
    var onEscape: (@MainActor () -> Void)?
    private var cursorHidden = false

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = .mainMenu + 1  // above the menu bar on that display
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        backgroundColor = .black
        hasShadow = false
    }

    required init?(coder: NSCoder) {
        fatalError("OutputWindow is created in code, not from a storyboard")
    }

    // Borderless windows refuse focus by default; allow it so Esc works after a click.
    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        let escapeKeyCode: UInt16 = 53
        if event.keyCode == escapeKeyCode {
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }

    /// Hide the mouse pointer while it is over the projector image.
    func hideCursor(over view: NSView) {
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil)
        view.addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        if !cursorHidden {
            NSCursor.hide()
            cursorHidden = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        showCursor()
    }

    override func close() {
        showCursor()
        super.close()
    }

    private func showCursor() {
        if cursorHidden {
            NSCursor.unhide()
            cursorHidden = false
        }
    }
}
