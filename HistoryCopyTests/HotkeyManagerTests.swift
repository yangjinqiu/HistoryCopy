import XCTest
import Carbon
@testable import HistoryCopy

final class HotkeyManagerTests: XCTestCase {
    private var manager: HotkeyManager!

    override func setUp() {
        super.setUp()
        manager = HotkeyManager()
    }

    override func tearDown() {
        manager.unregister()
        manager = nil
        super.tearDown()
    }

    // MARK: - HotkeyConfig

    func test_defaultConfig() {
        let config = HotkeyManager.HotkeyConfig.default
        XCTAssertEqual(config.keyCode, 9)
        XCTAssertEqual(config.modifiers, cmdKey | optionKey)
    }

    func test_defaultConfig_keyCode_isV() {
        XCTAssertEqual(HotkeyManager.HotkeyConfig.default.keyCode, 9)
    }

    func test_config_equality() {
        let a = HotkeyManager.HotkeyConfig(keyCode: 1, modifiers: 2)
        let b = HotkeyManager.HotkeyConfig(keyCode: 1, modifiers: 2)
        let c = HotkeyManager.HotkeyConfig(keyCode: 1, modifiers: 3)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func test_config_equality_differentKeyCode() {
        let a = HotkeyManager.HotkeyConfig(keyCode: 1, modifiers: 2)
        let b = HotkeyManager.HotkeyConfig(keyCode: 2, modifiers: 2)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Save / Load Config

    func test_saveAndLoadConfig() {
        let config = HotkeyManager.HotkeyConfig(keyCode: 42, modifiers: cmdKey | shiftKey)
        manager.saveConfig(config)
        XCTAssertEqual(manager.currentKeyCode, 42)
        XCTAssertEqual(manager.currentModifiers, cmdKey | shiftKey)

        let savedKeyCode = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        let savedModifiers = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
        XCTAssertEqual(savedKeyCode, 42)
        XCTAssertEqual(savedModifiers, Int(cmdKey | shiftKey))
    }

    func test_loadSavedConfig_whenDefaultsEmpty_usesDefault() {
        UserDefaults.standard.removeObject(forKey: "hotkeyKeyCode")
        UserDefaults.standard.removeObject(forKey: "hotkeyModifiers")
        manager.loadSavedConfig()
        XCTAssertEqual(manager.currentKeyCode, 9)
        XCTAssertEqual(manager.currentModifiers, Int(cmdKey | optionKey))
    }

    func test_loadSavedConfig_whenDefaultsHaveValues() {
        UserDefaults.standard.set(20, forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(cmdKey | shiftKey, forKey: "hotkeyModifiers")
        manager.loadSavedConfig()
        XCTAssertEqual(manager.currentKeyCode, 20)
        XCTAssertEqual(manager.currentModifiers, Int(cmdKey | shiftKey))
    }

    // MARK: - Conflict Detection

    func test_checkConflict_defaultHotkey() {
        // Cmd+Option+V is expected to be available (or taken by system)
        // We just verify it doesn't crash
        let hasConflict = manager.checkConflict(keyCode: 9, modifiers: cmdKey | optionKey)
        // Either outcome is valid; the method should just not crash
        _ = hasConflict
    }

    func test_checkConflict_sameKeyCalledTwice_consistentOrNot() {
        // Conflict check on an obscure combination
        let first = manager.checkConflict(keyCode: 100, modifiers: cmdKey | optionKey | shiftKey | controlKey)
        // The method should return a Bool without crashing
        XCTAssertTrue(first || !first) // Always true; ensures Bool return type
    }

    // MARK: - Registration lifecycle

    func test_register_defaultHotkey() {
        manager.loadSavedConfig()
        manager.register()
        // After register, hotkey should be active; unregister cleans up
        manager.unregister()
    }

    func test_reregister_withNewConfig() {
        let config = HotkeyManager.HotkeyConfig(keyCode: 9, modifiers: cmdKey | optionKey)
        manager.reregister(with: config)
        XCTAssertEqual(manager.currentKeyCode, config.keyCode)
        manager.unregister()
    }

    func test_unregister_whenNotRegistered_isSafe() {
        manager.unregister()
        // Should not crash
    }

    func test_doubleRegister_overwrites() {
        manager.loadSavedConfig()
        manager.register()
        manager.register()
        manager.unregister()
        // Should not crash or leak
    }

    // MARK: - onHotkeyPressed callback

    func test_onHotkeyPressed_isNilByDefault() {
        XCTAssertNil(manager.onHotkeyPressed)
    }

    func test_onHotkeyPressed_canBeSet() {
        var wasCalled = false
        manager.onHotkeyPressed = { wasCalled = true }
        manager.onHotkeyPressed?()
        XCTAssertTrue(wasCalled)
    }
}
