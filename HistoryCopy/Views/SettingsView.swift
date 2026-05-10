import SwiftUI
import Carbon
import ServiceManagement

struct SettingsView: View {
    let storage: StorageManager

    @State private var retentionDays: Int
    @State private var launchAtLogin: Bool
    @State private var isRecordingHotkey = false
    @State private var hotkeyDisplay: String
    @State private var conflictMessage: String?

    private let retentionOptions: [(Int, String)] = [
        (1, "1天"),
        (3, "3天"),
        (5, "5天"),
        (7, "7天"),
        (0, "永不")
    ]

    init(storage: StorageManager) {
        self.storage = storage

        let days = UserDefaults.standard.integer(forKey: "retentionDays")
        if days == 0 || retentionOptions.contains(where: { $0.0 == days }) {
            _retentionDays = State(initialValue: days)
        } else {
            _retentionDays = State(initialValue: 3)
        }

        _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)

        let keyCode = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
        if keyCode == 0 && modifiers == 0 {
            _hotkeyDisplay = State(initialValue: "⌘ ⌥ V")
        } else {
            _hotkeyDisplay = State(initialValue: HotkeyHelper.toString(keyCode: keyCode, modifiers: modifiers))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                    // Retention
                    VStack(alignment: .leading, spacing: 10) {
                        Text("保留时长")
                            .font(.system(size: 13, weight: .semibold))

                        Picker("", selection: $retentionDays) {
                            ForEach(retentionOptions, id: \.0) { option in
                                Text(option.1).tag(option.0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: retentionDays) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "retentionDays")
                            storage.cleanupExpired()
                            NotificationCenter.default.post(
                                name: NSNotification.Name("RefreshPanel"), object: nil
                            )
                        }
                    }

                    Divider()

                    // Hotkey
                    VStack(alignment: .leading, spacing: 10) {
                        Text("全局快捷键")
                            .font(.system(size: 13, weight: .semibold))

                        Button(action: { isRecordingHotkey = true }) {
                            HStack {
                                if isRecordingHotkey {
                                    Text("按下新快捷键...")
                                        .foregroundColor(.accentColor)
                                } else {
                                    Text(hotkeyDisplay)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                if !isRecordingHotkey {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                        .background(KeyEventRecorder(
                            isRecording: isRecordingHotkey,
                            onKeyCaptured: { keyCode, nsModifiers in
                                let carbonMods = HotkeyHelper.carbonModifiers(from: nsModifiers)

                                if HotkeyManager.shared.checkConflict(
                                    keyCode: keyCode, modifiers: carbonMods
                                ) {
                                    conflictMessage = "此快捷键已被占用，请重新输入"
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        conflictMessage = nil
                                    }
                                } else {
                                    let config = HotkeyManager.HotkeyConfig(
                                        keyCode: keyCode, modifiers: carbonMods
                                    )
                                    HotkeyManager.shared.reregister(with: config)
                                    hotkeyDisplay = HotkeyHelper.toString(
                                        keyCode: keyCode, modifiers: carbonMods
                                    )
                                    isRecordingHotkey = false
                                    conflictMessage = nil
                                }
                            }
                        ))

                        if let msg = conflictMessage {
                            Text(msg)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                    }

                    Divider()

                    // Launch at login
                    VStack(alignment: .leading, spacing: 10) {
                        Text("启动")
                            .font(.system(size: 13, weight: .semibold))

                        Toggle(isOn: $launchAtLogin) {
                            Text("开机自动启动")
                                .font(.system(size: 13))
                        }
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                    }

                    Divider()

                    // Clean up
                    VStack(alignment: .leading, spacing: 10) {
                        Text("数据管理")
                            .font(.system(size: 13, weight: .semibold))

                        Button(action: { cleanupAll() }) {
                            Text("清除所有历史记录")
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        .frame(minWidth: 420, minHeight: 400)
    }

    private func cleanupAll() {
        for item in storage.fetchAllItems() {
            storage.deleteItem(item)
        }
        NotificationCenter.default.post(
            name: NSNotification.Name("RefreshPanel"), object: nil
        )
    }
}

// MARK: - Key event recorder (NSViewRepresentable for proper event monitoring)

struct KeyEventRecorder: NSViewRepresentable {
    let isRecording: Bool
    let onKeyCaptured: (Int, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        KeyCaptureView(onKeyCaptured: onKeyCaptured)
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.isRecording = isRecording
        nsView.onKeyCaptured = onKeyCaptured
    }
}

final class KeyCaptureView: NSView {
    var isRecording = false
    var onKeyCaptured: (Int, NSEvent.ModifierFlags) -> Void
    private var monitor: Any?

    init(onKeyCaptured: @escaping (Int, NSEvent.ModifierFlags) -> Void) {
        self.onKeyCaptured = onKeyCaptured
        super.init(frame: .zero)

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            self.onKeyCaptured(Int(event.keyCode), event.modifierFlags)
            self.isRecording = false
            return nil
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Hotkey helpers

enum HotkeyHelper {
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var mods = 0
        if flags.contains(.command) { mods |= cmdKey }
        if flags.contains(.option) { mods |= optionKey }
        if flags.contains(.shift) { mods |= shiftKey }
        if flags.contains(.control) { mods |= controlKey }
        return mods
    }

    static func toString(keyCode: Int, modifiers: Int) -> String {
        var parts: [String] = []
        if modifiers & controlKey != 0 { parts.append("⌃") }
        if modifiers & optionKey != 0 { parts.append("⌥") }
        if modifiers & shiftKey != 0 { parts.append("⇧") }
        if modifiers & cmdKey != 0 { parts.append("⌘") }

        let keyMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P",
            37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            49: "Space", 36: "Return", 53: "Escape", 51: "Delete",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
            97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
            103: "F11", 111: "F12"
        ]

        if let key = keyMap[keyCode] {
            parts.append(key)
        } else {
            parts.append("Key\(keyCode)")
        }

        return parts.joined(separator: " ")
    }
}
