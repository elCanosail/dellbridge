import Foundation

/// Transport-independent description of an online display.
public struct DisplayInfo: Equatable {
    public let id: UInt32
    public let vendor: UInt32
    public let model: UInt32
    public let serial: UInt32
    public let productName: String?
    public let manufacturer: String?
    public let edidUUID: String?
    public let isExternal: Bool

    public init(
        id: UInt32,
        vendor: UInt32,
        model: UInt32,
        serial: UInt32,
        productName: String?,
        manufacturer: String?,
        edidUUID: String?,
        isExternal: Bool
    ) {
        self.id = id
        self.vendor = vendor
        self.model = model
        self.serial = serial
        self.productName = productName
        self.manufacturer = manufacturer
        self.edidUUID = edidUUID
        self.isExternal = isExternal
    }

    /// `DEL:0x1234:0x5678` style identifier, stable across reboots.
    public var identifier: String {
        String(format: "%u:%u:%u", vendor, model, serial)
    }
}
