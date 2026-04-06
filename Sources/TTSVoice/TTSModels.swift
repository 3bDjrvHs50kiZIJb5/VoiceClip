import Foundation

/// 与 Electron `settings-store` / `preload` 保存结构对齐，便于共用配置思路。
struct AppSettings: Codable, Equatable {
    var ttsAppId: String
    var ttsBearerToken: String
    var cluster: String
    var voiceType: String
    var endpoint: String
    var uid: String
    var encoding: String
    var speedRatio: Double
    var volumeRatio: Double
    var pitchRatio: Double
    var readHotkey: String

    static let defaults = AppSettings(
        ttsAppId: "",
        ttsBearerToken: "",
        cluster: "volcano_tts",
        voiceType: "BV001_streaming",
        endpoint: "https://openspeech.bytedance.com/api/v1/tts",
        uid: "tts-voice-desktop",
        encoding: "wav",
        speedRatio: 1.5,
        volumeRatio: 1,
        pitchRatio: 1,
        readHotkey: "CommandOrControl+Shift+L"
    )
}

enum AppState: String {
    case idle
    case synthesizing
    case playing
    case error
}
