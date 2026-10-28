import CycCore
import SwiftUI

/// Art-Net settings and, on demand, a live view of the 512 channel levels.
struct DMXInputView: View {
    @EnvironmentObject private var input: DMXInputController
    @AppStorage("showsLevels") private var showsLevels = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Art-Net input")
                .sectionTitle()
            Stepper(value: $input.universe, in: 0...0x7FFF) {
                Text("Universe \(input.universe)")
                + Text("  (\(ArtDmxPacket.label(universe: UInt16(input.universe))))")
                    .foregroundColor(.secondary)
            }
            HStack {
                Text(input.statusText)
                    .font(.caption)
                    .foregroundStyle(input.error == nil ? Color.secondary : Color.red)
                Spacer()
                Button(showsLevels ? "Hide Levels" : "Show Levels") {
                    showsLevels.toggle()
                }
                .help("The 512 channel levels received on this universe.")
            }
            if showsLevels {
                LevelGrid(levels: input.levels)
            }
        }
    }
}

/// 512 small cells, 16 per row: channel number on top, level (0 to 255) below.
/// A cell is tinted more strongly the higher its level.
struct LevelGrid: View {
    let levels: [UInt8]
    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 2), count: 16)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 2) {
                ForEach(levels.indices, id: \.self) { index in
                    VStack(spacing: 0) {
                        Text("\(index + 1)")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text("\(levels[index])")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .frame(width: 30, height: 26)
                    .background(Color.accentColor.opacity(Double(levels[index]) / 255 * 0.6))
                }
            }
        }
        .frame(height: 180)
    }
}
