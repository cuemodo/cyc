import Darwin
import Foundation

public enum ArtNetReceiverError: Error, CustomStringConvertible {
    case socket(Int32)
    case bind(Int32)

    public var description: String {
        switch self {
        case .socket(let code):
            "Could not open a network socket: \(String(cString: strerror(code)))"
        case .bind(let code):
            "Could not listen on Art-Net port \(ArtNetReceiver.port): \(String(cString: strerror(code)))"
        }
    }
}

/// Listens for Art-Net on UDP port 6454 and hands every ArtDmx packet to
/// `onPacket`, on the main queue, with the sender's IP address.
///
/// It listens on every network interface, for broadcast and direct packets.
/// The port is opened with "reuse" options so another Art-Net app on the same
/// Mac can listen at the same time.
public final class ArtNetReceiver {
    public static let port: UInt16 = 6454

    public var onPacket: ((ArtDmxPacket, String) -> Void)?
    private var source: DispatchSourceRead?
    private let queue = DispatchQueue(label: "cyc.artnet.receiver")

    public init() {}

    deinit {
        stop()
    }

    public func start(port: UInt16 = ArtNetReceiver.port) throws {
        stop()
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw ArtNetReceiverError.socket(errno) }

        var yes: Int32 = 1
        let size = socklen_t(MemoryLayout<Int32>.size)
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, size)
        setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &yes, size)

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: 0)  // 0 = any interface
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            let code = errno
            Darwin.close(fd)
            throw ArtNetReceiverError.bind(code)
        }

        // The system calls us on `queue` whenever a packet is waiting.
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            guard let received = ArtNetReceiver.receive(from: fd) else { return }
            DispatchQueue.main.async { self?.onPacket?(received.packet, received.sender) }
        }
        source.setCancelHandler { Darwin.close(fd) }
        source.resume()
        self.source = source
    }

    public func stop() {
        source?.cancel()
        source = nil
    }

    private static func receive(from fd: Int32) -> (packet: ArtDmxPacket, sender: String)? {
        let capacity = 1024  // an ArtDmx packet is at most 530 bytes
        var buffer = [UInt8](repeating: 0, count: capacity)
        var address = sockaddr_in()
        var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let count = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                recvfrom(fd, &buffer, capacity, 0, $0, &addressLength)
            }
        }
        guard count > 0, let packet = ArtDmxPacket(bytes: buffer[0..<count]) else { return nil }
        return (packet, String(cString: inet_ntoa(address.sin_addr)))
    }
}
