import XCTest
@testable import DellBridgeCore

final class ProfileTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // DellBridgeCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repository root
    }

    func testLoadS2725QCProfile() throws {
        let url = repositoryRoot.appendingPathComponent("profiles/s2725qc.json")
        let profile = try ProfileStore.load(from: url)

        XCTAssertEqual(profile.id, "dell-s2725qc")
        XCTAssertEqual(profile.vcp.brightness, VCP.brightness.rawValue)
        XCTAssertEqual(profile.vcp.contrast, VCP.contrast.rawValue)
        XCTAssertEqual(profile.vcp.inputSource, VCP.inputSource.rawValue)
        XCTAssertEqual(profile.inputs["usb-c"], InputSource.usbC.rawValue)
        XCTAssertFalse(profile.verified, "profiles must stay unverified until hardware evidence exists")
    }

    func testMatchByManufacturerAndModel() throws {
        let profile = try ProfileStore.load(
            from: repositoryRoot.appendingPathComponent("profiles/s2725qc.json")
        )

        let match = ProfileStore.match(
            [profile],
            manufacturer: "DEL",
            model: "DELL S2725QC"
        )
        XCTAssertEqual(match?.id, profile.id)
    }

    func testMatchRejectsOtherModel() throws {
        let profile = try ProfileStore.load(
            from: repositoryRoot.appendingPathComponent("profiles/s2725qc.json")
        )

        XCTAssertNil(
            ProfileStore.match([profile], manufacturer: "DEL", model: "U2723QE")
        )
    }

    func testMalformedDirectoryLoadReportsErrors() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("broken.json"))

        let result = ProfileStore.loadAll(in: directory)
        XCTAssertTrue(result.profiles.isEmpty)
        XCTAssertEqual(result.errors.count, 1)

        try? FileManager.default.removeItem(at: directory)
    }
}
