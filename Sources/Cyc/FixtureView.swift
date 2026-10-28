import CycCore
import SwiftUI

/// Fixture settings: the mode and DMX address to patch on the desk.
struct FixtureView: View {
    @EnvironmentObject private var output: OutputController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fixture")
                .font(.headline)
            Picker("Mode", selection: $output.fixture.mode.deferredWrites()) {
                ForEach(FixtureMode.allCases) { mode in
                    Text(mode.name).tag(mode)
                }
            }
            .fixedSize()
            .help(channelsText)
            HStack {
                Text("DMX address")
                TextField("", value: $output.fixture.address, format: .number)
                    .frame(width: 60)
                Stepper("", value: $output.fixture.address, in: 1...512)
                    .labelsHidden()
            }
            .help(channelsText)
            if !output.fixture.fitsInUniverse {
                Text(channelsText)
                    .font(.caption)
                    .foregroundStyle(.red)
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
