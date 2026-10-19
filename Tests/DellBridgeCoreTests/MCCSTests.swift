import XCTest
@testable import DellBridgeCore

final class MCCSTests: XCTestCase {
    func testGetBrightnessRequest() {
        XCTAssertEqual(
            MCCS.getVCPRequest(VCP.brightness.rawValue),
            [0x82, 0x01, 0x10, 0xFD]
        )
    }

    func testSetBrightness50Request() {
        XCTAssertEqual(
            MCCS.setVCPRequest(VCP.brightness.rawValue, value: 50),
            [0x84, 0x03, 0x10, 0x00, 0x32, 0x9A]
        )
    }

    func testSetContrast75Request() {
        XCTAssertEqual(
            MCCS.setVCPRequest(VCP.contrast.rawValue, value: 75),
            [0x84, 0x03, 0x12, 0x00, 0x4B, 0xE1]
        )
    }

    func testSetVolumeZeroRequest() {
        XCTAssertEqual(
            MCCS.setVCPRequest(VCP.volume.rawValue, value: 0),
            [0x84, 0x03, 0x62, 0x00, 0x00, 0xDA]
        )
    }

    func testSetInputUSBCRequest() {
        XCTAssertEqual(
            MCCS.setVCPRequest(VCP.inputSource.rawValue, value: InputSource.usbC.rawValue),
            [0x84, 0x03, 0x60, 0x00, 0x1B, 0xC3]
        )
    }

    func testSetRequestXorIncludesHostAddress() {
        let packet = MCCS.setVCPRequest(VCP.brightness.rawValue, value: 50)
        XCTAssertEqual(([MCCS.hostAddress] + packet).reduce(UInt8(0), ^), MCCS.monitorAddress)
    }

    func testParseReply() throws {
        let reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0xF3]
        let parsed = try MCCS.parseVCPReply(reply, expecting: VCP.brightness.rawValue)
        XCTAssertEqual(parsed.code, VCP.brightness.rawValue)
        XCTAssertEqual(parsed.result, 0)
        XCTAssertEqual(parsed.current, 50)
        XCTAssertEqual(parsed.maximum, 100)
        XCTAssertTrue(parsed.checksumValid)
    }

    func testParseReplyReportsBadChecksumWithoutThrowing() throws {
        var reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0xF3]
        reply[10] = 0x00
        let parsed = try MCCS.parseVCPReply(reply, expecting: VCP.brightness.rawValue)
        XCTAssertFalse(parsed.checksumValid)
        XCTAssertEqual(parsed.current, 50)
    }

    func testParseReplyRejectsWrongVCP() {
        let reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x12, 0x00, 0x00, 0x64, 0x00, 0x32, 0xF3]
        XCTAssertThrowsError(try MCCS.parseVCPReply(reply, expecting: VCP.brightness.rawValue)) { error in
            XCTAssertEqual(
                error as? MCCS.ReplyError,
                .wrongVCP(expected: VCP.brightness.rawValue, got: VCP.contrast.rawValue)
            )
        }
    }

    func testParseReplyRejectsShortBuffer() {
        XCTAssertThrowsError(try MCCS.parseVCPReply([0x6E, 0x88, 0x02])) { error in
            XCTAssertEqual(error as? MCCS.ReplyError, .tooShort(3))
        }
    }

    func testHexString() {
        XCTAssertEqual(
            MCCS.hexString([0x84, 0x03, 0x10, 0x00, 0x32, 0x9A]),
            "84 03 10 00 32 9A"
        )
    }
}
