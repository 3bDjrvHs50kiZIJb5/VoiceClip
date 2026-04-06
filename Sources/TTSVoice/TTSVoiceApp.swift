import AppKit
import SwiftUI

@main
struct TTSVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController()

    var body: some Scene {
        MenuBarExtra {
            Group {
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Text("打开设置")
                    }
                } else {
                    Button("打开设置") {
                        controller.openSettings()
                    }
                }
                Button("朗读当前选中文本") {
                    Task { await controller.handleReadSelection() }
                }
                Divider()
                Button("停止播放") {
                    controller.stopPlayback()
                }
                Divider()
                Button("退出") {
                    NSApp.terminate(nil)
                }
            }
            .background {
                if #available(macOS 14.0, *) {
                    OpenSettingsRegistrar(controller: controller)
                }
            }
        } label: {
            MenuBarTrayIcon()
        }

        Settings {
            SettingsView(controller: controller)
        }
    }
}

@available(macOS 14.0, *)
private struct OpenSettingsRegistrar: View {
    @ObservedObject var controller: AppController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                controller.setOpenSettingsHandler {
                    openSettings()
                }
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let image = applicationIconFromBundle() {
            NSApp.applicationIconImage = image
        }
    }

    /// `.app` 内优先 `AppIcon.icns`；开发运行无 icns 时用 `app-icon.png`（与 `tray-icon-light` 同源）。
    private func applicationIconFromBundle() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.module.url(forResource: "tray-icon-light", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.module.url(forResource: "app-icon", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}

private struct SettingsView: View {
    @ObservedObject var controller: AppController

    @State private var draft = AppSettings.defaults
    @State private var message = ""
    @State private var messageIsError = false
    @State private var isSaving = false
    @State private var hotkeyHint = ""

    private let voiceOptions: [(id: String, title: String)] = [
        ("BV001_streaming", "女生语音"),
        ("BV002_streaming", "男生语音"),
    ]

    var body: some View {
        Form {
            Section {
                TextField("TTS App ID", text: $draft.ttsAppId)
                SecureField("TTS Bearer Token", text: $draft.ttsBearerToken)
                Picker("音色（Voice Type）", selection: $draft.voiceType) {
                    ForEach(voiceOptions, id: \.id) { item in
                        Text(item.title).tag(item.id)
                    }
                }
                HStack {
                    Text("语速（Speed Ratio）")
                    Slider(value: $draft.speedRatio, in: 0.8 ... 1.8, step: 0.1)
                    Text(String(format: "%.1f", draft.speedRatio))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            } header: {
                Text("语音合成")
            } footer: {
                Text("与 Electron 设置页一致：App ID、Token、音色与语速。")
                    .font(.footnote)
            }

            Section {
                hotkeyRow
                Text(hotkeyHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(
                    "单独使用 F1–F12 时可能被系统占用；若无反应，请改用 Command / Control / Shift 与字母组合，或在「系统设置 → 键盘」中开启「将 F1、F2 等键用作标准功能键」。"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            } header: {
                Text("朗读快捷键")
            } footer: {
                Text(
                    "朗读热键使用系统级注册，通常不依赖辅助功能。划词复制仍须在「辅助功能」中授权；请尽量只使用同一安装路径（例如仅使用「应用程序」里的 .app），不要交替用 Xcode 调试与正式包，否则 macOS 会视为不同程序而需分别勾选。"
                )
                .font(.footnote)
            }

            Section {
                HStack {
                    Text("音量（Volume Ratio）")
                    Slider(value: $draft.volumeRatio, in: 0.5 ... 2.0, step: 0.1)
                    Text(String(format: "%.1f", draft.volumeRatio))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                HStack {
                    Text("音调（Pitch Ratio）")
                    Slider(value: $draft.pitchRatio, in: 0.5 ... 2.0, step: 0.1)
                    Text(String(format: "%.1f", draft.pitchRatio))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            } header: {
                Text("高级（可选）")
            } footer: {
                Text("对应 Node 版 `tts/core.js` 中的 volume_ratio / pitch_ratio。")
                    .font(.footnote)
            }

            Section {
                TextField("Cluster", text: $draft.cluster)
                TextField("Endpoint", text: $draft.endpoint)
                TextField("UID", text: $draft.uid)
                TextField("Encoding", text: $draft.encoding)
            } header: {
                Text("服务端参数")
            } footer: {
                Text("一般无需修改；与桌面版共用同一 `settings.json` 时会一并读写。")
                    .font(.footnote)
            }

            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundStyle(messageIsError ? Color.red : Color.green)
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button(isSaving ? "保存中…" : "保存设置") {
                        Task {
                            isSaving = true
                            message = ""
                            do {
                                let saved = try await controller.saveFromUI(draft)
                                draft = saved
                                message = "保存成功"
                                messageIsError = false
                            } catch {
                                message = error.localizedDescription
                                messageIsError = true
                            }
                            isSaving = false
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaving)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(minWidth: 560, minHeight: 640)
        .onAppear {
            draft = controller.settings
        }
        .onChange(of: controller.settingsReady) { ready in
            if ready {
                draft = controller.settings
            }
        }
    }

    private var hotkeyRow: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )

            Text(draft.readHotkey.isEmpty ? "点击后按下快捷键" : draft.readHotkey)
                .foregroundStyle(draft.readHotkey.isEmpty ? .secondary : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            HotkeyCaptureField(accelerator: $draft.readHotkey, hint: $hotkeyHint)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .frame(height: 36)
    }
}
