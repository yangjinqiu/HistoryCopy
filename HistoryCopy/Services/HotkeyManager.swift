import Foundation
import Carbon
import AppKit

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
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

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                print("[HistoryCopy] Carbon event handler invoked")
                guard let userData = userData else {
                    print("[HistoryCopy] ERROR: userData is nil in Carbon handler")
                    return -1
                }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                print("[HistoryCopy] Carbon handler calling onHotkeyPressed, callback=\(manager.onHotkeyPressed != nil ? "set" : "nil")")
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
            print("[HistoryCopy] Failed to register hotkey: \(status)")
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
