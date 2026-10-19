import Foundation

/// Encoding and decoding of DDC/CI (MCCS) messages.
///
/// Wire format note: requests are written to the monitor at I2C offset `0x51`
/// (the host address). The source address is therefore *not* part of the
/// request buffer for reads, and it participates in the checksum only for
/// writes. This matches the behaviour of `m1ddc` (MIT), which is the reference
/// implementation this project validates against.
public enum MCCS {
    /// Host address, also used as the I2C data offset for requests.
    public static let hostAddress: UInt8 = 0x51

    /// Monitor address. Checksums are chosen so the logical message XORs to
    /// the destination address.
    public static let monitorAddress: UInt8 = 0x6E

    public enum Opcode: UInt8 {
        case getVCPFeature = 0x01
        case getVCPReply = 0x02
        case setVCPFeature = 0x03
    }

    /// XOR checksum over `bytes` such that the full message XORs to `destination`.
    public static func checksum(_ bytes: [UInt8], destination: UInt8 = monitorAddress) -> UInt8 {
        bytes.reduce(destination) { $0 ^ $1 }
    }

    /// `Get VCP Feature` request: `82 01 <vcp> <checksum>`, written at offset 0x51.
    public static func getVCPRequest(_ code: UInt8) -> [UInt8] {
        var packet: [UInt8] = [0x82, Opcode.getVCPFeature.rawValue, code]
        packet.append(checksum(packet))
        return packet
    }

    /// `Set VCP Feature` request: `84 03 <vcp> <hi> <lo> <checksum>`.
    /// The I2C `address` participates in the checksum, matching m1ddc.
    public static func setVCPRequest(
        _ code: UInt8,
        value: UInt16,
        address: UInt8 = hostAddress
    ) -> [UInt8] {
        var packet: [UInt8] = [
            0x84,
            Opcode.setVCPFeature.rawValue,
            code,
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ]
        packet.append(checksum([address] + packet))
        return packet
    }

    /// Decoded `Get VCP Feature Reply`.
    ///
    /// Reply layout: `6E 88 02 <result> <vcp> <type> <maxHi> <maxLo> <curHi>
    /// <curLo> <checksum>`. The checksum is validated but not enforced: some
    /// panels return a sloppy checksum while the payload is correct. Callers
    /// can see the flag and decide.
    public struct VCPReply: Equatable {
        public let code: UInt8
        public let result: UInt8
        public let current: UInt16
        public let maximum: UInt16
        public let checksumValid: Bool

        public init(code: UInt8, result: UInt8, current: UInt16, maximum: UInt16, checksumValid: Bool) {
            self.code = code
            self.result = result
            self.current = current
            self.maximum = maximum
            self.checksumValid = checksumValid
        }
    }

    public enum ReplyError: Error, Equatable {
        case tooShort(Int)
        case wrongOpcode(UInt8)
        case wrongVCP(expected: UInt8, got: UInt8)
    }

    public static func parseVCPReply(_ bytes: [UInt8], expecting code: UInt8? = nil) throws -> VCPReply {
        guard bytes.count >= 11 else { throw ReplyError.tooShort(bytes.count) }
        guard bytes[2] == Opcode.getVCPReply.rawValue else {
            throw ReplyError.wrongOpcode(bytes[2])
        }
        if let expected = code, bytes[4] != expected {
            throw ReplyError.wrongVCP(expected: expected, got: bytes[4])
        }

        let expectedChecksum = checksum(Array(bytes[0..<10]), destination: hostAddress)
        let maximum = UInt16(bytes[6]) << 8 | UInt16(bytes[7])
        let current = UInt16(bytes[8]) << 8 | UInt16(bytes[9])

        return VCPReply(
            code: bytes[4],
            result: bytes[3],
            current: current,
            maximum: maximum,
            checksumValid: bytes[10] == expectedChecksum
        )
    }

    /// Human-readable hex dump, e.g. `84 03 10 00 32 9A`.
    public static func hexString(_ packet: [UInt8]) -> String {
        packet.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
