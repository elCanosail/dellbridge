import Foundation

/// A decoded VCP value.
public struct VCPValue: Equatable {
    public let code: UInt8
    public let current: UInt16
    public let maximum: UInt16

    public init(code: UInt8, current: UInt16, maximum: UInt16) {
        self.code = code
        self.current = current
        self.maximum = maximum
    }

    public var percent: Int {
        guard maximum > 0 else { return 0 }
        return Int((Double(current) / Double(maximum) * 100).rounded())
    }
}

/// Hardware abstraction. Implementations must be safe to call from one thread
/// at a time; `DDCClient` serializes access.
public protocol DDCTransport: AnyObject {
    func readVCP(_ code: UInt8) throws -> MCCS.VCPReply
    func writeVCP(_ code: UInt8, value: UInt16) throws
}

public enum DDCError: Error, Equatable {
    /// IOReturn from IOKit.
    case ioKit(Int32)
    /// Non-zero result code in the DDC/CI reply (1 = unsupported VCP, 2 = invalid value).
    case displayError(UInt8)
    case noExternalDisplay
    case unsupported(String)
}

extension DDCError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ioKit(let code):
            return "IOKit error \(code)"
        case .displayError(let code):
            return "display rejected the command (DDC result \(code))"
        case .noExternalDisplay:
            return "no external display with DDC support found"
        case .unsupported(let message):
            return message
        }
    }
}
