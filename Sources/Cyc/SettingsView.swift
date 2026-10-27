import CycCore
import SwiftUI

/// The control window. Later steps add network, fixture, output and mapping
/// settings here.
struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(CycInfo.name)
                .font(.title)
            Text("Version \(CycInfo.version)")
                .foregroundStyle(.secondary)
            Divider()
            Text("No output yet.")
        }
        .padding(24)
        .frame(minWidth: 360, alignment: .leading)
    }
}
