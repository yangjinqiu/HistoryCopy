import SwiftUI
import AppKit
import Carbon

final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@main
struct HistoryCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(storage: appDelegate.storage)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panel: HistoryPanel!
    let storage = StorageManager()
    private var monitor: ClipboardMonitor?
    private let hotkeyManager = HotkeyManager.shared
    private var isPanelVisible = false
    private var dismissGeneration = 0
    private var lastShowTime: Date?
    private var showRetryCount = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        registerDefaults()
        setupStatusItem()
        setupPanel()
        setupHotkey()
        setupClipboardMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
        monitor?.stop()
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        print("[HistoryCopy] windowDidResignKey called, window=\(notification.object as? NSWindow != nil ? "yes" : "no"), isPanel=\(notification.object as? NSWindow === panel)")
        guard let window = notification.object as? NSWindow, window === panel else { return }
        if panel.attachedSheet != nil {
            print("[HistoryCopy] windowDidResignKey skipped: sheet attached")
            return
        }
        // ViewBridge warm-up: first show may immediately lose key, auto-retry once
        if let lastShow = lastShowTime, Date().timeIntervalSince(lastShow) < 0.6, showRetryCount == 0 {
            showRetryCount += 1
            print("[HistoryCopy] windowDidResignKey -> auto-retry show (ViewBridge warm-up)")
            isPanelVisible = false
            dismissGeneration += 1
            panel.orderOut(nil)
            showPanel()
            return
        }
        showRetryCount = 0
        print("[HistoryCopy] windowDidResignKey -> calling dismissPanel")
        dismissPanel()
    }

    // MARK: - Defaults

    private func registerDefaults() {
        let defaults: [String: Any] = [
            "retentionDays": 3,
            "maxItemCount": 1000,
            "hotkeyKeyCode": 9,    // V
            "hotkeyModifiers": cmdKey | optionKey
        ]
        UserDefaults.standard.register(defaults: defaults)
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = createMenuBarIcon()
            button.image?.isTemplate = true
            button.toolTip = "HistoryCopy"

            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func createMenuBarIcon() -> NSImage {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size)

        image.lockFocus()
        let path = NSBezierPath(roundedRect: NSRect(x: 2, y: 3, width: 16, height: 14), xRadius: 3, yRadius: 3)
        path.lineWidth = 1.8

        // Draw clipboard outline
        NSColor.secondaryLabelColor.setStroke()
        path.stroke()

        // Draw lines on clipboard
        for i in 0..<3 {
            let y = CGFloat(7 + i * 3)
            let line = NSBezierPath()
            line.move(to: NSPoint(x: 6, y: y))
            line.line(to: NSPoint(x: 14, y: y))
            line.lineWidth = 1.2
            NSColor.secondaryLabelColor.withAlphaComponent(0.6).setStroke()
            line.stroke()
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePanel()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        let pauseItem = NSMenuItem(
            title: monitor == nil ? "恢复记录" : "暂停记录",
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "设置...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "退出 HistoryCopy",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleRecording() {
        if monitor != nil {
            monitor?.stop()
            monitor = nil
        } else {
            monitor = ClipboardMonitor()
            monitor?.start(context: storage.context)
        }
    }

    // MARK: - Panel

    private func setupPanel() {
        panel = HistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 580),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = false
        panel.isMovable = false
        panel.animationBehavior = .none
        panel.delegate = self

        let panelSize = NSRect(x: 0, y: 0, width: 400, height: 580)

        // Liquid Glass or fallback
        let glassView: NSView
        if let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let lg = glassClass.init(frame: panelSize)
            if lg.responds(to: NSSelectorFromString("setStyle:")) {
                typealias IntSetter = @convention(c) (NSObject, Selector, Int) -> Void
                let imp = class_getMethodImplementation(type(of: lg), NSSelectorFromString("setStyle:"))
                unsafeBitCast(imp, to: IntSetter.self)(lg as NSObject, NSSelectorFromString("setStyle:"), 0)
            }
            if lg.responds(to: NSSelectorFromString("setCornerRadius:")) {
                typealias DblSetter = @convention(c) (NSObject, Selector, Double) -> Void
                let imp = class_getMethodImplementation(type(of: lg), NSSelectorFromString("setCornerRadius:"))
                unsafeBitCast(imp, to: DblSetter.self)(lg as NSObject, NSSelectorFromString("setCornerRadius:"), 20)
            }
            if lg.responds(to: NSSelectorFromString("setClipsToBounds:")) {
                typealias BoolSetter = @convention(c) (NSObject, Selector, Bool) -> Void
                let imp = class_getMethodImplementation(type(of: lg), NSSelectorFromString("setClipsToBounds:"))
                unsafeBitCast(imp, to: BoolSetter.self)(lg as NSObject, NSSelectorFromString("setClipsToBounds:"), true)
            }
            // Pre-warm: force layout to initialize ViewBridge before panel is shown
            lg.layoutSubtreeIfNeeded()
            glassView = lg
        } else {
            let blur = NSVisualEffectView(frame: panelSize)
            blur.material = .hudWindow
            blur.blendingMode = .withinWindow
            blur.state = .active
            blur.wantsLayer = true
            blur.layer?.cornerRadius = 20
            blur.layer?.masksToBounds = true
            glassView = blur
        }

        // SwiftUI content on top
        let hostingView = NSHostingView(
            rootView: HistoryPanelView(storage: storage, onDismiss: { [weak self] in
                self?.dismissPanel()
            })
        )
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.frame = panelSize
        glassView.addSubview(hostingView)

        panel.contentView = glassView
    }

    private func showPanel() {
        print("[HistoryCopy] showPanel called, isPanelVisible=\(isPanelVisible)")
        guard !isPanelVisible else {
            print("[HistoryCopy] showPanel aborted: already visible")
            return
        }

        isPanelVisible = true
        dismissGeneration += 1

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = panel.frame
            let x = screenFrame.midX - panelFrame.width / 2
            let y = screenFrame.midY - panelFrame.height / 2 + screenFrame.minY + 30
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        lastShowTime = Date()
        panel.alphaValue = 0
        panel.contentView?.layer?.transform = CATransform3DMakeScale(0.94, 0.94, 1)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        print("[HistoryCopy] showPanel makeKeyAndOrderFront done")

        let p = panel!
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.275)
            p.animator().alphaValue = 1
            p.contentView?.layer?.transform = CATransform3DIdentity
        }
    }

    private func dismissPanel() {
        print("[HistoryCopy] dismissPanel called, isPanelVisible=\(isPanelVisible)")
        guard isPanelVisible else {
            print("[HistoryCopy] dismissPanel aborted: not visible")
            return
        }

        isPanelVisible = false
        dismissGeneration += 1
        let capturedGen = dismissGeneration
        print("[HistoryCopy] dismissPanel set isPanelVisible=false, gen=\(capturedGen)")

        let p = panel!
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            p.animator().alphaValue = 0
            p.contentView?.layer?.transform = CATransform3DMakeScale(0.97, 0.97, 1)
        } completionHandler: { [weak self] in
            guard let self else { return }
            if self.dismissGeneration == capturedGen {
                p.orderOut(nil)
                p.alphaValue = 1
                print("[HistoryCopy] dismissPanel completion: panel ordered out, gen=\(capturedGen)")
            } else {
                print("[HistoryCopy] dismissPanel completion skipped: gen mismatch (captured=\(capturedGen), current=\(self.dismissGeneration))")
            }
        }
    }

    private func togglePanel() {
        print("[HistoryCopy] togglePanel called, isPanelVisible=\(isPanelVisible)")
        if isPanelVisible {
            dismissPanel()
        } else {
            showPanel()
        }
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        hotkeyManager.loadSavedConfig()
        hotkeyManager.onHotkeyPressed = { [weak self] in
            print("[HistoryCopy] onHotkeyPressed fired, self=\(self != nil ? "alive" : "nil")")
            DispatchQueue.main.async {
                guard let self else {
                    print("[HistoryCopy] ERROR: self is nil in DispatchQueue.main.async")
                    return
                }
                print("[HistoryCopy] DispatchQueue.main.async executing, isPanelVisible=\(self.isPanelVisible)")
                MainActor.assumeIsolated {
                    self.togglePanel()
                }
            }
        }
        hotkeyManager.register()
    }

    // MARK: - Clipboard

    private func setupClipboardMonitor() {
        monitor = ClipboardMonitor()
        monitor?.start(context: storage.context)

        // Clean expired on launch
        monitor?.cleanupExpired(context: storage.context)
    }

    // MARK: - Settings

    @objc private func openSettings() {
        if isPanelVisible {
            dismissPanel()
        }
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

