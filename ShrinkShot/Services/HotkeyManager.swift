import Cocoa
import Carbon

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {}

    func start() {
        installEventHandler()
        registerHotKeyIfNeeded()

        // 設定変更時にホットキーを再登録
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        unregisterHotKey()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    @objc private func settingsChanged() {
        unregisterHotKey()
        registerHotKeyIfNeeded()
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                HotkeyManager.shared.handleHotKey()
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        if status != noErr {
            print("Failed to install event handler: \(status)")
        }
    }

    private func registerHotKeyIfNeeded() {
        let keyCode = UserDefaults.standard.integer(forKey: AppSettings.hotkeyKeyCode)
        let modifiers = UserDefaults.standard.integer(forKey: AppSettings.hotkeyModifiers)

        guard keyCode != 0 || modifiers != 0 else { return }

        let carbonModifiers = convertToCarbonModifiers(modifiers)

        var hotKeyID = EventHotKeyID(
            signature: OSType(0x5348524B), // "SHRK"
            id: 1
        )

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("Failed to register hotkey: \(status)")
        } else {
            let display = HotkeyManager.displayString(keyCode: keyCode, modifiers: modifiers)
            print("Hotkey registered: \(display)")
        }
    }

    private func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func handleHotKey() {
        let current = UserDefaults.standard.bool(forKey: AppSettings.isEnabled)
        UserDefaults.standard.set(!current, forKey: AppSettings.isEnabled)
        print("Hotkey toggled: \(!current ? "ON" : "OFF")")
    }

    /// NSEvent modifiers → Carbon modifiers に変換
    private func convertToCarbonModifiers(_ modifiers: Int) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        var carbonMods: UInt32 = 0

        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }

        return carbonMods
    }

    // MARK: - Display

    static func displayString(keyCode: Int, modifiers: Int) -> String {
        guard keyCode != 0 || modifiers != 0 else { return "" }

        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))

        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        if let keyString = keyCodeToString(keyCode) {
            parts.append(keyString)
        }

        return parts.joined()
    }

    private static func keyCodeToString(_ keyCode: Int) -> String? {
        let keyMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            51: "⌫", 53: "⎋",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 109: "F10", 111: "F12", 103: "F11",
            118: "F4", 120: "F2", 122: "F1",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyMap[keyCode]
    }
}
