#if os(macOS)
import AppKit
import ApplicationServices
import CoreGraphics

private let nxSubtypeAuxControlButtons: Int16 = 8
private let nxKeyTypeBrightnessUp = 2
private let nxKeyTypeBrightnessDown = 3
private let nxKeyTypeSoundUp = 0
private let nxKeyTypeSoundDown = 1
private let nxKeyTypeMute = 7
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

/// Intercepts Apple brightness/volume keys through a session event tap plus
/// NSEvent global/local monitors.
///
/// Brightness and volume keys arrive as NX_SYSDEFINED aux events on a normal
/// desktop. In clamshell (or with no built-in display to target), macOS can
/// suppress that event while the raw F1/F2/F3 keyDown still flows. Both paths
/// are handled. The monitors are a second path for macOS versions where the
/// tap does not receive the key; they cannot suppress, but on an external
/// display the system action is harmless. Per-key throttles avoid double
/// adjustments if both paths see the same press.
final class MediaKeyMonitor {
    var onBrightness: ((Int) -> Bool)?
    var onVolume: ((Int) -> Bool)?
    var onMute: (() -> Bool)?

    fileprivate var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastBrightness: TimeInterval = 0
    private var lastVolume: TimeInterval = 0
    private var lastMute: TimeInterval = 0
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

        let monitorMask: NSEvent.EventTypeMask = [.systemDefined, .keyDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: monitorMask) { [weak self] event in
            _ = self?.handle(nsEvent: event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: monitorMask) { [weak self] event in
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
        // Brightness/volume keys can arrive as NX_SYSDEFINED aux events or as
        // raw keyDown events (clamshell/no built-in display). Tap both.
        let mask = (CGEventMask(1) << CGEventMask(NSEvent.EventType.systemDefined.rawValue))
            | (CGEventMask(1) << CGEventMask(CGEventType.keyDown.rawValue))
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
        if event.type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            debugLog("keyDown keycode=\(keyCode)")
            switch keyCode {
            case 144:
                return handleBrightness(direction: 1) ? nil : Unmanaged.passUnretained(event)
            case 145:
                return handleBrightness(direction: -1) ? nil : Unmanaged.passUnretained(event)
            case 72:
                return handleVolume(direction: 1) ? nil : Unmanaged.passUnretained(event)
            case 73:
                return handleVolume(direction: -1) ? nil : Unmanaged.passUnretained(event)
            case 74:
                return handleMute() ? nil : Unmanaged.passUnretained(event)
            default:
                return Unmanaged.passUnretained(event)
            }
        }

        guard let ns = NSEvent(cgEvent: event) else {
            debugLog("NSEvent nil cgtype=\(event.type.rawValue)")
            return Unmanaged.passUnretained(event)
        }
        return handle(nsEvent: ns) ? nil : Unmanaged.passUnretained(event)
    }

    @discardableResult
    private func handle(nsEvent ns: NSEvent) -> Bool {
        if ns.type == .keyDown {
            debugLog("ns keyDown keycode=\(ns.keyCode)")
            switch ns.keyCode {
            case 144:
                return handleBrightness(direction: 1)
            case 145:
                return handleBrightness(direction: -1)
            case 72:
                return handleVolume(direction: 1)
            case 73:
                return handleVolume(direction: -1)
            case 74:
                return handleMute()
            default:
                return false
            }
        }

        guard ns.type == .systemDefined, ns.subtype.rawValue == nxSubtypeAuxControlButtons else {
            debugLog("ns type=\(ns.type.rawValue) subtype=\(ns.subtype.rawValue)")
            return false
        }

        let data1 = ns.data1
        debugLog("systemDefined data1=\(data1)")
        let keyCode = (data1 >> 16) & 0xFF
        let isKeyDown = (data1 & 0x0100) == 0

        switch keyCode {
        case nxKeyTypeBrightnessUp, nxKeyTypeBrightnessDown:
            guard isKeyDown else { return true }
            return handleBrightness(direction: keyCode == nxKeyTypeBrightnessUp ? 1 : -1)
        case nxKeyTypeSoundUp, nxKeyTypeSoundDown:
            guard isKeyDown else { return true }
            return handleVolume(direction: keyCode == nxKeyTypeSoundUp ? 1 : -1)
        case nxKeyTypeMute:
            guard isKeyDown else { return true }
            return handleMute()
        default:
            return false
        }
    }

    @discardableResult
    private func handleBrightness(direction: Int) -> Bool {
        guard onBrightness != nil else {
            return false
        }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastBrightness < throttle {
            return true
        }
        lastBrightness = now
        return onBrightness?(direction) ?? false
    }

    @discardableResult
    private func handleVolume(direction: Int) -> Bool {
        guard onVolume != nil else {
            return false
        }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastVolume < throttle {
            return true
        }
        lastVolume = now
        return onVolume?(direction) ?? false
    }

    @discardableResult
    private func handleMute() -> Bool {
        guard onMute != nil else {
            return false
        }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastMute < throttle {
            return true
        }
        lastMute = now
        return onMute?() ?? false
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
