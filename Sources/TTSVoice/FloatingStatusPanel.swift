import AppKit
import SwiftUI

/// 简易底部状态条，对应 Electron 的透明播放器窗口（非 Web 跑马灯，仅展示当前提示）。
final class FloatingStatusPanel {
    private var panel: NSPanel?
    private var hosting: NSHostingController<StatusBannerView>?

    func show(message: String) {
        DispatchQueue.main.async {
            if self.panel == nil {
                let content = StatusBannerView(message: message)
                let host = NSHostingController(rootView: content)
                self.hosting = host

                let panel = NSPanel(
                    contentRect: NSRect(x: 0, y: 0, width: 520, height: 88),
                    styleMask: [.nonactivatingPanel, .borderless],
                    backing: .buffered,
                    defer: false
                )
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.level = .floating
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                panel.hasShadow = true
                panel.hidesOnDeactivate = false
                panel.contentViewController = host
                panel.isReleasedWhenClosed = false
                self.panel = panel
            } else {
                self.hosting?.rootView = StatusBannerView(message: message)
            }

            self.positionPanel()
            self.panel?.orderFrontRegardless()
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.panel?.orderOut(nil)
        }
    }

    private func positionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let x = frame.midX - size.width / 2
        let y = frame.minY + 48
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct StatusBannerView: View {
    var message: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "waveform")
                .foregroundStyle(.secondary)
            Text(message)
                .lineLimit(2)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
        .frame(width: 520, height: 88)
    }
}
