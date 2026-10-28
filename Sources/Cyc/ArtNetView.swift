import CycCore
import SwiftUI

/// Everything for Art-Net in one place: what to patch on the desk (universe,
/// address, mode), whether packets arrive, and on demand the 512 levels.
struct ArtNetView: View {
    @EnvironmentObject private var input: DMXInputController
    @EnvironmentObject private var output: OutputController
    @AppStorage("showsLevels") private var showsLevels = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Art-Net Patch")
                .sectionTitle()
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
                GridRow {
                    Text("Universe")
                        .gridColumnAlignment(.trailing)
                    HStack {
                        Text("\(input.universe)")
                            .monospacedDigit()
                        Stepper("Universe", value: $input.universe, in: 0...0x7FFF)
                            .labelsHidden()
                        Text(ArtDmxPacket.label(universe: UInt16(input.universe)))
                            .foregroundStyle(.secondary)
                    }
                    // Full width for the label: the grid would otherwise
                    // squeeze this cell and truncate it.
                    .fixedSize()
                    .help("Art-Net Port-Address, counted from 0 (net:subnet:universe next to it).")
                    Text("Address")
                        .gridColumnAlignment(.trailing)
                    HStack {
                        TextField("Address", value: $output.fixture.address.deferredWrites(), format: .number)
                            .labelsHidden()
                            .frame(width: 60)
                        Stepper("Address", value: $output.fixture.address, in: 1...512)
                            .labelsHidden()
                    }
                    .help(channelsText)
                }
                GridRow {
                    Text("Mode")
                    Picker("Mode", selection: $output.fixture.mode.deferredWrites()) {
                        ForEach(FixtureMode.allCases) { mode in
                            Text(mode.name).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .help(channelsText)
                    .gridCellColumns(3)
                }
                GridRow {
                    Text("Signal loss")
                    HStack {
                        Picker("Signal loss", selection: $output.signalLoss.deferredWrites()) {
                            ForEach(SignalLoss.allCases) { behavior in
                                Text(behavior.name).tag(behavior)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        // Hold does nothing over time, so no delay to set.
                        if output.signalLoss == .fadeToBlack {
                            Text("after")
                            TextField("Seconds", value: $output.signalLossTimeout.deferredWrites(), format: .number)
                                .labelsHidden()
                                .frame(width: 40)
                            Text("s without Art-Net")
                        }
                    }
                    .fixedSize()
                    .help("If the desk, the node or a cable fails: keep the last look, or fade to black over \(Int(SignalLoss.fadeDuration)) s. The next packet brings the look back.")
                    .gridCellColumns(3)
                }
            }
            if output.signalLost {
                Text(output.signalLoss == .hold
                     ? "Art-Net lost: holding the last look."
                     : "Art-Net lost: faded to black.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if !output.fixture.fitsInUniverse {
                Text(channelsText)
                    .font(.caption)
                    .foregroundStyle(.red)
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

    private var channelsText: String {
        let fixture = output.fixture
        guard fixture.fitsInUniverse else {
            return "This mode needs \(fixture.mode.channelCount) channels, so the address must be "
                + "between 1 and \(512 - fixture.mode.channelCount + 1)."
        }
        return "Uses channels \(fixture.address) to \(fixture.lastChannel): "
            + fixture.mode.channelNames.joined(separator: ", ") + "."
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
