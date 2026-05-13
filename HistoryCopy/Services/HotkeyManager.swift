import Foundation
import Carbon
import AppKit

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    var onHotkeyPressed: (() -> Void)?

    struct HotkeyConfig: Equatable {
        var keyCode: Int
        var modifiers: Int

        static var `default`: HotkeyConfig {
            HotkeyConfig(keyCode: 9, modifiers: cmdKey | optionKey) // Cmd+Option+V
        }
    }

    private var currentConfig: HotkeyConfig = .default

    func loadSavedConfig() {
        let keyCode = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "hotkeyModifiers")

        if keyCode != 0 || modifiers != 0 {
            currentConfig = HotkeyConfig(keyCode: keyCode, modifiers: modifiers)
        } else {
            currentConfig = .default
            saveConfig(currentConfig)
        }
    }

    func saveConfig(_ config: HotkeyConfig) {
        UserDefaults.standard.set(config.keyCode, forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(config.modifiers, forKey: "hotkeyModifiers")
        currentConfig = config
    }

    func register() {
        unregister()

        // Primary: Carbon hotkey (works without Accessibility permission)
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData = userData else { return -1 }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onHotkeyPressed?()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        let hotkeyID = EventHotKeyID(signature: 0x48434B59, id: 1) // "HCKY"
        let status = RegisterEventHotKey(
            UInt32(currentConfig.keyCode),
            UInt32(currentConfig.modifiers),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status != noErr {
            print("[HistoryCopy] Carbon hotkey registration failed: \(status)")
        }

        // Fallback: NSEvent global monitor (requires Accessibility permission)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor catches events when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    private func carbonModsToNSEvent(_ carbonMods: Int) -> NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if carbonMods & cmdKey != 0 { flags.insert(.command) }
        if carbonMods & optionKey != 0 { flags.insert(.option) }
        if carbonMods & controlKey != 0 { flags.insert(.control) }
        if carbonMods & shiftKey != 0 { flags.insert(.shift) }
        return flags
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let expectedMods = carbonModsToNSEvent(currentConfig.modifiers)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == UInt16(currentConfig.keyCode) && flags == expectedMods {
            onHotkeyPressed?()
        }
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    func checkConflict(keyCode: Int, modifiers: Int) -> Bool {
        var hotkeyRef: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: 0x48434B52, id: 2) // "HCKR"
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        if status == noErr, let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            return false
        }
        return true
    }

    func reregister(with config: HotkeyConfig) {
        saveConfig(config)
        register()
    }

    var currentKeyCode: Int { currentConfig.keyCode }
    var currentModifiers: Int { currentConfig.modifiers }
}
