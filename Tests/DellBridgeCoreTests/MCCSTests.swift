import XCTest
@testable import DellBridgeCore

final class MCCSTests: XCTestCase {
    func testSetBrightness50() {
        XCTAssertEqual(
            MCCS.setVCP(VCP.brightness.rawValue, value: 50),
            [0x51, 0x84, 0x03, 0x10, 0x00, 0x32, 0x9A]
        )
    }

    func testSetContrast75() {
        XCTAssertEqual(
            MCCS.setVCP(VCP.contrast.rawValue, value: 75),
            [0x51, 0x84, 0x03, 0x12, 0x00, 0x4B, 0xE1]
        )
    }

    func testSetVolumeZero() {
        XCTAssertEqual(
            MCCS.setVCP(VCP.volume.rawValue, value: 0),
            [0x51, 0x84, 0x03, 0x62, 0x00, 0x00, 0xDA]
        )
    }

    func testSetInputUSBC() {
        XCTAssertEqual(
            MCCS.setVCP(VCP.inputSource.rawValue, value: InputSource.usbC.rawValue),
            [0x51, 0x84, 0x03, 0x60, 0x00, 0x1B, 0xC3]
        )
    }

    func testGetBrightness() {
        XCTAssertEqual(
            MCCS.getVCP(VCP.brightness.rawValue),
            [0x51, 0x82, 0x01, 0x10, 0xAC]
        )
    }

    func testChecksumMakesRequestXorToMonitorAddress() {
        XCTAssertEqual(MCCS.setVCP(VCP.brightness.rawValue, value: 50).reduce(UInt8(0), ^), MCCS.monitorAddress)
        XCTAssertEqual(MCCS.getVCP(VCP.brightness.rawValue).reduce(UInt8(0), ^), MCCS.monitorAddress)
    }

    func testHexString() {
        XCTAssertEqual(
            MCCS.hexString([0x51, 0x82, 0x01, 0x10, 0xAC]),
            "51 82 01 10 AC"
        )
    }
}
