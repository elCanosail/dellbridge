#if os(macOS)
import AppKit
import ApplicationServices
import DellBridgeCore

/// Minimal menu bar shell. The full media-key agent is M2; this exists so the
/// packaging and installer pipeline can be built and tested end to end.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var client: DDCClient?
    private let mediaKeys = MediaKeyMonitor()
    private let osd = OSDController()
    private var mediaKeysActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "◐"
        connect()
        rebuildMenu()
        configureMediaKeys(prompt: true)
    }

    private func connect() {
        guard let display = AppleSiliconDisplays.all().first(where: { $0.isExternal }) else {
            client = nil
            return
        }
        guard let transport = try? AppleSiliconTransport(display: display) else {
            client = nil
            return
        }
        client = DDCClient(transport: transport, writeDelayMilliseconds: 20)
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if client == nil {
            let unavailable = NSMenuItem(title: "No external display", action: nil, keyEquivalent: "")
            unavailable.isEnabled = false
            menu.addItem(unavailable)
            menu.addItem(.separator())
        }

        menu.addItem(item("Brightness +10", #selector(brightnessUp)))
        menu.addItem(item("Brightness −10", #selector(brightnessDown)))
        menu.addItem(.separator())
        menu.addItem(item("Input: USB-C", #selector(inputUSBC)))
        menu.addItem(item("Input: HDMI 1", #selector(inputHDMI1)))
        menu.addItem(item("Input: HDMI 2", #selector(inputHDMI2)))
        menu.addItem(.separator())
        if !AXIsProcessTrusted() {
            menu.addItem(item("Enable Accessibility…", #selector(openAccessibilitySettings)))
        }
        if mediaKeysActive {
            let active = NSMenuItem(title: "Media keys: active", action: nil, keyEquivalent: "")
            active.isEnabled = false
            menu.addItem(active)
        } else {
            menu.addItem(item("Retry media keys", #selector(retryMediaKeys)))
        }
        menu.addItem(.separator())
        menu.addItem(item("Refresh display", #selector(refresh)))
        menu.addItem(item("Quit DellBridge", #selector(quit), key: "q"))

        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func brightnessUp() { _ = changeBrightness(rawDelta: 10) }
    @objc private func brightnessDown() { _ = changeBrightness(rawDelta: -10) }

    @discardableResult
    private func changeBrightness(rawDelta: Int) -> Bool {
        guard let client else { return false }
        do {
            let value = try client.change(VCP.brightness.rawValue, by: rawDelta)
            osd.showBrightness(current: Int(value.current), maximum: Int(value.maximum))
            return true
        } catch {
            NSSound.beep()
            return false
        }
    }

    private func changeBrightnessStep(_ direction: Int) -> Bool {
        guard let client else { return false }
        do {
            let reference = try client.read(VCP.brightness.rawValue)
            let step = max(1, Int(reference.maximum) / 16)
            return changeBrightness(rawDelta: direction * step)
        } catch {
            return false
        }
    }

    @objc private func inputUSBC() { setInput(InputSource.usbC.rawValue) }
    @objc private func inputHDMI1() { setInput(InputSource.hdmi1.rawValue) }
    @objc private func inputHDMI2() { setInput(InputSource.hdmi2.rawValue) }

    private func setInput(_ value: UInt16) {
        guard let client else { return }
        do {
            try client.write(VCP.inputSource.rawValue, value: value)
        } catch {
            NSSound.beep()
        }
    }

    @objc private func refresh() {
        connect()
        rebuildMenu()
    }

    private func configureMediaKeys(prompt: Bool) {
        mediaKeys.onBrightness = { [weak self] direction in
            self?.changeBrightnessStep(direction) ?? false
        }
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        mediaKeysActive = mediaKeys.start()
        rebuildMenu()
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func retryMediaKeys() {
        configureMediaKeys(prompt: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaKeys.stop()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
#endif
