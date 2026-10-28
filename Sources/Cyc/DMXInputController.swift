import CycCore
import Foundation

/// Receives Art-Net and keeps the levels of the chosen universe.
///
/// Packets arrive about 44 times a second. The main window only needs a
/// few updates a second, so `levels` is refreshed 10 times a second.
@MainActor
final class DMXInputController: ObservableObject {
    /// Art-Net Port-Address, counted from 0 like Art-Net does.
    @Published var universe = 0 {
        didSet {
            guard universe != oldValue else { return }
            latest = Self.blackout
            latestSender = nil
            lastPacketUptime = nil
            onLevels?(Self.blackout)
        }
    }

    /// Called with all 512 levels each time a packet for `universe` arrives.
    var onLevels: (@MainActor ([UInt8]) -> Void)?
    @Published private(set) var levels = DMXInputController.blackout
    @Published private(set) var packetsPerSecond = 0
    @Published private(set) var sender: String?
    @Published private(set) var error: String?
    /// When the last packet for `universe` arrived (seconds since the Mac
    /// started, which never jumps like the clock can). Nil: none yet.
    private(set) var lastPacketUptime: TimeInterval?

    static let blackout = [UInt8](repeating: 0, count: ArtDmxPacket.channelCount)

    private let receiver = ArtNetReceiver()
    private var latest = DMXInputController.blackout
    private var latestSender: String?
    private var packetCount = 0
    private var ticks = 0
    private var timer: Timer?

    init() {
        receiver.onPacket = { [weak self] packet, sender in
            MainActor.assumeIsolated { self?.handle(packet, from: sender) }
        }
        do {
            try receiver.start()
        } catch {
            self.error = "\(error)"
        }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)  // keep ticking while menus are open
        self.timer = timer
    }

    var statusText: String {
        if let error { return error }
        guard packetsPerSecond > 0, let sender else { return "No Art-Net on this universe yet." }
        return "Receiving \(packetsPerSecond) packets/s from \(sender)."
    }

    private func handle(_ packet: ArtDmxPacket, from sender: String) {
        guard packet.universe == universe else { return }
        latest = packet.levels
        latestSender = sender
        lastPacketUptime = ProcessInfo.processInfo.systemUptime
        packetCount += 1
        onLevels?(packet.levels)
    }

    private func tick() {
        if levels != latest {
            levels = latest
        }
        ticks += 1
        if ticks == 10 {
            packetsPerSecond = packetCount
            sender = packetCount > 0 ? latestSender : nil
            packetCount = 0
            ticks = 0
        }
    }
}
