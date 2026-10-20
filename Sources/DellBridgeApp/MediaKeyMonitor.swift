#if os(macOS)
import AppKit
import ApplicationServices
import CoreGraphics

private let nxSubtypeAuxControlButtons: Int16 = 8
private let nxKeyTypeBrightnessUp = 2
private let nxKeyTypeBrightnessDown = 3
private let debugLogPath = "/tmp/dellbridge-media.log"

private func debugLog(_ message: String) {
    let line = "\(Date().timeIntervalSince1970) \(message)\n"
    let url = URL(fileURLWithPath: debugLogPath)
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        try? handle.close()
    } else {
        try? Data(line.utf8).write(to: url)
    }
}

/// Intercepts Apple brightness keys through a session event tap.
///
/// The monitor only consumes the brightness key codes. Every other
/// system-defined media key is passed through untouched. If the tap cannot be
/// created (Accessibility permission missing), `start()` returns `false` and
/// the app keeps working through the menu bar.
final class MediaKeyMonitor {
    var onBrightness: ((Int) -> Bool)?

    fileprivate var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var lastHandled: TimeInterval = 0
    private let throttle: TimeInterval = 0.08

    func start() -> Bool {
        stop()

        debugLog("start trusted=\(AXIsProcessTrusted())")
        let tap = makeTap(.cghidEventTap) ?? makeTap(.cgSessionEventTap)
        guard let tap else {
            debugLog("tap creation failed")
            return false
        }
        self.tap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            debugLog("run loop source failed")
            self.tap = nil
            return false
        }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        debugLog("tap created")
        return true
    }

    private func makeTap(_ location: CGEventTapLocation) -> CFMachPort? {
        let mask = CGEventMask(1) << CGEventMask(NSEvent.EventType.systemDefined.rawValue)
        return CGEvent.tapCreate(
            tap: location,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        tap = nil
        source = nil
    }

    fileprivate func handle(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let ns = NSEvent(cgEvent: event),
              ns.type == .systemDefined,
              ns.subtype.rawValue == nxSubtypeAuxControlButtons else {
            debugLog("non-system event type=\(event.type.rawValue)")
            return Unmanaged.passUnretained(event)
        }

        let data1 = ns.data1
        debugLog("systemDefined data1=\(data1)")
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = data1 & 0x0000FFFF
        let keyState = (keyFlags & 0xFF00) >> 8
        let isKeyDown = keyState == 0x0A

        guard keyCode == nxKeyTypeBrightnessUp || keyCode == nxKeyTypeBrightnessDown else {
            return Unmanaged.passUnretained(event)
        }
        if !isKeyDown {
            // Key-up for a key we own; swallow it so the system does not act.
            return nil
        }
        guard onBrightness != nil else {
            return Unmanaged.passUnretained(event)
        }

        let now = ProcessInfo.processInfo.systemUptime
        if now - lastHandled < throttle {
            return nil
        }
        lastHandled = now

        let delta = keyCode == nxKeyTypeBrightnessUp ? 1 : -1
        return (onBrightness?(delta) ?? false) ? nil : Unmanaged.passUnretained(event)
    }
}

private func mediaKeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<MediaKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        debugLog("tap disabled type=\(type.rawValue)")
        if let tap = monitor.tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    return monitor.handle(event: event)
}
#endif
