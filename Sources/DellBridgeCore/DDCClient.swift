import Foundation

/// Serialized access to a `DDCTransport` with the pacing and retry rules that
/// DDC/CI needs. One instance per display; never share a client across displays.
public final class DDCClient {
    private let transport: DDCTransport
    private let lock = NSLock()
    private let writeDelay: TimeInterval
    private let writeAttempts: Int

    public init(transport: DDCTransport, writeDelayMilliseconds: Int = 20, writeAttempts: Int = 2) {
        self.transport = transport
        self.writeDelay = TimeInterval(max(0, writeDelayMilliseconds)) / 1000.0
        self.writeAttempts = max(1, writeAttempts)
    }

    /// Reads a VCP value. Throws `DDCError.displayError` when the monitor
    /// rejects the code.
    public func read(_ code: UInt8) throws -> VCPValue {
        lock.lock()
        defer { lock.unlock() }

        let reply = try transport.readVCP(code)
        guard reply.result == 0 else { throw DDCError.displayError(reply.result) }
        return VCPValue(code: reply.code, current: reply.current, maximum: reply.maximum)
    }

    /// Writes a VCP value. Retries once on transient I/O failure, with pacing.
    public func write(_ code: UInt8, value: UInt16) throws {
        lock.lock()
        defer { lock.unlock() }

        var lastError: Error?
        for attempt in 1...writeAttempts {
            do {
                Thread.sleep(forTimeInterval: writeDelay)
                try transport.writeVCP(code, value: value)
                return
            } catch {
                lastError = error
                if attempt < writeAttempts {
                    Thread.sleep(forTimeInterval: writeDelay)
                }
            }
        }
        throw lastError ?? DDCError.ioKit(-1)
    }

    /// Reads the current value, applies `delta`, clamps to `0...maximum`, writes
    /// it and returns the new value.
    public func change(_ code: UInt8, by delta: Int) throws -> VCPValue {
        let current = try read(code)
        let target = max(0, min(Int(current.maximum), Int(current.current) + delta))
        if target == Int(current.current) {
            return current
        }
        try write(code, value: UInt16(target))
        return VCPValue(code: code, current: UInt16(target), maximum: current.maximum)
    }

    /// Sets a percentage of the monitor's own maximum.
    public func setPercent(_ code: UInt8, percent: Int) throws -> VCPValue {
        let reference = try read(code)
        let clamped = max(0, min(100, percent))
        let value = UInt16((Int(reference.maximum) * clamped + 50) / 100)
        try write(code, value: value)
        return VCPValue(code: code, current: value, maximum: reference.maximum)
    }
}
