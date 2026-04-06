import AppKit
import Carbon.HIToolbox
import Foundation

/// 使用 Carbon `RegisterEventHotKey` 注册系统级快捷键（不依赖「辅助功能」监听键盘）。
/// 划词复制仍需要辅助功能，与快捷键分开。
final class GlobalHotkeyManager {
    private struct Parsed {
        var modifierFlags: NSEvent.ModifierFlags
        var keyCode: UInt16
    }

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var fireHandler: (() -> Void)?

    private static let hotKeySignature: OSType = {
        let s = "TTS1"
        var value: UInt32 = 0
        for byte in s.utf8 {
            value = (value << 8) | UInt32(byte)
        }
        return OSType(value)
    }()

    private static var nextHotKeyId: UInt32 = 1

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        fireHandler = nil
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    /// 注册全局快捷键；失败时抛出，调用方负责提示。
    func register(accelerator: String, handler: @escaping () -> Void) throws {
        unregister()

        let parsed = try Self.parseAccelerator(accelerator)
        fireHandler = handler

        if eventHandler == nil {
            try installKeyboardHandlerIfNeeded()
        }

        let mods = Self.carbonModifiers(from: parsed.modifierFlags)
        let hotKeyNumericId = Self.nextHotKeyId
        Self.nextHotKeyId &+= 1
        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: hotKeyNumericId)

        let status = RegisterEventHotKey(
            UInt32(parsed.keyCode),
            mods,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, hotKeyRef != nil else {
            throw NSError(
                domain: "TTSVoice",
                code: 34,
                userInfo: [NSLocalizedDescriptionKey: "快捷键注册失败（可能被系统或其他应用占用）"]
            )
        }
    }

    private func installKeyboardHandlerIfNeeded() throws {
        var eventType = EventTypeSpec(eventClass: UInt32(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.carbonHotKeyCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard status == noErr else {
            throw NSError(domain: "TTSVoice", code: 35, userInfo: [NSLocalizedDescriptionKey: "无法安装快捷键事件处理"])
        }
    }

    fileprivate func invokeHotKey() {
        DispatchQueue.main.async { [weak self] in
            self?.fireHandler?()
        }
    }

    private static let carbonHotKeyCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
        guard let userData else { return OSStatus(eventNotHandledErr) }
        let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
        manager.invokeHotKey()
        return noErr
    }

    /// 与 `parseAccelerator` 一致：`CommandOrControl` 已映射为 `.command`，显式 `Control` 保留为 `.control`，不再合并，便于 Carbon 区分 Cmd / Ctrl。
    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let f = flags.intersection(.deviceIndependentFlagsMask)
        var result: UInt32 = 0
        if f.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if f.contains(.control) {
            result |= UInt32(controlKey)
        }
        if f.contains(.shift) {
            result |= UInt32(shiftKey)
        }
        if f.contains(.option) {
            result |= UInt32(optionKey)
        }
        return result
    }

    private static func parseAccelerator(_ value: String) throws -> Parsed {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "TTSVoice", code: 30, userInfo: [NSLocalizedDescriptionKey: "快捷键为空"])
        }

        let parts = trimmed.split(separator: "+").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let primary = parts.last else {
            throw NSError(domain: "TTSVoice", code: 31, userInfo: [NSLocalizedDescriptionKey: "快捷键格式无效"])
        }

        var modifiers: NSEvent.ModifierFlags = []
        for part in parts.dropLast() {
            switch part {
            case "CommandOrControl", "Command":
                modifiers.insert(.command)
            case "Control":
                modifiers.insert(.control)
            case "Alt", "Option":
                modifiers.insert(.option)
            case "Shift":
                modifiers.insert(.shift)
            case "Super":
                modifiers.insert(.command)
            default:
                throw NSError(domain: "TTSVoice", code: 32, userInfo: [NSLocalizedDescriptionKey: "未知修饰键: \(part)"])
            }
        }

        guard let keyCode = keyCode(forPrimaryKey: primary) else {
            throw NSError(domain: "TTSVoice", code: 33, userInfo: [NSLocalizedDescriptionKey: "无法映射主键: \(primary)"])
        }

        return Parsed(modifierFlags: modifiers, keyCode: keyCode)
    }

    private static func keyCode(forPrimaryKey primary: String) -> UInt16? {
        if primary.hasPrefix("F"), primary.count >= 2 {
            let n = Int(primary.dropFirst()) ?? 0
            guard n >= 1, n <= 24 else { return nil }
            let table: [UInt16] = [
                UInt16(kVK_F1), UInt16(kVK_F2), UInt16(kVK_F3), UInt16(kVK_F4),
                UInt16(kVK_F5), UInt16(kVK_F6), UInt16(kVK_F7), UInt16(kVK_F8),
                UInt16(kVK_F9), UInt16(kVK_F10), UInt16(kVK_F11), UInt16(kVK_F12),
                UInt16(kVK_F13), UInt16(kVK_F14), UInt16(kVK_F15), UInt16(kVK_F16),
                UInt16(kVK_F17), UInt16(kVK_F18), UInt16(kVK_F19), UInt16(kVK_F20),
            ]
            if n <= table.count {
                return table[n - 1]
            }
            return nil
        }

        if primary.count == 1 {
            let digitCodes: [UInt16] = [
                UInt16(kVK_ANSI_0), UInt16(kVK_ANSI_1), UInt16(kVK_ANSI_2), UInt16(kVK_ANSI_3), UInt16(kVK_ANSI_4),
                UInt16(kVK_ANSI_5), UInt16(kVK_ANSI_6), UInt16(kVK_ANSI_7), UInt16(kVK_ANSI_8), UInt16(kVK_ANSI_9),
            ]
            if let value = Int(primary), value >= 0, value <= 9 {
                return digitCodes[value]
            }

            let upper = primary.uppercased()
            let map: [String: UInt16] = [
                "A": UInt16(kVK_ANSI_A), "B": UInt16(kVK_ANSI_B), "C": UInt16(kVK_ANSI_C), "D": UInt16(kVK_ANSI_D),
                "E": UInt16(kVK_ANSI_E), "F": UInt16(kVK_ANSI_F), "G": UInt16(kVK_ANSI_G), "H": UInt16(kVK_ANSI_H),
                "I": UInt16(kVK_ANSI_I), "J": UInt16(kVK_ANSI_J), "K": UInt16(kVK_ANSI_K), "L": UInt16(kVK_ANSI_L),
                "M": UInt16(kVK_ANSI_M), "N": UInt16(kVK_ANSI_N), "O": UInt16(kVK_ANSI_O), "P": UInt16(kVK_ANSI_P),
                "Q": UInt16(kVK_ANSI_Q), "R": UInt16(kVK_ANSI_R), "S": UInt16(kVK_ANSI_S), "T": UInt16(kVK_ANSI_T),
                "U": UInt16(kVK_ANSI_U), "V": UInt16(kVK_ANSI_V), "W": UInt16(kVK_ANSI_W), "X": UInt16(kVK_ANSI_X),
                "Y": UInt16(kVK_ANSI_Y), "Z": UInt16(kVK_ANSI_Z),
            ]
            return map[upper]
        }

        let named: [String: UInt16] = [
            "Space": UInt16(kVK_Space),
            "Tab": UInt16(kVK_Tab),
            "Enter": UInt16(kVK_Return),
            "Escape": UInt16(kVK_Escape),
            "Backspace": UInt16(kVK_Delete),
            "Delete": UInt16(kVK_ForwardDelete),
            "Insert": UInt16(kVK_Help),
            "Home": UInt16(kVK_Home),
            "End": UInt16(kVK_End),
            "PageUp": UInt16(kVK_PageUp),
            "PageDown": UInt16(kVK_PageDown),
            "Up": UInt16(kVK_UpArrow),
            "Down": UInt16(kVK_DownArrow),
            "Left": UInt16(kVK_LeftArrow),
            "Right": UInt16(kVK_RightArrow),
        ]

        return named[primary]
    }
}
