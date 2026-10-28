import AppKit
import CycCore
import SwiftUI

/// The main window: the output, then only the controls for what it shows
/// (Art-Net, Manual or Test Pattern), and the show lock. Explanations live in tooltips (hover a
/// control), so only problems show as text.
struct MainView: View {
    @EnvironmentObject private var output: OutputController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let mark = NSImage.resource("CuemodoMark") {
                    Image(nsImage: mark)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 44, height: 44)
                }
                // A wordmark, so all lowercase like the "cuemodo" logo. The
                // app's name stays "Cuemodo Cyc" everywhere else.
                Text(CycInfo.name.lowercased())
                    .brandTitle()
                Spacer()
                lockButton
            }
            Divider()

            // Show lock: nothing below reacts until unlocked.
            Group {
                Text("Output")
                    .sectionTitle()
                HStack(alignment: .center, spacing: 16) {
                    outputButton
                    // A grid, so both pickers start at the same left edge
                    // whatever the length of their labels.
                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
                        GridRow {
                            Text("Display")
                                .gridColumnAlignment(.trailing)
                            HStack {
                                Picker("Display", selection: $output.selectedDisplayID.deferredWrites()) {
                                    ForEach(output.displays) { display in
                                        Text(display.label).tag(Optional(display.id))
                                    }
                                }
                                .labelsHidden()
                                .disabled(output.isOpen)
                                Button("Mapping…") {
                                    openWindow(id: "mapping")
                                }
                                .help(mappingText)
                            }
                        }
                        GridRow {
                            Text("Show")
                            Picker("Show", selection: $output.source.deferredWrites()) {
                                ForEach(OutputSource.allCases) { source in
                                    Text(source.name).tag(source)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .fixedSize()
                            .help("Test Pattern draws a white grid inside the quads: while adjusting the mapping, its lines must run straight across the seam.")
                        }
                    }
                }

                if output.mapping.invalidQuadCount > 0 {
                    Text("\(output.mapping.invalidQuadCount) quads skipped (dented, crossed or squashed).")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                switch output.source {
                case .artNet:
                    Divider()
                    ArtNetView()
                case .manual:
                    Divider()
                    manualControls
                case .testPattern:
                    EmptyView()
                }
            }
            .disabled(output.isLocked)
        }
        .padding(24)
        .frame(minWidth: 560, alignment: .leading)
    }

    /// Solid or gradient, and its colors. Kept apart from the fixture mode so
    /// trying things here never changes the Art-Net patch.
    private var manualControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manual")
                .sectionTitle()
            HStack(spacing: 16) {
                Picker("Look", selection: $output.manualGradient.deferredWrites()) {
                    Text("Solid").tag(false)
                    Text("Gradient").tag(true)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
                if output.manualGradient {
                    ColorPicker("Top", selection: color(\.manualTop).deferredWrites(), supportsOpacity: false)
                    ColorPicker("Bottom", selection: color(\.manualBottom).deferredWrites(), supportsOpacity: false)
                } else {
                    ColorPicker("Color", selection: color(\.manualTop).deferredWrites(), supportsOpacity: false)
                }
            }
            .fixedSize()
            .help("Manual shows these colors instead of Art-Net.")
        }
    }

    /// Locks the windows for the show, so a stray click or key press can't
    /// change anything. Stays locked after a relaunch.
    private var lockButton: some View {
        Button {
            output.isLocked.toggle()
        } label: {
            Label(output.isLocked ? "Locked" : "Lock",
                  systemImage: output.isLocked ? "lock.fill" : "lock.open")
        }
        .buttonStyle(.borderedProminent)
        .tint(output.isLocked ? Brand.amber : .gray)
        .help(output.isLocked
              ? "Locked for the show: controls, the Mapping window and Esc on the output are ignored. Click to unlock."
              : "Lock everything for the show, so a stray click or key press changes nothing.")
    }

    /// Big and colored so it reads from across the room: green Play while
    /// the output is closed, red Stop while it is live.
    private var outputButton: some View {
        Button {
            if output.isOpen {
                output.close()
            } else {
                output.open()
            }
        } label: {
            Label(output.isOpen ? "Stop" : "Start",
                  systemImage: output.isOpen ? "stop.fill" : "play.fill")
        }
        .buttonStyle(OutputButtonStyle(color: output.isOpen ? .red : .green))
        .disabled(output.selectedDisplayID == nil)
        .help(output.isOpen
              ? "The output is live. Stop closes it (or click the output, then press Esc)."
              : "Start opens the output fullscreen on the chosen display.")
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

/// A large filled button with a white icon and title, dimmed when disabled.
struct OutputButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, color: color)
    }

    // Not "Body": that name is ButtonStyle's own associated type.
    private struct Face: View {
        let configuration: Configuration
        let color: Color
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 130, height: 56)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(isEnabled ? color : Color.gray))
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}
