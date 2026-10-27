import CycCore
import XCTest

final class ArtDmxPacketTests: XCTestCase {
    /// Builds packet bytes the way a desk would send them.
    private func packet(net: UInt8 = 0, subUni: UInt8 = 0, sequence: UInt8 = 0, levels: [UInt8],
                        opCode: UInt16 = 0x5000) -> [UInt8] {
        let length = UInt16(levels.count)
        var bytes: [UInt8] = Array("Art-Net".utf8)
        bytes.append(0)
        bytes += [UInt8(opCode & 0xFF), UInt8(opCode >> 8)]
        bytes += [0, 14]  // protocol version 14
        bytes += [sequence, 0, subUni, net]
        bytes += [UInt8(length >> 8), UInt8(length & 0xFF)]
        return bytes + levels
    }

    func testParsesUniverseSequenceAndLevels() throws {
        let parsed = try XCTUnwrap(ArtDmxPacket(bytes: packet(net: 1, subUni: 0x23, sequence: 7, levels: [255, 128, 0, 10])))
        XCTAssertEqual(parsed.universe, 0x123)
        XCTAssertEqual(parsed.sequence, 7)
        XCTAssertEqual(parsed.level(channel: 1), 255)
        XCTAssertEqual(parsed.level(channel: 2), 128)
        XCTAssertEqual(parsed.level(channel: 4), 10)
    }

    func testPadsShortPacketsTo512Channels() throws {
        let parsed = try XCTUnwrap(ArtDmxPacket(bytes: packet(levels: [1, 2])))
        XCTAssertEqual(parsed.levels.count, 512)
        XCTAssertEqual(parsed.level(channel: 512), 0)
    }

    func testFullUniverse() throws {
        let levels = (0..<512).map { UInt8($0 % 256) }
        let parsed = try XCTUnwrap(ArtDmxPacket(bytes: packet(levels: levels)))
        XCTAssertEqual(parsed.levels, levels)
    }

    func testChannelOutOfRangeReadsZero() throws {
        let parsed = try XCTUnwrap(ArtDmxPacket(bytes: packet(levels: [9])))
        XCTAssertEqual(parsed.level(channel: 0), 0)
        XCTAssertEqual(parsed.level(channel: 513), 0)
    }

    func testRejectsOtherOpCodes() {
        let artPoll: UInt16 = 0x2000
        XCTAssertNil(ArtDmxPacket(bytes: packet(levels: [1], opCode: artPoll)))
    }

    func testRejectsWrongHeader() {
        var bytes = packet(levels: [1])
        bytes[0] = UInt8(ascii: "X")
        XCTAssertNil(ArtDmxPacket(bytes: bytes))
    }

    func testRejectsTruncatedPackets() {
        let bytes = packet(levels: [1, 2, 3, 4])
        XCTAssertNil(ArtDmxPacket(bytes: bytes.dropLast()))
        XCTAssertNil(ArtDmxPacket(bytes: bytes.prefix(10)))
    }

    func testRejectsEmptyAndOversizedLengths() {
        XCTAssertNil(ArtDmxPacket(bytes: packet(levels: [])))
        XCTAssertNil(ArtDmxPacket(bytes: packet(levels: Array(repeating: 0, count: 513))))
    }

    func testUniverseLabel() {
        XCTAssertEqual(ArtDmxPacket.label(universe: 0), "Net 0, Sub-Net 0, Universe 0")
        XCTAssertEqual(ArtDmxPacket.label(universe: 0x123), "Net 1, Sub-Net 2, Universe 3")
    }
}
