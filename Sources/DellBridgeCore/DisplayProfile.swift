import Foundation

/// Per-model description of the VCP codes and quirks a display needs.
///
/// Profiles are hypotheses until `verified` is true. A profile is only marked
/// verified after the M0/M1 checks pass on real hardware and the evidence is
/// linked in `docs/compatibility.md`.
public struct DisplayProfile: Codable, Equatable {
    public struct Match: Codable, Equatable {
        /// EDID manufacturer id, e.g. `DEL`.
        public let manufacturer: String
        /// Marketing model name as reported by the display or EDID.
        public let model: String
        /// EDID product code as hex, when known. Never guessed.
        public let productCode: String?

        public init(manufacturer: String, model: String, productCode: String? = nil) {
            self.manufacturer = manufacturer
            self.model = model
            self.productCode = productCode
        }
    }

    public struct VCPMap: Codable, Equatable {
        public let brightness: UInt8
        public let contrast: UInt8
        public let volume: UInt8?
        public let inputSource: UInt8
        public let mute: UInt8?

        public init(brightness: UInt8, contrast: UInt8, volume: UInt8?, inputSource: UInt8, mute: UInt8?) {
            self.brightness = brightness
            self.contrast = contrast
            self.volume = volume
            self.inputSource = inputSource
            self.mute = mute
        }
    }

    public struct Quirks: Codable, Equatable {
        /// Minimum gap between two DDC writes, in milliseconds.
        public let writeDelayMilliseconds: Int
        /// True when the display ignores VCP 0x10 while HDR content is active.
        public let brightnessLockedInHDR: Bool
        /// True when the last brightness value must be re-applied after wake.
        public let reapplyAfterWake: Bool
        public let notes: [String]

        public init(writeDelayMilliseconds: Int, brightnessLockedInHDR: Bool, reapplyAfterWake: Bool, notes: [String]) {
            self.writeDelayMilliseconds = writeDelayMilliseconds
            self.brightnessLockedInHDR = brightnessLockedInHDR
            self.reapplyAfterWake = reapplyAfterWake
            self.notes = notes
        }
    }

    public let id: String
    public let displayName: String
    public let match: Match
    public let vcp: VCPMap
    /// Input name to VCP 0x60 value.
    public let inputs: [String: UInt16]
    public let quirks: Quirks
    public let verified: Bool
}
