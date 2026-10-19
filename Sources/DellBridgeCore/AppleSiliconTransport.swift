#if os(macOS)
import Foundation
import CoreGraphics
import IOKit

// Private symbols. Declared here exactly as the working reference
// implementation (m1ddc, MIT) does; there is no public header for IOAVService.

@_silgen_name("CoreDisplay_DisplayCreateInfoDictionary")
private func CoreDisplay_DisplayCreateInfoDictionary(_ display: CGDirectDisplayID) -> Unmanaged<CFDictionary>?

@_silgen_name("IOAVServiceCreateWithService")
private func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> Unmanaged<AnyObject>?

@_silgen_name("IOAVServiceReadI2C")
private func IOAVServiceReadI2C(
    _ service: CFTypeRef,
    _ chipAddress: UInt32,
    _ offset: UInt32,
    _ buffer: UnsafeMutableRawPointer?,
    _ length: UInt32
) -> IOReturn

@_silgen_name("IOAVServiceWriteI2C")
private func IOAVServiceWriteI2C(
    _ service: CFTypeRef,
    _ chipAddress: UInt32,
    _ offset: UInt32,
    _ buffer: UnsafeMutableRawPointer?,
    _ length: UInt32
) -> IOReturn

private func registryProperty(_ service: io_service_t, _ key: String) -> CFTypeRef? {
    IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
}

private func isMCDP29XXProxy(_ proxy: io_service_t) -> Bool {
    var parent: io_registry_entry_t = 0
    guard IORegistryEntryGetParentEntry(proxy, kIOServicePlane, &parent) == KERN_SUCCESS else {
        return false
    }
    defer { IOObjectRelease(parent) }

    guard let value = registryProperty(parent, "EPICProviderClass") else { return false }
    guard CFGetTypeID(value) == CFStringGetTypeID() else { return false }
    return CFStringCompare(value as! CFString, "AppleDCPMCDP29XX" as CFString, 0) == .compareEqualTo
}

/// Online display enumeration. Mirrors m1ddc's IORegistry walk: find the
/// IOMobileFramebuffer that matches the adapter, then its DCPAVServiceProxy.
public enum AppleSiliconDisplays {
    public static func all() -> [DisplayInfo] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success else {
            return []
        }

        return ids.prefix(Int(count)).compactMap { id in
            guard let cf = CoreDisplay_DisplayCreateInfoDictionary(id)?.takeRetainedValue() else {
                return nil
            }
            let info = cf as NSDictionary
            guard let location = info["IODisplayLocation"] as? String else { return nil }

            let adapter = IORegistryEntryCopyFromPath(kIOMainPortDefault, location as CFString)
            guard adapter != 0 else { return nil }
            defer { IOObjectRelease(adapter) }

            var productName: String?
            var manufacturer: String?
            if let attrs = registryProperty(adapter, "DisplayAttributes") as? NSDictionary,
               let product = attrs["ProductAttributes"] as? NSDictionary {
                productName = product["ProductName"] as? String
                manufacturer = product["ManufacturerID"] as? String
            }

            return DisplayInfo(
                id: id,
                vendor: CGDisplayVendorNumber(id),
                model: CGDisplayModelNumber(id),
                serial: CGDisplaySerialNumber(id),
                productName: productName,
                manufacturer: manufacturer,
                edidUUID: registryProperty(adapter, "EDID UUID") as? String,
                isExternal: CGDisplayIsBuiltin(id) == 0
            )
        }
    }
}

/// DDC/CI transport for Apple Silicon, behind the private IOAVService API.
///
/// The IORegistry walk and chip-address handling are ported from m1ddc (MIT).
/// Hardware validation is tracked in docs/plans/m0-feasibility.md; until a
/// device report exists this code path is "drafted, unverified".
public final class AppleSiliconTransport: DDCTransport {
    private let service: AnyObject
    private let chipAddress: UInt32
    private let inputAddress: UInt32
    private let readWait: TimeInterval

    public init(display: DisplayInfo) throws {
        let resolved = try Self.resolve(displayID: display.id)
        self.service = resolved.service
        self.chipAddress = resolved.chipAddress
        self.inputAddress = UInt32(MCCS.hostAddress)
        self.readWait = resolved.isMCDP ? 0.05 : 0.01
    }

    public func readVCP(_ code: UInt8) throws -> MCCS.VCPReply {
        let request = MCCS.getVCPRequest(code)
        try writeBuffer(request, offset: inputAddress)
        Thread.sleep(forTimeInterval: readWait)

        var reply = [UInt8](repeating: 0, count: 12)
        let length = UInt32(reply.count)
        let result = reply.withUnsafeMutableBytes { buffer -> IOReturn in
            guard let base = buffer.baseAddress else { return -1 }
            return IOAVServiceReadI2C(service, chipAddress, inputAddress, base, length)
        }
        guard result == KERN_SUCCESS else { throw DDCError.ioKit(result) }
        return try MCCS.parseVCPReply(reply, expecting: code)
    }

    public func writeVCP(_ code: UInt8, value: UInt16) throws {
        let payload = MCCS.setVCPRequest(code, value: value, address: UInt8(inputAddress))
        try writeBuffer(payload, offset: inputAddress)
    }

    private func writeBuffer(_ bytes: [UInt8], offset: UInt32) throws {
        var copy = bytes
        let length = UInt32(copy.count)
        let result = copy.withUnsafeMutableBytes { buffer -> IOReturn in
            guard let base = buffer.baseAddress else { return -1 }
            return IOAVServiceWriteI2C(service, chipAddress, offset, base, length)
        }
        guard result == KERN_SUCCESS else { throw DDCError.ioKit(result) }
    }

    private static func resolve(
        displayID: UInt32
    ) throws -> (service: AnyObject, chipAddress: UInt32, isMCDP: Bool) {
        guard let cf = CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() else {
            throw DDCError.unsupported("display \(displayID) has no CoreDisplay info")
        }
        let info = cf as NSDictionary
        guard let location = info["IODisplayLocation"] as? String else {
            throw DDCError.unsupported("display \(displayID) has no IODisplayLocation")
        }

        let adapter = IORegistryEntryCopyFromPath(kIOMainPortDefault, location as CFString)
        guard adapter != 0 else {
            throw DDCError.unsupported("cannot open display adapter")
        }
        defer { IOObjectRelease(adapter) }

        var adapterID: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(adapter, &adapterID) == KERN_SUCCESS else {
            throw DDCError.unsupported("cannot read adapter registry id")
        }

        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard root != 0 else { throw DDCError.unsupported("cannot open IORegistry root") }
        defer { IOObjectRelease(root) }

        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(
            root,
            kIOServicePlane,
            IOOptionBits(kIORegistryIterateRecursively),
            &iterator
        ) == KERN_SUCCESS else {
            throw DDCError.unsupported("cannot iterate IORegistry")
        }
        defer { IOObjectRelease(iterator) }

        var framebufferMatches = false
        var entry = IOIteratorNext(iterator)

        while entry != 0 {
            let current = entry
            entry = IOIteratorNext(iterator)

            if IOObjectConformsTo(current, "IOMobileFramebuffer") != 0 {
                var framebufferID: UInt64 = 0
                framebufferMatches =
                    IORegistryEntryGetRegistryEntryID(current, &framebufferID) == KERN_SUCCESS &&
                    framebufferID == adapterID
                IOObjectRelease(current)
                continue
            }

            var name = [CChar](repeating: 0, count: 128)
            _ = name.withUnsafeMutableBufferPointer { buffer in
                IORegistryEntryGetName(current, buffer.baseAddress)
            }

            guard framebufferMatches, String(cString: name) == "DCPAVServiceProxy" else {
                IOObjectRelease(current)
                continue
            }

            guard let av = IOAVServiceCreateWithService(kCFAllocatorDefault, current)?.takeRetainedValue() else {
                IOObjectRelease(current)
                continue
            }

            let isExternal = (registryProperty(current, "Location") as? String) == "External"
            let isMCDP = isMCDP29XXProxy(current)
            IOObjectRelease(current)

            if isExternal {
                return (av, isMCDP ? 0xB7 : 0x37, isMCDP)
            }
        }

        throw DDCError.noExternalDisplay
    }
}
#endif
