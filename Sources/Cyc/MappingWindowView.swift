import CycCore
import SwiftUI

/// A selected corner, and which side (canvas or output) it was picked on.
struct CornerSelection: Equatable {
    var id: CornerID
    var side: MappingSide
}

/// The Mapping window: every quad shown twice, on the canvas (what the fixture
/// paints) and on the output (what the projectors show). Drag corners on either
/// side; it works with the output closed. Cmd-Z undoes.
struct MappingWindowView: View {
    @EnvironmentObject private var output: OutputController
    @Environment(\.undoManager) private var undoManager
    @State private var selectedQuad: Int?
    @State private var selectedCorner: CornerSelection?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            sidebar
                .frame(width: 330)
            VStack(alignment: .leading, spacing: 8) {
                Text("Canvas (input): the patch of the picture each quad takes")
                    .font(.headline)
                QuadSideEditor(side: .source, width: output.mapping.canvasWidth,
                               height: output.mapping.canvasHeight,
                               selectedQuad: $selectedQuad, selectedCorner: $selectedCorner)
                Text("Output: where each quad lands on the projectors")
                    .font(.headline)
                    .padding(.top, 8)
                QuadSideEditor(side: .destination, width: output.outputPixelSize.width,
                               height: output.outputPixelSize.height,
                               selectedQuad: $selectedQuad, selectedCorner: $selectedCorner)
            }
        }
        .padding(16)
        .frame(minWidth: 900, minHeight: 600)
        .onChange(of: selectedQuad) { _, quad in
            // A corner of another quad can't stay selected.
            if selectedCorner?.id.quad != quad {
                selectedCorner = nil
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Canvas size (pixels)")
                .font(.headline)
            HStack {
                TextField("Width", value: canvasSize(\.canvasWidth).deferredWrites(), format: .number)
                Text("x")
                TextField("Height", value: canvasSize(\.canvasHeight).deferredWrites(), format: .number)
            }
            Text("The gradient runs from the top of the canvas to its bottom.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Text("Quads")
                .font(.headline)
            List(selection: $selectedQuad) {
                ForEach(output.mapping.quads.indices, id: \.self) { index in
                    Text("Quad \(index + 1)").tag(index)
                }
            }
            .frame(minHeight: 120)
            HStack {
                Button("Add") {
                    let size = output.outputPixelSize
                    output.setMapping(output.mapping.addingQuad(outputWidth: size.width, outputHeight: size.height),
                                      undoManager: undoManager, actionName: "Add Quad")
                    selectedQuad = output.mapping.quads.count - 1
                }
                Button("Remove") {
                    guard let index = selectedQuad else { return }
                    output.setMapping(output.mapping.removingQuad(at: index),
                                      undoManager: undoManager, actionName: "Remove Quad")
                    selectedQuad = nil
                }
                .disabled(selectedQuad == nil)
            }
            Divider()
            if let index = selectedQuad, output.mapping.quads.indices.contains(index) {
                QuadCoordinatesView(quadIndex: index, selectedCorner: $selectedCorner)
            } else {
                Text("Select a quad to see and type its corner coordinates.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func canvasSize(_ keyPath: WritableKeyPath<Mapping, Double>) -> Binding<Double> {
        Binding(
            get: { output.mapping[keyPath: keyPath] },
            set: { value in
                guard value >= 1 else { return }
                var mapping = output.mapping
                mapping[keyPath: keyPath] = value
                output.setMapping(mapping, undoManager: undoManager, actionName: "Change Canvas Size")
            })
    }
}

/// One side of the mapping (canvas or output), scaled to fit, with every quad
/// outlined and draggable corner handles. The selected quad is orange.
///
/// Click a corner to select it (white ring), then the arrow keys nudge it
/// 1 pixel (10 with Shift), and Tab / Shift-Tab selects the next / previous
/// corner.
struct QuadSideEditor: View {
    let side: MappingSide
    let width: Double
    let height: Double
    @Binding var selectedQuad: Int?
    @Binding var selectedCorner: CornerSelection?

    @EnvironmentObject private var output: OutputController
    @Environment(\.undoManager) private var undoManager
    @State private var mappingBeforeDrag: Mapping?
    @State private var draggedCorner: CornerID?
    @FocusState private var hasKeyboard: Bool

    /// The selected corner, if it was picked on this side.
    private var selectedHere: CornerID? {
        selectedCorner?.side == side ? selectedCorner?.id : nil
    }

    private func select(_ id: CornerID?) {
        selectedCorner = id.map { CornerSelection(id: $0, side: side) }
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / width
            Canvas { context, _ in
                draw(in: &context, scale: scale)
            }
            .gesture(drag(scale: scale))
        }
        .aspectRatio(CGSize(width: width, height: height), contentMode: .fit)
        .focusable()
        .focused($hasKeyboard)
        .focusEffectDisabled()
        .onKeyPress(phases: [.down, .repeat]) { press in
            handleKey(press)
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let shift = press.modifiers.contains(.shift)
        let step: Double = shift ? 10 : 1
        switch press.key {
        // macOS sends Shift-Tab as its own "backtab" key (U+0019), not as
        // Tab with Shift held.
        case .tab, KeyEquivalent("\u{19}"):
            let backwards = shift || press.key == KeyEquivalent("\u{19}")
            // With no corner picked yet, start on the selected quad.
            var next = output.mapping.cornerAfter(selectedHere, backwards: backwards)
            if selectedHere == nil, let quad = selectedQuad {
                next = CornerID(quad: quad, corner: .topLeft)
            }
            // Use `next` directly: reading the binding back right after
            // writing it can still return the old corner.
            select(next)
            selectedQuad = next?.quad
        case .leftArrow: nudge(dx: -step, dy: 0)
        case .rightArrow: nudge(dx: step, dy: 0)
        case .upArrow: nudge(dx: 0, dy: -step)
        case .downArrow: nudge(dx: 0, dy: step)
        default: return .ignored
        }
        return .handled
    }

    private func nudge(dx: Double, dy: Double) {
        guard let id = selectedHere, let corner = output.mapping.corner(id, on: side) else { return }
        let point = PixelPoint(
            x: min(max(corner.x + dx, 0), width),
            y: min(max(corner.y + dy, 0), height))
        if let moved = output.mapping.moving(id, to: point, on: side) {
            output.setMapping(moved, undoManager: undoManager, actionName: "Nudge Corner")
        }
    }

    private func draw(in context: inout GraphicsContext, scale: Double) {
        context.fill(Path(CGRect(x: 0, y: 0, width: width * scale, height: height * scale)),
                     with: .color(Color(white: 0.12)))
        for (index, mappedQuad) in output.mapping.quads.enumerated() {
            let quad = mappedQuad[side: side]
            let points = quad.corners.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
            var outline = Path()
            outline.addLines(points)
            outline.closeSubpath()
            let color: Color = index == selectedQuad ? .orange : .yellow
            context.fill(outline, with: .color(color.opacity(0.12)))
            context.stroke(outline, with: .color(quad.isConvex ? color : .red), lineWidth: index == selectedQuad ? 2 : 1)

            let center = CGPoint(x: points.map(\.x).reduce(0, +) / 4, y: points.map(\.y).reduce(0, +) / 4)
            context.draw(Text("\(index + 1)").font(.headline).foregroundColor(color), at: center)
            for (corner, point) in zip(Corner.allCases, points) {
                context.fill(Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)),
                             with: .color(color))
                if CornerID(quad: index, corner: corner) == selectedHere {
                    context.stroke(Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)),
                                   with: .color(.white), lineWidth: 2)
                }
            }
        }
    }

    private func drag(scale: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if mappingBeforeDrag == nil {
                    // Drag just started: grab the corner under the pointer, or
                    // select the quad that was clicked.
                    mappingBeforeDrag = output.mapping
                    let start = PixelPoint(x: value.startLocation.x / scale, y: value.startLocation.y / scale)
                    draggedCorner = output.mapping.nearestCorner(to: start, within: 10 / scale, on: side)
                    select(draggedCorner)
                    selectedQuad = draggedCorner?.quad ?? output.mapping.quadIndex(at: start, on: side)
                    hasKeyboard = true
                }
                guard let corner = draggedCorner else { return }
                let point = PixelPoint(
                    x: min(max((value.location.x / scale).rounded(), 0), width),
                    y: min(max((value.location.y / scale).rounded(), 0), height))
                if let moved = output.mapping.moving(corner, to: point, on: side) {
                    output.mapping = moved  // live while dragging
                }
            }
            .onEnded { _ in
                // Record the whole drag as one undoable step.
                if let before = mappingBeforeDrag {
                    let after = output.mapping
                    output.mapping = before
                    output.setMapping(after, undoManager: undoManager, actionName: "Move Corner")
                }
                mappingBeforeDrag = nil
                draggedCorner = nil
            }
    }
}

/// The selected quad's corners as numbers, in pixels: canvas (input) and
/// output side by side. Values follow drags live; type a value and press
/// Return to move a corner exactly, or use the up / down arrows in a field to
/// step it by 1 pixel (10 with Shift). A value that would dent the quad or
/// cross its edges is refused and the field goes back to the old number.
///
/// The selected corner's x, y pair is boxed in the accent color. Clicking a
/// field selects its corner in the previews too.
struct QuadCoordinatesView: View {
    let quadIndex: Int
    @Binding var selectedCorner: CornerSelection?

    @EnvironmentObject private var output: OutputController
    @Environment(\.undoManager) private var undoManager
    @FocusState private var focusedField: Field?

    enum Axis { case x, y }

    struct Field: Hashable {
        var corner: Corner
        var side: MappingSide
        var axis: Axis
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quad \(quadIndex + 1)")
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
                GridRow {
                    Text("Corner")
                    Text("Canvas x, y")
                    Text("Output x, y")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                ForEach(Corner.allCases, id: \.self) { corner in
                    GridRow {
                        Text(corner.name)
                        pair(corner, .source)
                        pair(corner, .destination)
                    }
                }
            }
        }
        .onChange(of: focusedField) { _, field in
            guard let field else { return }
            selectedCorner = CornerSelection(id: CornerID(quad: quadIndex, corner: field.corner), side: field.side)
        }
    }

    /// One corner's x and y on one side, boxed when that corner is selected.
    private func pair(_ corner: Corner, _ side: MappingSide) -> some View {
        let isSelected = selectedCorner == CornerSelection(id: CornerID(quad: quadIndex, corner: corner), side: side)
        return HStack(spacing: 4) {
            field(Field(corner: corner, side: side, axis: .x))
            field(Field(corner: corner, side: side, axis: .y))
        }
        .padding(3)
        .overlay(RoundedRectangle(cornerRadius: 5)
            .stroke(Color.accentColor, lineWidth: 2)
            .opacity(isSelected ? 1 : 0))
    }

    private func field(_ field: Field) -> some View {
        // Deferred: a text field also commits when it loses focus, which can
        // happen while SwiftUI redraws (e.g. when another quad is selected).
        TextField("", value: coordinate(field).deferredWrites(), format: .number.grouping(.never))
            .frame(width: 58)
            .multilineTextAlignment(.trailing)
            .focused($focusedField, equals: field)
            .onKeyPress(phases: [.down, .repeat]) { press in
                let step: Double = press.modifiers.contains(.shift) ? 10 : 1
                switch press.key {
                case .upArrow: bump(field, by: step)
                case .downArrow: bump(field, by: -step)
                default: return .ignored
                }
                return .handled
            }
    }

    private func keyPath(_ axis: Axis) -> WritableKeyPath<PixelPoint, Double> {
        axis == .x ? \.x : \.y
    }

    private func bump(_ field: Field, by delta: Double) {
        let id = CornerID(quad: quadIndex, corner: field.corner)
        guard var point = output.mapping.corner(id, on: field.side) else { return }
        point[keyPath: keyPath(field.axis)] = max(point[keyPath: keyPath(field.axis)] + delta, 0)
        if let moved = output.mapping.moving(id, to: point, on: field.side) {
            output.setMapping(moved, undoManager: undoManager, actionName: "Nudge Corner")
        }
    }

    private func coordinate(_ field: Field) -> Binding<Double> {
        let id = CornerID(quad: quadIndex, corner: field.corner)
        let axis = keyPath(field.axis)
        return Binding(
            get: { output.mapping.corner(id, on: field.side)?[keyPath: axis] ?? 0 },
            set: { value in
                guard var point = output.mapping.corner(id, on: field.side),
                      point[keyPath: axis] != value else { return }
                point[keyPath: axis] = value
                if let moved = output.mapping.moving(id, to: point, on: field.side) {
                    output.setMapping(moved, undoManager: undoManager, actionName: "Edit Corner")
                }
            })
    }
}
