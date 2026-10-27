/// One ArtDmx packet: the Art-Net message that carries the levels of one DMX universe.
///
/// Byte layout:
/// - 0-7: the text "Art-Net" followed by a zero byte
/// - 8-9: OpCode 0x5000, low byte first
/// - 10-11: protocol version (ignored)
/// - 12: sequence number, 0 when the sender does not use it
/// - 13: physical input port on the sender (ignored)
/// - 14: SubUni (Sub-Net in the high 4 bits, Universe in the low 4 bits)
/// - 15: Net (7 bits)
/// - 16-17: number of levels that follow, high byte first (up to 512)
/// - 18...: the levels, one byte per DMX channel
public struct ArtDmxPacket: Equatable, Sendable {
    public static let opCode: UInt16 = 0x5000
    public static let header: [UInt8] = Array("Art-Net".utf8) + [0]
    public static let channelCount = 512

    /// The 15-bit Art-Net "Port-Address": Net, Sub-Net and Universe in one number.
    /// Art-Net counts from 0, so the first universe is 0.
    public let universe: UInt16
    public let sequence: UInt8
    /// Always 512 levels; channels the sender left out are 0.
    public let levels: [UInt8]

    /// Returns nil for anything that is not a well-formed ArtDmx packet
    /// (other Art-Net messages such as ArtPoll, or other traffic on the port).
    public init?<Bytes: Collection>(bytes: Bytes) where Bytes.Element == UInt8 {
        let b = Array(bytes)
        guard b.count >= 18, Array(b[0..<8]) == Self.header else { return nil }
        guard UInt16(b[8]) | UInt16(b[9]) << 8 == Self.opCode else { return nil }
        let length = Int(b[16]) << 8 | Int(b[17])
        guard (1...Self.channelCount).contains(length), b.count >= 18 + length else { return nil }

        universe = UInt16(b[15] & 0x7F) << 8 | UInt16(b[14])
        sequence = b[12]
        levels = Array(b[18..<(18 + length)]) + Array(repeating: 0, count: Self.channelCount - length)
    }

    /// Level of a DMX channel, numbered 1 to 512 like on a desk. Out of range reads as 0.
    public func level(channel: Int) -> UInt8 {
        (1...Self.channelCount).contains(channel) ? levels[channel - 1] : 0
    }

    /// Spells out a Port-Address the way some desks show it, e.g. 0x123 is
    /// "Net 1, Sub-Net 2, Universe 3".
    public static func label(universe: UInt16) -> String {
        "Net \(universe >> 8 & 0x7F), Sub-Net \(universe >> 4 & 0x0F), Universe \(universe & 0x0F)"
    }
}
