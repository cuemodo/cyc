import AppKit
import CycCore
import SwiftUI

/// The control window. Explanations live in tooltips (hover a control), so
/// only problems show as text.
struct SettingsView: View {
    @EnvironmentObject private var output: OutputController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(CycInfo.name)
                .font(.title)
            HStack {
                Text("Version \(CycInfo.version)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Show Settings File") {
                    NSWorkspace.shared.activateFileViewerSelecting([SettingsFile.defaultURL])
                }
            }
            Divider()

            Text("Output")
                .font(.headline)
            Picker("Output display", selection: $output.selectedDisplayID.deferredWrites()) {
                ForEach(output.displays) { display in
                    Text(display.label).tag(Optional(display.id))
                }
            }
            .disabled(output.isOpen)

            Picker("Show", selection: $output.source.deferredWrites()) {
                ForEach(OutputSource.allCases) { source in
                    Text(source.name).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Grid draws a white test grid inside the quads: while adjusting the mapping, its lines must run straight across the seam.")

            if output.source == .manual {
                HStack(spacing: 16) {
                    if output.fixture.mode.isGradient {
                        ColorPicker("Top", selection: color(\.manualTop).deferredWrites(), supportsOpacity: false)
                        ColorPicker("Bottom", selection: color(\.manualBottom).deferredWrites(), supportsOpacity: false)
                    } else {
                        ColorPicker("Color", selection: color(\.manualTop).deferredWrites(), supportsOpacity: false)
                    }
                }
                .help("Manual shows these colors instead of Art-Net. Gradient modes use a top and a bottom color.")
            }

            Button(output.isOpen ? "Close Output" : "Open Output") {
                if output.isOpen {
                    output.close()
                } else {
                    output.open()
                }
            }
            .disabled(output.selectedDisplayID == nil)
            .help("To close from the output itself, click it, then press Esc.")

            Button("Mapping…") {
                openWindow(id: "mapping")
            }
            .help(mappingText)

            if output.mapping.invalidQuadCount > 0 {
                Text("\(output.mapping.invalidQuadCount) quads skipped (dented, crossed or squashed).")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()
            FixtureView()

            Divider()
            DMXInputView()
        }
        .padding(24)
        .frame(minWidth: 560, alignment: .leading)
    }

    private var mappingText: String {
        let mapping = output.mapping
        guard !mapping.quads.isEmpty else { return "Mapping: none, the canvas fills the whole output." }
        return "Mapping: \(mapping.quads.count) quads on a \(Int(mapping.canvasWidth)) x \(Int(mapping.canvasHeight)) canvas."
    }

    private func color(_ keyPath: ReferenceWritableKeyPath<OutputController, RGB>) -> Binding<Color> {
        Binding(
            get: { output[keyPath: keyPath].swiftUIColor },
            set: { color in
                // The color picker can echo the current color back (with tiny
                // rounding changes) while SwiftUI is drawing. Publishing then
                // triggers "Publishing changes from within view updates", so
                // only real changes go through.
                let new = RGB(color)
                if !new.isClose(to: output[keyPath: keyPath]) {
                    output[keyPath: keyPath] = new
                }
            })
    }
}
