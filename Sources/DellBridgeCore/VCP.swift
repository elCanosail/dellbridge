import Foundation

/// MCCS Virtual Control Panel codes used by dellbridge.
public enum VCP: UInt8, CaseIterable {
    case brightness = 0x10
    case contrast = 0x12
    case colorPreset = 0x14
    case inputSource = 0x60
    case volume = 0x62
    case mute = 0x8D
    case powerMode = 0xD6
}

/// Input source values for VCP 0x60. Values are the MCCS standard ones;
/// Dell monitors generally follow them, but each model profile is validated
/// against real hardware before being marked verified.
public enum InputSource: UInt16, CaseIterable {
    case displayPort1 = 15
    case displayPort2 = 16
    case hdmi1 = 17
    case hdmi2 = 18
    case usbC = 27
}
