import AppKit
import Carbon.HIToolbox
import Foundation

/// 与 Electron `App.jsx` 中 `buildAccelerator` 一致：把一次按键事件转成 accelerator 字符串。
enum HotkeyAcceleratorBuilder {
    static func build(from event: NSEvent) -> String? {
        guard let primary = primaryKeyLabel(for: event) else {
            return nil
        }

        var parts: [String] = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.command) || flags.contains(.control) {
            parts.append("CommandOrControl")
        }

        if flags.contains(.option) {
            parts.append("Alt")
        }

        if flags.contains(.shift) {
            parts.append("Shift")
        }

        parts.append(primary)
        return parts.joined(separator: "+")
    }

    private static func primaryKeyLabel(for event: NSEvent) -> String? {
        let keyCode = event.keyCode

        let functionPairs: [(UInt16, String)] = [
            (UInt16(kVK_F1), "F1"), (UInt16(kVK_F2), "F2"), (UInt16(kVK_F3), "F3"), (UInt16(kVK_F4), "F4"),
            (UInt16(kVK_F5), "F5"), (UInt16(kVK_F6), "F6"), (UInt16(kVK_F7), "F7"), (UInt16(kVK_F8), "F8"),
            (UInt16(kVK_F9), "F9"), (UInt16(kVK_F10), "F10"), (UInt16(kVK_F11), "F11"), (UInt16(kVK_F12), "F12"),
            (UInt16(kVK_F13), "F13"), (UInt16(kVK_F14), "F14"), (UInt16(kVK_F15), "F15"), (UInt16(kVK_F16), "F16"),
            (UInt16(kVK_F17), "F17"), (UInt16(kVK_F18), "F18"), (UInt16(kVK_F19), "F19"), (UInt16(kVK_F20), "F20"),
        ]

        if let hit = functionPairs.first(where: { $0.0 == keyCode }) {
            return hit.1
        }

        let digitCodes: [(UInt16, String)] = [
            (UInt16(kVK_ANSI_0), "0"), (UInt16(kVK_ANSI_1), "1"), (UInt16(kVK_ANSI_2), "2"),
            (UInt16(kVK_ANSI_3), "3"), (UInt16(kVK_ANSI_4), "4"), (UInt16(kVK_ANSI_5), "5"),
            (UInt16(kVK_ANSI_6), "6"), (UInt16(kVK_ANSI_7), "7"), (UInt16(kVK_ANSI_8), "8"),
            (UInt16(kVK_ANSI_9), "9"),
        ]

        if let hit = digitCodes.first(where: { $0.0 == keyCode }) {
            return hit.1
        }

        let letterCodes: [(UInt16, String)] = [
            (UInt16(kVK_ANSI_A), "A"), (UInt16(kVK_ANSI_B), "B"), (UInt16(kVK_ANSI_C), "C"), (UInt16(kVK_ANSI_D), "D"),
            (UInt16(kVK_ANSI_E), "E"), (UInt16(kVK_ANSI_F), "F"), (UInt16(kVK_ANSI_G), "G"), (UInt16(kVK_ANSI_H), "H"),
            (UInt16(kVK_ANSI_I), "I"), (UInt16(kVK_ANSI_J), "J"), (UInt16(kVK_ANSI_K), "K"), (UInt16(kVK_ANSI_L), "L"),
            (UInt16(kVK_ANSI_M), "M"), (UInt16(kVK_ANSI_N), "N"), (UInt16(kVK_ANSI_O), "O"), (UInt16(kVK_ANSI_P), "P"),
            (UInt16(kVK_ANSI_Q), "Q"), (UInt16(kVK_ANSI_R), "R"), (UInt16(kVK_ANSI_S), "S"), (UInt16(kVK_ANSI_T), "T"),
            (UInt16(kVK_ANSI_U), "U"), (UInt16(kVK_ANSI_V), "V"), (UInt16(kVK_ANSI_W), "W"), (UInt16(kVK_ANSI_X), "X"),
            (UInt16(kVK_ANSI_Y), "Y"), (UInt16(kVK_ANSI_Z), "Z"),
        ]

        if let hit = letterCodes.first(where: { $0.0 == keyCode }) {
            return hit.1
        }

        let named: [(UInt16, String)] = [
            (UInt16(kVK_Space), "Space"),
            (UInt16(kVK_Tab), "Tab"),
            (UInt16(kVK_Return), "Enter"),
            (UInt16(kVK_Escape), "Escape"),
            (UInt16(kVK_Delete), "Backspace"),
            (UInt16(kVK_ForwardDelete), "Delete"),
            (UInt16(kVK_Help), "Insert"),
            (UInt16(kVK_Home), "Home"),
            (UInt16(kVK_End), "End"),
            (UInt16(kVK_PageUp), "PageUp"),
            (UInt16(kVK_PageDown), "PageDown"),
            (UInt16(kVK_UpArrow), "Up"),
            (UInt16(kVK_DownArrow), "Down"),
            (UInt16(kVK_LeftArrow), "Left"),
            (UInt16(kVK_RightArrow), "Right"),
        ]

        if let hit = named.first(where: { $0.0 == keyCode }) {
            return hit.1
        }

        return nil
    }
}
