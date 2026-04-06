import AppKit
import ApplicationServices
import Foundation

/// 对应 Electron `selection/macos.js`：模拟 Cmd+C 并从剪贴板取词。
enum SelectionReader {
    /// 仅划词需要辅助功能；`prompt:true` 每次调用会打扰用户，故每进程最多弹一次系统引导。
    private static var didShowAccessibilityPrompt = false

    private static func waitForClipboardChange(previousText: String, timeoutMs: Int = 1200, intervalMs: Int = 60) async -> String {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        var lastNonEmpty = previousText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : previousText

        while Date() < deadline {
            let current = NSPasteboard.general.string(forType: .string) ?? ""
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if current != previousText {
                    return current
                }
                lastNonEmpty = current
            }
            try? await Task.sleep(nanoseconds: UInt64(intervalMs) * 1_000_000)
        }

        let fallback = NSPasteboard.general.string(forType: .string) ?? ""
        let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFallback.isEmpty {
            return fallback
        }
        return lastNonEmpty
    }

    private static func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts: NSDictionary = [key: prompt]
        return AXIsProcessTrustedWithOptions(opts)
    }

    static func readSelectedText() async throws -> String {
        if isAccessibilityTrusted(prompt: false) {
            return try await performCopyAndRead()
        }

        if !didShowAccessibilityPrompt {
            didShowAccessibilityPrompt = true
            _ = isAccessibilityTrusted(prompt: true)
        }

        guard isAccessibilityTrusted(prompt: false) else {
            throw NSError(
                domain: "TTSVoice",
                code: 20,
                userInfo: [NSLocalizedDescriptionKey: "请在「系统设置 → 隐私与安全性 → 辅助功能」中勾选本应用。若已勾选仍无效，请确认始终从同一安装包启动（勿混用 Xcode 调试与正式 .app，系统按路径区分）。"]
            )
        }

        return try await performCopyAndRead()
    }

    private static func performCopyAndRead() async throws -> String {
        let previousText = NSPasteboard.general.string(forType: .string) ?? ""

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", #"tell application "System Events" to keystroke "c" using command down"#]

        try task.run()
        task.waitUntilExit()

        try await Task.sleep(nanoseconds: 80_000_000)

        let copied = await waitForClipboardChange(previousText: previousText)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(previousText, forType: .string)

        return copied.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
