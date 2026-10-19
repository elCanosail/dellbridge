import XCTest
@testable import DellBridgeCore

private final class FakeTransport: DDCTransport {
    var values: [UInt8: UInt16] = [:]
    var maximum: UInt16 = 100
    var writes: [(code: UInt8, value: UInt16)] = []
    var failWrites = false
    var writeAttempts = 0

    func readVCP(_ code: UInt8) throws -> MCCS.VCPReply {
        guard let value = values[code] else {
            return MCCS.VCPReply(code: code, result: 1, current: 0, maximum: maximum, checksumValid: true)
        }
        return MCCS.VCPReply(code: code, result: 0, current: value, maximum: maximum, checksumValid: true)
    }

    func writeVCP(_ code: UInt8, value: UInt16) throws {
        writeAttempts += 1
        if failWrites {
            throw DDCError.ioKit(-1)
        }
        values[code] = value
        writes.append((code, value))
    }
}

final class DDCClientTests: XCTestCase {
    func testReadReturnsValue() throws {
        let transport = FakeTransport()
        transport.values[VCP.brightness.rawValue] = 42
        let client = DDCClient(transport: transport, writeDelayMilliseconds: 0)

        let value = try client.read(VCP.brightness.rawValue)
        XCTAssertEqual(value.current, 42)
        XCTAssertEqual(value.maximum, 100)
        XCTAssertEqual(value.percent, 42)
    }

    func testUnsupportedVCPThrowsDisplayError() {
        let transport = FakeTransport()
        let client = DDCClient(transport: transport, writeDelayMilliseconds: 0)

        XCTAssertThrowsError(try client.read(VCP.volume.rawValue)) { error in
            XCTAssertEqual(error as? DDCError, .displayError(1))
        }
    }

    func testChangeClampsAtMaximum() throws {
        let transport = FakeTransport()
        transport.values[VCP.brightness.rawValue] = 95
        let client = DDCClient(transport: transport, writeDelayMilliseconds: 0)

        let value = try client.change(VCP.brightness.rawValue, by: 10)
        XCTAssertEqual(value.current, 100)
        XCTAssertEqual(transport.writes.last?.value, 100)
    }

    func testChangeClampsAtZero() throws {
        let transport = FakeTransport()
        transport.values[VCP.brightness.rawValue] = 3
        let client = DDCClient(transport: transport, writeDelayMilliseconds: 0)

        let value = try client.change(VCP.brightness.rawValue, by: -10)
        XCTAssertEqual(value.current, 0)
    }

    func testSetPercentMapsToMonitorMaximum() throws {
        let transport = FakeTransport()
        transport.values[VCP.brightness.rawValue] = 0
        transport.maximum = 255
        let client = DDCClient(transport: transport, writeDelayMilliseconds: 0)

        let value = try client.setPercent(VCP.brightness.rawValue, percent: 50)
        XCTAssertEqual(value.current, 128)
        XCTAssertEqual(transport.writes.last?.value, 128)
    }

    func testWriteRetriesOnceThenThrows() {
        let transport = FakeTransport()
        transport.failWrites = true
        let client = DDCClient(transport: transport, writeDelayMilliseconds: 0, writeAttempts: 2)

        XCTAssertThrowsError(try client.write(VCP.brightness.rawValue, value: 10))
        XCTAssertEqual(transport.writeAttempts, 2)
    }
}
