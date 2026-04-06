import Foundation

/// 对应 Electron `settings-store.js` 中的快捷键校验与归一化。
enum HotkeyParser {
    private static let validModifiers: Set<String> = [
        "CommandOrControl", "Command", "Control", "Alt", "Option", "Shift", "Super",
    ]

    private static var validKeys: Set<String> = {
        var keys = Set<String>()
        keys.formUnion(["Space", "Tab", "Enter", "Escape", "Backspace", "Delete", "Insert", "Home", "End", "PageUp", "PageDown", "Up", "Down", "Left", "Right"])
        for i in 1 ... 24 { keys.insert("F\(i)") }
        for i in 0 ... 9 { keys.insert(String(i)) }
        for code in 65 ... 90 { keys.insert(String(UnicodeScalar(code)!)) }
        return keys
    }()

    static func normalizeReadHotkey(_ input: String) throws -> String {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = raw.isEmpty ? AppSettings.defaults.readHotkey : raw

        guard !value.isEmpty else {
            throw NSError(domain: "TTSVoice", code: 10, userInfo: [NSLocalizedDescriptionKey: "请设置朗读快捷键"])
        }

        let parts = value.split(separator: "+").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !parts.isEmpty else {
            throw NSError(domain: "TTSVoice", code: 11, userInfo: [NSLocalizedDescriptionKey: "快捷键格式无效"])
        }

        var modifiers: [String] = []
        var primaryKey = ""

        for part in parts {
            if validModifiers.contains(part) {
                if !modifiers.contains(part) {
                    modifiers.append(part)
                }
                continue
            }

            if !primaryKey.isEmpty {
                throw NSError(domain: "TTSVoice", code: 12, userInfo: [NSLocalizedDescriptionKey: "快捷键只能包含一个主键"])
            }

            guard validKeys.contains(part) else {
                throw NSError(domain: "TTSVoice", code: 13, userInfo: [NSLocalizedDescriptionKey: "暂不支持的快捷键: \(part)"])
            }

            primaryKey = part
        }

        guard !primaryKey.isEmpty else {
            throw NSError(domain: "TTSVoice", code: 14, userInfo: [NSLocalizedDescriptionKey: "快捷键必须包含一个非修饰键"])
        }

        return (modifiers + [primaryKey]).joined(separator: "+")
    }

    /// 对应 `normalizeSettings`：先合并默认，再裁剪字符串并校验快捷键。
    static func normalizeSettings(_ input: AppSettings) throws -> AppSettings {
        var merged = AppSettings.defaults
        merged.ttsAppId = input.ttsAppId.trimmingCharacters(in: .whitespacesAndNewlines)
        merged.ttsBearerToken = input.ttsBearerToken.trimmingCharacters(in: .whitespacesAndNewlines)

        let cluster = input.cluster.trimmingCharacters(in: .whitespacesAndNewlines)
        merged.cluster = cluster.isEmpty ? AppSettings.defaults.cluster : cluster

        let voiceType = input.voiceType.trimmingCharacters(in: .whitespacesAndNewlines)
        merged.voiceType = voiceType.isEmpty ? AppSettings.defaults.voiceType : voiceType

        let endpoint = input.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        merged.endpoint = endpoint.isEmpty ? AppSettings.defaults.endpoint : endpoint

        let uid = input.uid.trimmingCharacters(in: .whitespacesAndNewlines)
        merged.uid = uid.isEmpty ? AppSettings.defaults.uid : uid

        let encoding = input.encoding.trimmingCharacters(in: .whitespacesAndNewlines)
        merged.encoding = encoding.isEmpty ? AppSettings.defaults.encoding : encoding

        merged.speedRatio = input.speedRatio
        merged.volumeRatio = input.volumeRatio
        merged.pitchRatio = input.pitchRatio

        let hotkeyRaw = input.readHotkey.trimmingCharacters(in: .whitespacesAndNewlines)
        merged.readHotkey = try normalizeReadHotkey(hotkeyRaw.isEmpty ? AppSettings.defaults.readHotkey : hotkeyRaw)

        return merged
    }

    /// 对应 `prepareSettings`：把新表单合并进当前配置，再归一化并校验必填项。
    static func prepareSettings(_ next: AppSettings, current: AppSettings) throws -> AppSettings {
        var merged = current
        merged.ttsAppId = next.ttsAppId
        merged.ttsBearerToken = next.ttsBearerToken
        merged.cluster = next.cluster
        merged.voiceType = next.voiceType
        merged.endpoint = next.endpoint
        merged.uid = next.uid
        merged.encoding = next.encoding
        merged.speedRatio = next.speedRatio
        merged.volumeRatio = next.volumeRatio
        merged.pitchRatio = next.pitchRatio
        merged.readHotkey = next.readHotkey

        let normalized = try normalizeSettings(merged)

        guard !normalized.ttsAppId.isEmpty else {
            throw NSError(domain: "TTSVoice", code: 15, userInfo: [NSLocalizedDescriptionKey: "请填写 TTS App ID"])
        }
        guard !normalized.ttsBearerToken.isEmpty else {
            throw NSError(domain: "TTSVoice", code: 16, userInfo: [NSLocalizedDescriptionKey: "请填写 TTS Bearer Token"])
        }

        return normalized
    }
}
