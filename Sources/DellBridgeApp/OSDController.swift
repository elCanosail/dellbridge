#if os(macOS)
import AppKit
import QuartzCore

/// Small HUD shown when a media key changes a monitor VCP value.
///
/// It is deliberately non-activating and click-through: the panel must never
/// steal focus from the app the user is working in.
final class OSDController {
    private var panel: NSPanel?
    private var iconView: NSImageView?
    private var progress: NSProgressIndicator?
    private var hideWorkItem: DispatchWorkItem?

    func showBrightness(current: Int, maximum: Int) {
        let panel = ensurePanel()
        iconView?.image = NSImage(
            systemSymbolName: "sun.max.fill",
            accessibilityDescription: "Brightness"
        )
        let percent = maximum > 0
            ? max(0, min(100, Int((Double(current) / Double(maximum) * 100).rounded())))
            : 0
        progress?.doubleValue = Double(percent)
        position(panel)
        panel.orderFrontRegardless()

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak panel] in
            panel?.orderOut(nil)
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func ensurePanel() -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false

        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 240, height: 64))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true
        effect.autoresizingMask = [.width, .height]
        panel.contentView = effect

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentTintColor = .white
        icon.imageScaling = .scaleProportionallyUpOrDown
        effect.addSubview(icon)

        let progress = NSProgressIndicator()
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 100
        progress.controlSize = .small
        progress.wantsLayer = true
        effect.addSubview(progress)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 18),
            icon.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 26),
            icon.heightAnchor.constraint(equalToConstant: 26),
            progress.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 14),
            progress.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -18),
            progress.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
            progress.heightAnchor.constraint(equalToConstant: 8),
        ])

        self.panel = panel
        self.iconView = icon
        self.progress = progress
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + 90
        ))
    }
}
#endif
