import AppKit
import CycCore

/// A see-through layer over the projector output while editing the mapping.
/// It outlines each quad, draws a handle on every corner, and lets you move
/// corners with the mouse or the keyboard:
///
/// - drag a handle to move it
/// - Tab / Shift-Tab: select the next / previous corner
/// - arrow keys: nudge the selected corner 1 pixel (10 with Shift)
/// - Esc: leave edit mode (handled by the window)
///
/// Corners are kept in output pixels, like the mapping; the view works in
/// points, so it converts with the display's scale (1 on a projector, 2 on a
/// Retina screen).
final class MappingEditorView: NSView {
    var mapping = Mapping() {
        didSet { needsDisplay = true }
    }
    /// Called with the new mapping after every move.
    var onChange: (@MainActor (Mapping) -> Void)?

    private var selected: CornerID? {
        didSet { needsDisplay = true }
    }
    private let handleRadius: CGFloat = 8
    private let grabDistance: CGFloat = 20

    override var isFlipped: Bool { true }  // y grows downwards, like the mapping
    override var acceptsFirstResponder: Bool { true }
    // React to the first click even when the output window is not in front.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var scale: CGFloat { window?.backingScaleFactor ?? 1 }

    private func viewPoint(_ point: PixelPoint) -> CGPoint {
        CGPoint(x: point.x / scale, y: point.y / scale)
    }

    private func pixelPoint(_ point: CGPoint) -> PixelPoint {
        PixelPoint(x: (point.x * scale).rounded(), y: (point.y * scale).rounded())
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        for (index, quad) in mapping.quads.enumerated() {
            let corners = quad.destination.corners.map(viewPoint)
            let outline = NSBezierPath()
            outline.move(to: corners[0])
            corners.dropFirst().forEach { outline.line(to: $0) }
            outline.close()
            outline.lineWidth = 2
            (quad.destination.isConvex ? NSColor.systemYellow : NSColor.systemRed).setStroke()
            outline.stroke()

            let center = CGPoint(x: corners.map(\.x).reduce(0, +) / 4, y: corners.map(\.y).reduce(0, +) / 4)
            let label = NSAttributedString(string: "\(index + 1)", attributes: [
                .font: NSFont.boldSystemFont(ofSize: 48),
                .foregroundColor: NSColor.systemYellow,
            ])
            label.draw(at: CGPoint(x: center.x - label.size().width / 2, y: center.y - label.size().height / 2))
        }

        for id in mapping.allCorners {
            guard let corner = mapping.corner(id) else { continue }
            let p = viewPoint(corner)
            let handle = NSBezierPath(ovalIn: CGRect(
                x: p.x - handleRadius, y: p.y - handleRadius, width: handleRadius * 2, height: handleRadius * 2))
            (id == selected ? NSColor.systemOrange : NSColor.white).setFill()
            handle.fill()
            NSColor.black.setStroke()
            handle.stroke()
        }
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = pixelPoint(convert(event.locationInWindow, from: nil))
        selected = mapping.nearestCorner(to: point, within: Double(grabDistance * scale))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let selected else { return }
        var point = pixelPoint(convert(event.locationInWindow, from: nil))
        // Keep corners on the output, where they can still be grabbed.
        point.x = min(max(point.x, 0), Double(bounds.width * scale))
        point.y = min(max(point.y, 0), Double(bounds.height * scale))
        move(selected, to: point)
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        let step: Double = event.modifierFlags.contains(.shift) ? 10 : 1
        switch event.keyCode {
        case 48:  // Tab
            selected = mapping.cornerAfter(selected, backwards: event.modifierFlags.contains(.shift))
        case 123: nudge(dx: -step, dy: 0)  // left arrow
        case 124: nudge(dx: step, dy: 0)   // right arrow
        case 125: nudge(dx: 0, dy: step)   // down arrow
        case 126: nudge(dx: 0, dy: -step)  // up arrow
        default: super.keyDown(with: event)  // Esc and the rest go to the window
        }
    }

    private func nudge(dx: Double, dy: Double) {
        guard let selected, let corner = mapping.corner(selected) else { return }
        move(selected, to: PixelPoint(x: corner.x + dx, y: corner.y + dy))
    }

    private func move(_ id: CornerID, to point: PixelPoint) {
        guard let moved = mapping.moving(id, to: point) else { return }  // would break the quad
        mapping = moved
        onChange?(moved)
    }
}
