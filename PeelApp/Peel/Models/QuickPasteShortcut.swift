import AppKit
import Carbon.HIToolbox

struct QuickPasteShortcut: Codable, Equatable, Hashable {
    let keyCode: UInt16
    let modifierFlagsRawValue: UInt

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        modifierFlagsRawValue = modifiers.normalizedShortcutFlags.rawValue
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue).normalizedShortcutFlags
    }

    var displayString: String {
        let modifierSymbols = [
            modifiers.contains(.control) ? "⌃" : "",
            modifiers.contains(.option) ? "⌥" : "",
            modifiers.contains(.shift) ? "⇧" : "",
            modifiers.contains(.command) ? "⌘" : ""
        ].joined()

        return modifierSymbols + keyDisplay
    }

    var keyDisplay: String {
        Self.keyDisplays[Int(keyCode)] ?? "Key \(keyCode)"
    }

    var carbonModifiers: UInt32 {
        var flags: UInt32 = 0

        if modifiers.contains(.command) {
            flags |= UInt32(cmdKey)
        }

        if modifiers.contains(.option) {
            flags |= UInt32(optionKey)
        }

        if modifiers.contains(.control) {
            flags |= UInt32(controlKey)
        }

        if modifiers.contains(.shift) {
            flags |= UInt32(shiftKey)
        }

        return flags
    }

    static let `default` = QuickPasteShortcut(keyCode: 9, modifiers: [.control, .option])

    static func captureCandidate(from event: NSEvent) -> QuickPasteShortcut? {
        let modifiers = event.modifierFlags.normalizedShortcutFlags
        guard !modifiers.isEmpty else {
            return nil
        }

        return QuickPasteShortcut(keyCode: event.keyCode, modifiers: modifiers)
    }

    private static let keyDisplays: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋", 65: ".", 67: "*",
        69: "+", 71: "Clear", 75: "/", 76: "↩", 78: "-", 81: "=", 82: "0", 83: "1",
        84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
        114: "Help", 115: "Home", 116: "Page Up", 117: "⌦", 118: "F4", 119: "End",
        120: "F2", 121: "Page Down", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}

struct QuickPasteShortcutValidator {
    static func validationMessage(for shortcut: QuickPasteShortcut) -> String? {
        let modifiers = shortcut.modifiers

        guard modifiers.contains(.command) || modifiers.contains(.option) || modifiers.contains(.control) else {
            return "快捷键至少要包含 Control、Option 或 Command。"
        }

        if modifiers == [.shift] {
            return "不能只用 Shift，请再加一个常用修饰键。"
        }

        if reservedShortcuts.contains(shortcut) {
            return "这个组合和应用里已有快捷键冲突，请换一个。"
        }

        return nil
    }

    private static let reservedShortcuts: Set<QuickPasteShortcut> = [
        QuickPasteShortcut(keyCode: 45, modifiers: [.command]),
        QuickPasteShortcut(keyCode: 31, modifiers: [.command]),
        QuickPasteShortcut(keyCode: 1, modifiers: [.command]),
        QuickPasteShortcut(keyCode: 1, modifiers: [.command, .shift]),
        QuickPasteShortcut(keyCode: 7, modifiers: [.command]),
        QuickPasteShortcut(keyCode: 8, modifiers: [.command]),
        QuickPasteShortcut(keyCode: 9, modifiers: [.command]),
        QuickPasteShortcut(keyCode: 0, modifiers: [.command]),
        QuickPasteShortcut(keyCode: 11, modifiers: [.command]),
        QuickPasteShortcut(keyCode: 11, modifiers: [.command, .shift]),
        QuickPasteShortcut(keyCode: 43, modifiers: [.command]),
        QuickPasteShortcut(keyCode: 12, modifiers: [.command]),
        QuickPasteShortcut(keyCode: 13, modifiers: [.command]),
        QuickPasteShortcut(keyCode: 4, modifiers: [.command]),
        QuickPasteShortcut(keyCode: 46, modifiers: [.command])
    ]
}

private extension NSEvent.ModifierFlags {
    var normalizedShortcutFlags: NSEvent.ModifierFlags {
        intersection([.command, .option, .control, .shift])
    }
}
