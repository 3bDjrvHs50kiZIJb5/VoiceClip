import AppKit
import Foundation
import UserNotifications

@MainActor
final class AppController: ObservableObject {
    @Published var settings: AppSettings = .defaults
    /// 首次从磁盘加载并注册快捷键完成后为 `true`，用于设置页同步草稿。
    @Published private(set) var settingsReady = false

    private let store = SettingsStore()
    private let ttsService = TTSService()
    private let hotkeyManager = GlobalHotkeyManager()
    private let audioPlayer = QueuedAudioPlayer()
    private let hud = FloatingStatusPanel()

    private var appState: AppState = .idle
    private var inFlight = false
    private var lastChunkJobId = 0

    init() {
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        defer { settingsReady = true }

        UNUserNotificationCenter.current().delegate = nil
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])

        do {
            let loaded = try store.load()
            settings = loaded
            try applyHotkey(loaded.readHotkey)
        } catch {
            notify(title: "TTS Voice", body: error.localizedDescription)
        }

        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.reregisterHotkeyAfterWake() }
        }
    }

    private func reregisterHotkeyAfterWake() async {
        do {
            let latest = try store.load()
            try applyHotkey(latest.readHotkey)
        } catch {
            // 与 Electron 一致：唤醒失败不打扰用户
        }
    }

    /// 由 SwiftUI 注入（`openSettings`），避免使用 `showSettingsWindow:` 触发 SwiftUI Fault。
    private var openSettingsHandler: (() -> Void)?

    func setOpenSettingsHandler(_ handler: @escaping () -> Void) {
        openSettingsHandler = handler
    }

    func openSettings() {
        if let openSettingsHandler {
            openSettingsHandler()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    func saveFromUI(_ next: AppSettings) async throws -> AppSettings {
        let saved = try store.save(next)
        settings = saved
        try applyHotkey(saved.readHotkey)
        return saved
    }

    private func applyHotkey(_ accelerator: String) throws {
        try hotkeyManager.register(accelerator: accelerator) { [weak self] in
            Task { await self?.handleReadSelection() }
        }
    }

    func handleReadSelection() async {
        if appState == .playing || appState == .synthesizing {
            return
        }

        if inFlight {
            notify(title: "TTS Voice", body: "正在处理上一次操作，请稍候再试")
            return
        }

        inFlight = true
        defer { inFlight = false }

        do {
            if appState == .error {
                appState = .idle
            }

            hud.show(message: "正在读取选中文本…")

            let current = try store.load()
            if current.ttsAppId.isEmpty || current.ttsBearerToken.isEmpty {
                hud.hide()
                openSettings()
                notify(title: "TTS Voice", body: "请先完成 TTS 配置")
                return
            }

            let text = try await SelectionReader.readSelectedText()
            if text.isEmpty {
                hud.hide()
                notify(title: "TTS Voice", body: "未获取到选中文本，请先复制或重新选择内容")
                return
            }

            hud.show(message: "正在识别选中文本…")

            if text.count < 10 {
                hud.show(message: "您选择的文本内容太少了，不予转换")
                try await Task.sleep(nanoseconds: 2_600_000_000)
                hud.hide()
                return
            }

            hud.show(message: "正在生成语音…")

            let config = store.toTtsConfig(current)

            try await ttsService.speak(
                text: text,
                config: config,
                onState: { [weak self] state in
                    Task { @MainActor in
                        self?.appState = state
                    }
                },
                onChunk: { [weak self] jobId, _, _, audio in
                    Task { @MainActor in
                        guard let self else { return }
                        if jobId != self.lastChunkJobId {
                            self.audioPlayer.clear()
                            self.lastChunkJobId = jobId
                        }
                        self.appState = .playing
                        self.audioPlayer.enqueue(audio)
                    }
                }
            )

            hud.hide()
            notify(title: "TTS Voice", body: "开始朗读：\(String(text.prefix(24)))")
        } catch {
            audioPlayer.clear()
            hud.hide()
            appState = .idle
            notify(title: "TTS Voice", body: error.localizedDescription)
        }
    }

    func stopPlayback() {
        Task {
            await ttsService.stop()
            audioPlayer.clear()
            hud.hide()
            appState = .idle
        }
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
