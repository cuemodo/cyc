import AppKit
import CycCore
import SwiftUI

/// The control window. Mapping settings arrive in a later step.
struct SettingsView: View {
    @EnvironmentObject private var output: OutputController

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

            ColorPicker("Test color", selection: testColor.deferredWrites(), supportsOpacity: false)
                .disabled(output.source != .testColor)

            Button(output.isOpen ? "Close Output" : "Open Output") {
                if output.isOpen {
                    output.close()
                } else {
                    output.open()
                }
            }
            .disabled(output.selectedDisplayID == nil)

            Text("To close from the output itself, click it, then press Esc.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
            FixtureView()

            Divider()
            DMXInputView()
        }
        .padding(24)
        .frame(minWidth: 560, alignment: .leading)
    }

    private var testColor: Binding<Color> {
        Binding(
            get: { output.testColor.swiftUIColor },
            set: { color in
                // The color picker can echo the current color back (with tiny
                // rounding changes) while SwiftUI is drawing. Publishing then
                // triggers "Publishing changes from within view updates", so
                // only real changes go through.
                let new = RGB(color)
                if !new.isClose(to: output.testColor) {
                    output.testColor = new
                }
            })
    }
}
