import Foundation
import DellBridgeCore

#if os(macOS)
import Darwin
#else
import Glibc
#endif

private func usage() -> String {
    """
    dellctl — DDC/CI control for Dell monitors on macOS

    USAGE
      dellctl list
      dellctl get <vcp> [--display <id>]
      dellctl set <vcp> <value> [--display <id>]
      dellctl input <usb-c|hdmi-1|hdmi-2> [--display <id>]
      dellctl profile <path>
      dellctl packet get <vcp-hex>
      dellctl packet set <vcp-hex> <value>
      dellctl version

    VCP may be a name (brightness, contrast, volume, input, mute) or hex (0x10).
    `packet` only encodes the wire payload and prints it as hex, useful without
    hardware. Display control requires macOS.
    """
}

private func parseHexByte(_ raw: String) -> UInt8? {
    let cleaned = raw.lowercased().hasPrefix("0x") ? String(raw.dropFirst(2)) : raw
    return UInt8(cleaned, radix: 16)
}

private func vcpCode(_ raw: String) -> UInt8? {
    switch raw.lowercased() {
    case "brightness", "luminance":
        return VCP.brightness.rawValue
    case "contrast":
        return VCP.contrast.rawValue
    case "volume":
        return VCP.volume.rawValue
    case "input":
        return VCP.inputSource.rawValue
    case "mute":
        return VCP.mute.rawValue
    default:
        return parseHexByte(raw)
    }
}

private func inputValue(_ raw: String) -> UInt16? {
    switch raw.lowercased() {
    case "usb-c", "usbc", "usb":
        return InputSource.usbC.rawValue
    case "hdmi-1", "hdmi1":
        return InputSource.hdmi1.rawValue
    case "hdmi-2", "hdmi2":
        return InputSource.hdmi2.rawValue
    case "dp-1", "dp1":
        return InputSource.displayPort1.rawValue
    case "dp-2", "dp2":
        return InputSource.displayPort2.rawValue
    default:
        return UInt16(raw)
    }
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: " + message + "\n").utf8))
    exit(1)
}

private func extractDisplay(_ args: inout [String]) -> String? {
    guard let index = args.firstIndex(of: "--display") else { return nil }
    guard index + 1 < args.count else { fail("--display requires an id") }
    let value = args[index + 1]
    args.removeSubrange(index...(index + 1))
    return value
}

#if os(macOS)
private func makeTransport(selector: String?) throws -> DDCTransport {
    let displays = AppleSiliconDisplays.all()

    if let selector {
        guard let id = UInt32(selector) else {
            throw DDCError.unsupported("invalid display id: \(selector)")
        }
        guard let match = displays.first(where: { $0.id == id }) else {
            throw DDCError.unsupported("no display with id \(id)")
        }
        return try AppleSiliconTransport(display: match)
    }

    guard let external = displays.first(where: { $0.isExternal }) else {
        throw DDCError.noExternalDisplay
    }
    return try AppleSiliconTransport(display: external)
}
#endif

let args = Array(CommandLine.arguments.dropFirst())

guard let command = args.first else {
    print(usage())
    exit(0)
}

switch command {
case "list":
    #if os(macOS)
    let displays = AppleSiliconDisplays.all()
    if displays.isEmpty {
        print("no displays")
    }
    for (index, display) in displays.enumerated() {
        let name = display.productName ?? "Unknown"
        let kind = display.isExternal ? "external" : "built-in"
        print(String(format: "%d  id=%u  %@  %@  %@", index + 1, display.id, name, display.identifier, kind))
    }
    #else
    fail("display enumeration requires macOS")
    #endif

case "get":
    var rest = Array(args.dropFirst())
    let selector = extractDisplay(&rest)
    guard let raw = rest.first, let code = vcpCode(raw) else {
        fail("get requires a VCP code")
    }
    #if os(macOS)
    do {
        let client = DDCClient(transport: try makeTransport(selector: selector))
        let value = try client.read(code)
        print("\(value.current)/\(value.maximum)")
    } catch {
        fail(error.localizedDescription)
    }
    #else
    fail("DDC transport requires macOS")
    #endif

case "set":
    var rest = Array(args.dropFirst())
    let selector = extractDisplay(&rest)
    guard rest.count >= 2, let code = vcpCode(rest[0]) else {
        fail("set requires a VCP code and a value")
    }
    let rawValue = rest[1]
    let parsed: UInt16?
    if code == VCP.inputSource.rawValue {
        parsed = inputValue(rawValue)
    } else {
        parsed = UInt16(rawValue)
    }
    guard let value = parsed else { fail("invalid value: \(rawValue)") }
    #if os(macOS)
    do {
        let client = DDCClient(transport: try makeTransport(selector: selector))
        try client.write(code, value: value)
        let label = code == VCP.inputSource.rawValue ? "input" : "vcp 0x" + String(format: "%02X", code)
        print("\(label) set to \(value)")
    } catch {
        fail(error.localizedDescription)
    }
    #else
    fail("DDC transport requires macOS")
    #endif

case "input":
    var rest = Array(args.dropFirst())
    let selector = extractDisplay(&rest)
    guard let raw = rest.first, let value = inputValue(raw) else {
        fail("input requires usb-c, hdmi-1, hdmi-2, dp-1 or dp-2")
    }
    #if os(macOS)
    do {
        let client = DDCClient(transport: try makeTransport(selector: selector))
        try client.write(VCP.inputSource.rawValue, value: value)
        print("input set to \(raw)")
    } catch {
        fail(error.localizedDescription)
    }
    #else
    fail("DDC transport requires macOS")
    #endif

case "profile":
    guard let path = args.dropFirst().first else { fail("profile requires a path") }
    do {
        let profile = try ProfileStore.load(from: URL(fileURLWithPath: path))
        print("\(profile.id) — \(profile.displayName)")
        print("verified: \(profile.verified)")
        print("brightness: 0x\(String(format: "%02X", profile.vcp.brightness))")
        print("contrast:   0x\(String(format: "%02X", profile.vcp.contrast))")
        if let volume = profile.vcp.volume {
            print("volume:     0x\(String(format: "%02X", volume))")
        }
        print("input:      0x\(String(format: "%02X", profile.vcp.inputSource))")
    } catch {
        fail("cannot load profile: \(error.localizedDescription)")
    }

case "packet":
    var rest = Array(args.dropFirst())
    guard rest.count >= 2, let code = parseHexByte(rest[1]) else {
        fail("packet requires get|set, a VCP code and, for set, a value")
    }
    switch rest[0] {
    case "get":
        print(MCCS.hexString(MCCS.getVCPRequest(code)))
    case "set":
        guard rest.count >= 3, let value = UInt16(rest[2]) else {
            fail("packet set requires a value")
        }
        print(MCCS.hexString(MCCS.setVCPRequest(code, value: value)))
    default:
        fail("unknown packet mode: \(rest[0])")
    }

case "version":
    print("dellctl 0.2.0 (M1 draft)")

case "help", "--help", "-h":
    print(usage())

default:
    fail("unknown command: \(command)")
}
