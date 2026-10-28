import AppKit
import Combine
import CycCore

/// Loads the settings at launch and saves them half a second after the last
/// change (so clicking a stepper ten times writes the file once), and at quit.
@MainActor
final class SettingsKeeper {
    private let input: DMXInputController
    private let output: OutputController
    private let url: URL
    private var lastSaved: CycSettings?
    private var subscriptions: Set<AnyCancellable> = []

    init(input: DMXInputController, output: OutputController, url: URL = SettingsFile.defaultURL) {
        self.input = input
        self.output = output
        self.url = url
        load()

        Publishers.MergeMany(
            input.$universe.map { _ in () }.eraseToAnyPublisher(),
            output.$fixture.map { _ in () }.eraseToAnyPublisher(),
            output.$source.map { _ in () }.eraseToAnyPublisher(),
            output.$manualTop.map { _ in () }.eraseToAnyPublisher(),
            output.$manualBottom.map { _ in () }.eraseToAnyPublisher(),
            output.$manualGradient.map { _ in () }.eraseToAnyPublisher(),
            output.$selectedDisplayID.map { _ in () }.eraseToAnyPublisher(),
            output.$mapping.map { _ in () }.eraseToAnyPublisher(),
            output.$signalLoss.map { _ in () }.eraseToAnyPublisher(),
            output.$signalLossTimeout.map { _ in () }.eraseToAnyPublisher(),
            output.$isLocked.map { _ in () }.eraseToAnyPublisher())
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.saveIfChanged() }
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.saveIfChanged() }
            }
            .store(in: &subscriptions)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let settings = try SettingsFile.load(from: url)
            apply(settings)
            lastSaved = settings
        } catch {
            print("Could not read \(url.path): \(error). Starting with default settings.")
        }
    }

    private func apply(_ settings: CycSettings) {
        input.universe = settings.universe
        output.fixture = settings.fixture
        output.source = settings.source
        output.manualTop = settings.manualTop
        output.manualBottom = settings.manualBottom
        output.manualGradient = settings.manualGradient
        output.selectDisplay(id: settings.displayID, name: settings.displayName)
        output.mapping = settings.mapping
        output.signalLoss = settings.signalLoss
        output.signalLossTimeout = settings.signalLossTimeout
        output.isLocked = settings.locked
    }

    private var current: CycSettings {
        var settings = CycSettings()
        settings.universe = input.universe
        settings.fixture = output.fixture
        settings.source = output.source
        settings.manualTop = output.manualTop
        settings.manualBottom = output.manualBottom
        settings.manualGradient = output.manualGradient
        settings.displayID = output.selectedDisplayID
        settings.displayName = output.displays.first { $0.id == output.selectedDisplayID }?.name
        settings.mapping = output.mapping
        settings.signalLoss = output.signalLoss
        settings.signalLossTimeout = output.signalLossTimeout
        settings.locked = output.isLocked
        return settings
    }

    private func saveIfChanged() {
        let settings = current
        guard settings != lastSaved else { return }
        do {
            try SettingsFile.save(settings, to: url)
            lastSaved = settings
        } catch {
            print("Could not save \(url.path): \(error)")
        }
    }
}
