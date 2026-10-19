import Foundation
import DellBridgeCore

private func usage() -> String {
    """
    dellctl — DDC/CI control for Dell monitors on macOS

    USAGE
      dellctl packet get <vcp-hex>
      dellctl packet set <vcp-hex> <value>
      dellctl version

    The `packet` commands only encode the MCCS message and print it as hex.
    The I2C/IOAVService transport is scheduled for milestone M1.

    EXAMPLES
      dellctl packet get 10          # Get VCP 0x10 (brightness)
      dellctl packet set 10 50       # Set VCP 0x10 to 50
    """
}

private func parseHexByte(_ raw: String) -> UInt8? {
    let cleaned = raw.lowercased().hasPrefix("0x") ? String(raw.dropFirst(2)) : raw
    return UInt8(cleaned, radix: 16)
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: " + message + "\n").utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())

guard let command = args.first else {
    print(usage())
    exit(0)
}

switch command {
case "packet":
    guard args.count >= 3 else { fail("packet requires a mode and a VCP code") }
    let mode = args[1]
    guard let code = parseHexByte(args[2]) else { fail("invalid VCP code: \(args[2])") }

    switch mode {
    case "get":
        print(MCCS.hexString(MCCS.getVCP(code)))
    case "set":
        guard args.count == 4 else { fail("packet set requires a value") }
        guard let value = UInt16(args[3]) else { fail("invalid value: \(args[3])") }
        print(MCCS.hexString(MCCS.setVCP(code, value: value)))
    default:
        fail("unknown packet mode: \(mode)")
    }

case "version":
    print("dellctl 0.1.0 (M0)")

case "help", "--help", "-h":
    print(usage())

default:
    fail("unknown command: \(command)")
}
