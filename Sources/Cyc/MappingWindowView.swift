import CycCore
import SwiftUI

/// The Mapping window: every quad shown twice, on the canvas (what the fixture
/// paints) and on the output (what the projectors show). Drag corners on either
/// side; it works with the output closed. Cmd-Z undoes.
struct MappingWindowView: View {
    @EnvironmentObject private var output: OutputController
    @Environment(\.undoManager) private var undoManager
    @State private var selectedQuad: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            quadList
                .frame(width: 180)
            VStack(alignment: .leading, spacing: 8) {
                Text("Canvas (input): the patch of the picture each quad takes")
                    .font(.headline)
                QuadSideEditor(side: .source, width: output.mapping.canvasWidth,
                               height: output.mapping.canvasHeight, selectedQuad: $selectedQuad)
                Text("Output: where each quad lands on the projectors")
                    .font(.headline)
                    .padding(.top, 8)
                QuadSideEditor(side: .destination, width: output.outputPixelSize.width,
                               height: output.outputPixelSize.height, selectedQuad: $selectedQuad)
            }
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 560)
    }

    private var quadList: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            Text("Canvas size (pixels)")
                .font(.headline)
            HStack {
                TextField("Width", value: canvasSize(\.canvasWidth), format: .number)
                Text("x")
                TextField("Height", value: canvasSize(\.canvasHeight), format: .number)
            }
            Text("The gradient runs from the top of the canvas to its bottom.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
/// corner, like Edit on Wall.
struct QuadSideEditor: View {
    let side: MappingSide
    let width: Double
    let height: Double
    @Binding var selectedQuad: Int?

    @EnvironmentObject private var output: OutputController
    @Environment(\.undoManager) private var undoManager
    @State private var mappingBeforeDrag: Mapping?
    @State private var draggedCorner: CornerID?
    @State private var selectedCorner: CornerID?
    @FocusState private var hasKeyboard: Bool

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
        case .tab:
            selectedCorner = output.mapping.cornerAfter(selectedCorner, backwards: shift)
            selectedQuad = selectedCorner?.quad
        case .leftArrow: nudge(dx: -step, dy: 0)
        case .rightArrow: nudge(dx: step, dy: 0)
        case .upArrow: nudge(dx: 0, dy: -step)
        case .downArrow: nudge(dx: 0, dy: step)
        default: return .ignored
        }
        return .handled
    }

    private func nudge(dx: Double, dy: Double) {
        guard let id = selectedCorner, let corner = output.mapping.corner(id, on: side) else { return }
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
                if CornerID(quad: index, corner: corner) == selectedCorner {
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
                    selectedCorner = draggedCorner
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
