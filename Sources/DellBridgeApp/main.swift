#if os(macOS)
import AppKit
import ApplicationServices
import CoreAudio
import DellBridgeCore

/// Minimal menu bar shell. The full media-key agent is M2; this exists so the
/// packaging and installer pipeline can be built and tested end to end.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var client: DDCClient?
    private let mediaKeys = MediaKeyMonitor()
    private let osd = OSDController()
    private let ddcQueue = DispatchQueue(label: "es.elcanosail.dellbridge.ddc")
    private var mutedVolume: UInt16?
    private var mediaKeysActive = false
    private var audioListener: AudioObjectPropertyListenerBlock?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "◐"
        installObservers()
        connect()
        rebuildMenu()
        configureMediaKeys(prompt: true)
    }

    private func installObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Accessibility grants can change while the app is running. Without
        // this, a first-launch denial leaves mediaKeysActive false forever.
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.updateMediaKeyTap()
            }
        }

        // IOAVService can be stale for a few seconds after wake.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self?.connect()
                self?.updateMediaKeyTap()
                self?.rebuildMenu()
            }
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateMediaKeyTap()
            }
        }
        audioListener = listener
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            listener
        )
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
        menu.addItem(item("Volume +10", #selector(volumeUp)))
        menu.addItem(item("Volume −10", #selector(volumeDown)))
        menu.addItem(item("Mute", #selector(muteMenu)))
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

    @objc private func brightnessUp() {
        ddcQueue.async { [weak self] in _ = self?.changeBrightness(rawDelta: 10) }
    }

    @objc private func brightnessDown() {
        ddcQueue.async { [weak self] in _ = self?.changeBrightness(rawDelta: -10) }
    }

    @discardableResult
    private func changeBrightness(rawDelta: Int) -> Bool {
        guard let client else { return false }
        do {
            let value = try client.change(VCP.brightness.rawValue, by: rawDelta)
            let current = Int(value.current)
            let maximum = Int(value.maximum)
            DispatchQueue.main.async { [weak self] in
                self?.osd.showBrightness(current: current, maximum: maximum)
            }
            return true
        } catch {
            DispatchQueue.main.async { NSSound.beep() }
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

    @objc private func volumeUp() {
        ddcQueue.async { [weak self] in _ = self?.changeVolumeStep(1) }
    }

    @objc private func volumeDown() {
        ddcQueue.async { [weak self] in _ = self?.changeVolumeStep(-1) }
    }

    @objc private func muteMenu() {
        ddcQueue.async { [weak self] in _ = self?.toggleMute() }
    }

    @discardableResult
    private func changeVolumeStep(_ direction: Int) -> Bool {
        guard let client else { return false }
        do {
            let reference = try client.read(VCP.volume.rawValue)
            let step = max(1, Int(reference.maximum) / 16)
            // Do not touch VCP 0x8D here. This Dell accepts the mute write
            // command but does not change its reported mute state; attempting
            // it only delays the volume write.
            let value = try client.change(VCP.volume.rawValue, by: direction * step)
            mutedVolume = nil
            let current = Int(value.current)
            let maximum = Int(value.maximum)
            DispatchQueue.main.async { [weak self] in
                self?.osd.showVolume(current: current, maximum: maximum)
            }
            return true
        } catch {
            DispatchQueue.main.async { NSSound.beep() }
            return false
        }
    }

    @discardableResult
    private func toggleMute() -> Bool {
        guard let client else { return false }
        do {
            let reference = try client.read(VCP.volume.rawValue)
            if let saved = mutedVolume {
                // If mute happened while volume was already 0, restore one
                // visible step instead of "unmuting" back to silence.
                let fallback = UInt16(max(1, Int(reference.maximum) / 16))
                let restore = saved == 0 ? fallback : min(saved, reference.maximum)
                try client.write(VCP.volume.rawValue, value: restore)
                mutedVolume = nil
                let current = Int(restore)
                let maximum = Int(reference.maximum)
                DispatchQueue.main.async { [weak self] in
                    self?.osd.showVolume(current: current, maximum: maximum)
                }
            } else {
                mutedVolume = reference.current
                try client.write(VCP.volume.rawValue, value: 0)
                DispatchQueue.main.async { [weak self] in
                    self?.osd.showMute(true)
                }
            }
            return true
        } catch {
            DispatchQueue.main.async { NSSound.beep() }
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
        updateMediaKeyTap()
        rebuildMenu()
    }

    private func configureMediaKeys(prompt: Bool) {
        mediaKeys.onBrightness = { [weak self] direction in
            guard let self else { return false }
            self.ddcQueue.async { _ = self.changeBrightnessStep(direction) }
            return true
        }
        mediaKeys.shouldHandleBrightness = { [weak self] in
            self?.shouldHandleBrightnessKeys() ?? false
        }
        mediaKeys.onVolume = { [weak self] direction in
            guard let self else { return false }
            self.ddcQueue.async { _ = self.changeVolumeStep(direction) }
            return true
        }
        mediaKeys.shouldHandleVolume = { [weak self] in
            self?.shouldHandleVolumeKeys() ?? false
        }
        mediaKeys.onMute = { [weak self] in
            guard let self else { return false }
            self.ddcQueue.async { _ = self.toggleMute() }
            return true
        }
        mediaKeys.shouldHandleMute = { [weak self] in
            self?.shouldHandleVolumeKeys() ?? false
        }
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        updateMediaKeyTap()
    }

    @objc private func screenParametersChanged() {
        connect()
        updateMediaKeyTap()
        rebuildMenu()
        // USB-C hotplug can publish the screen notification before the
        // IOAVService proxy is ready. Re-check once after settle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.connect()
            self?.updateMediaKeyTap()
            self?.rebuildMenu()
        }
    }

    /// MonitorControl does the same thing: do not leave a media-key tap
    /// installed when there is no external display and the default audio
    /// device is natively controllable. Keeping a tap alive just to pass
    /// events through creates needless lifecycle and permission edge cases.
    private func updateMediaKeyTap() {
        let hasExternal = AppleSiliconDisplays.all().contains(where: { $0.isExternal })
        let dellAudio = shouldHandleVolumeKeys()
        let needed = hasExternal || dellAudio

        if needed, !mediaKeysActive {
            mediaKeysActive = mediaKeys.start()
        } else if !needed, mediaKeysActive {
            mediaKeys.stop()
            mediaKeysActive = false
        }
        rebuildMenu()
    }

    private func shouldHandleVolumeKeys() -> Bool {
        guard let name = defaultOutputDeviceName() else { return false }
        let lower = name.lowercased()
        return lower.contains("dell") || lower.contains("s2725")
    }

    private func shouldHandleBrightnessKeys() -> Bool {
        guard client != nil else { return false }
        return AppleSiliconDisplays.all().contains(where: { $0.isExternal })
    }

    private func defaultOutputDeviceName() -> String? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        ) == noErr else {
            return nil
        }

        var name: Unmanaged<CFString>?
        var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            deviceID,
            &nameAddress,
            0,
            nil,
            &nameSize,
            &name
        ) == noErr, let name else {
            return nil
        }
        return name.takeRetainedValue() as String
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func retryMediaKeys() {
        mediaKeys.stop()
        mediaKeysActive = false
        configureMediaKeys(prompt: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaKeys.stop()
        if let audioListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                DispatchQueue.main,
                audioListener
            )
        }
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
