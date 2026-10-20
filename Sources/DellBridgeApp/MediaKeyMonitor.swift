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

/// Intercepts Apple brightness keys through both a session event tap and
/// NSEvent global/local monitors.
///
/// The event tap can suppress the event when it works. The monitors are the
/// fallback for macOS versions where the media keys are not delivered to the
/// tap; they cannot suppress, but on an external display the system action is
/// harmless and our DDC write is the visible result. A shared throttle avoids
/// double adjustments if both paths see the same key press.
final class MediaKeyMonitor {
    var onBrightness: ((Int) -> Bool)?

    fileprivate var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastHandled: TimeInterval = 0
    private let throttle: TimeInterval = 0.08

    func start() -> Bool {
        stop()

        debugLog("start trusted=\(AXIsProcessTrusted())")

        let tap = makeTap(.cgSessionEventTap) ?? makeTap(.cghidEventTap)
        if let tap {
            self.tap = tap
            if let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) {
                self.source = source
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                debugLog("tap created")
            } else {
                debugLog("run loop source failed")
            }
        } else {
            debugLog("tap creation failed")
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            _ = self?.handle(nsEvent: event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard let self else { return event }
            return self.handle(nsEvent: event) ? nil : event
        }
        debugLog("monitors global=\(globalMonitor != nil) local=\(localMonitor != nil)")

        return tap != nil || globalMonitor != nil || localMonitor != nil
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        tap = nil
        source = nil
        globalMonitor = nil
        localMonitor = nil
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

    fileprivate func handle(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let ns = NSEvent(cgEvent: event) else {
            debugLog("NSEvent nil cgtype=\(event.type.rawValue)")
            return Unmanaged.passUnretained(event)
        }
        return handle(nsEvent: ns) ? nil : Unmanaged.passUnretained(event)
    }

    @discardableResult
    private func handle(nsEvent ns: NSEvent) -> Bool {
        guard ns.type == .systemDefined, ns.subtype.rawValue == nxSubtypeAuxControlButtons else {
            debugLog("ns type=\(ns.type.rawValue) subtype=\(ns.subtype.rawValue)")
            return false
        }

        let data1 = ns.data1
        debugLog("systemDefined data1=\(data1)")
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = data1 & 0x0000FFFF
        let keyState = (keyFlags & 0xFF00) >> 8
        let isKeyDown = keyState == 0x0A

        guard keyCode == nxKeyTypeBrightnessUp || keyCode == nxKeyTypeBrightnessDown else {
            return false
        }
        if !isKeyDown {
            // Key-up for a key we own; swallow it in the local/tap path.
            return true
        }
        guard onBrightness != nil else {
            return false
        }

        let now = ProcessInfo.processInfo.systemUptime
        if now - lastHandled < throttle {
            return true
        }
        lastHandled = now

        let delta = keyCode == nxKeyTypeBrightnessUp ? 1 : -1
        return onBrightness?(delta) ?? false
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
