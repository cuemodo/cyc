import CycCore
import SwiftUI

/// The control window. Later steps add fixture and mapping settings here.
struct SettingsView: View {
    @EnvironmentObject private var output: OutputController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(CycInfo.name)
                .font(.title)
            Text("Version \(CycInfo.version)")
                .foregroundStyle(.secondary)
            Divider()

            Text("Output")
                .font(.headline)
            Picker("Output display", selection: $output.selectedDisplayID) {
                ForEach(output.displays) { display in
                    Text(display.label).tag(Optional(display.id))
                }
            }
            .disabled(output.isOpen)

            ColorPicker("Test color", selection: testColor, supportsOpacity: false)

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
            DMXInputView()
        }
        .padding(24)
        .frame(minWidth: 560, alignment: .leading)
    }

    private var testColor: Binding<Color> {
        Binding(
            get: { output.testColor.swiftUIColor },
            set: { output.testColor = RGB($0) })
    }
}
