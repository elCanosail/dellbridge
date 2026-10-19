#if os(macOS)
import AppKit
import DellBridgeCore

/// Minimal menu bar shell. The full media-key agent is M2; this exists so the
/// packaging and installer pipeline can be built and tested end to end.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var client: DDCClient?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "◐"
        connect()
        rebuildMenu()
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
        menu.addItem(item("Refresh display", #selector(refresh)))
        menu.addItem(item("Quit DellBridge", #selector(quit), key: "q"))

        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func brightnessUp() { changeBrightness(10) }
    @objc private func brightnessDown() { changeBrightness(-10) }

    private func changeBrightness(_ delta: Int) {
        guard let client else { return }
        do {
            _ = try client.change(VCP.brightness.rawValue, by: delta)
        } catch {
            NSSound.beep()
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
