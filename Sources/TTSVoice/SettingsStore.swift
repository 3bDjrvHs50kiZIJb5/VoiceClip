import AppKit
import Foundation

/// 对应 Electron `settings-store.js`：读写 Application Support 下的 `settings.json`。
final class SettingsStore {
    private let fileURL: URL
    private var cache: AppSettings?

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        // 与 Electron `productName: TTS Voice` 的 userData 目录一致，便于共用 settings.json
        let dir = base.appendingPathComponent("TTS Voice", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("settings.json")
    }

    func load() throws -> AppSettings {
        if let cache {
            return cache
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let initial = AppSettings.defaults
            cache = initial
            return initial
        }
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        let normalized = try HotkeyParser.normalizeSettings(decoded)
        cache = normalized
        return normalized
    }

    func save(_ next: AppSettings) throws -> AppSettings {
        let current = try load()
        let prepared = try HotkeyParser.prepareSettings(next, current: current)
        cache = prepared
        let data = try JSONEncoder().encode(prepared)
        try data.write(to: fileURL, options: .atomic)
        return prepared
    }

    func toTtsConfig(_ settings: AppSettings) -> TTSConfig {
        TTSConfig(
            appId: settings.ttsAppId,
            bearerToken: settings.ttsBearerToken,
            cluster: settings.cluster,
            voiceType: settings.voiceType,
            endpoint: settings.endpoint,
            uid: settings.uid,
            encoding: settings.encoding,
            speedRatio: settings.speedRatio,
            volumeRatio: settings.volumeRatio,
            pitchRatio: settings.pitchRatio
        )
    }
}
