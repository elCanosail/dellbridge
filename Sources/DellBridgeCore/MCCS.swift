import Foundation

/// Encoding of DDC/CI (MCCS) messages as used over I2C on Apple Silicon.
///
/// Packet layout follows the de-facto implementation used by `m1ddc`
/// (MIT, https://github.com/waydabber/m1ddc) and the VESA MCCS specification.
/// The transport itself (IOAVService) lands in M1; this type is pure Swift so
/// the protocol layer can be tested without hardware.
public enum MCCS {
    /// Host address used as the first byte of every request.
    public static let hostAddress: UInt8 = 0x51

    /// Monitor address. The checksum is chosen so the XOR of the complete
    /// request equals this byte.
    public static let monitorAddress: UInt8 = 0x6E

    public enum Opcode: UInt8 {
        case getVCPFeature = 0x01
        case setVCPFeature = 0x03
    }

    /// XOR checksum over `bytes` such that the full message XORs to `destination`.
    public static func checksum(_ bytes: [UInt8], destination: UInt8 = monitorAddress) -> UInt8 {
        bytes.reduce(destination) { $0 ^ $1 }
    }

    /// `Set VCP Feature` request: `51 84 03 <vcp> <hi> <lo> <checksum>`.
    public static func setVCP(_ code: UInt8, value: UInt16) -> [UInt8] {
        var packet: [UInt8] = [
            hostAddress,
            0x84, // 0x80 | 4 payload bytes: opcode, VCP, value high, value low
            Opcode.setVCPFeature.rawValue,
            code,
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ]
        packet.append(checksum(packet))
        return packet
    }

    /// `Get VCP Feature` request: `51 82 01 <vcp> <checksum>`.
    public static func getVCP(_ code: UInt8) -> [UInt8] {
        var packet: [UInt8] = [
            hostAddress,
            0x82, // 0x80 | 2 payload bytes: opcode, VCP
            Opcode.getVCPFeature.rawValue,
            code,
        ]
        packet.append(checksum(packet))
        return packet
    }

    /// Human-readable hex dump, e.g. `51 84 03 10 00 32 9A`.
    public static func hexString(_ packet: [UInt8]) -> String {
        packet.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
