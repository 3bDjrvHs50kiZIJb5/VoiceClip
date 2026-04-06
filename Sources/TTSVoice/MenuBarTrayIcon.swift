import AppKit
import SwiftUI

/// 菜单栏托盘：使用 `tray-icon-dark`（与 `Resources/tray-icon-dark.png` 一致）。
struct MenuBarTrayIcon: View {
    /// 菜单栏点尺寸；略大于 Electron 默认 18，便于看清。
    private static let menuBarSide: CGFloat = 20

    var body: some View {
        Group {
            if let image = loadMenuBarImage() {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: Self.menuBarSide, height: Self.menuBarSide)
                    .fixedSize()
            } else {
                Image(systemName: "waveform")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: Self.menuBarSide, height: Self.menuBarSide)
            }
        }
        .accessibilityLabel("TTS Voice")
    }

    /// 在内存里缩放到目标边长，避免 `Image` + `resizable` 与源图尺寸叠加导致偏大/偏小。
    private func loadMenuBarImage() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "tray-icon-dark", withExtension: "png"),
              let source = NSImage(contentsOf: url) else {
            return nil
        }
        return Self.scaleImage(source, sideLength: Self.menuBarSide)
    }

    private static func scaleImage(_ image: NSImage, sideLength: CGFloat) -> NSImage {
        let size = NSSize(width: sideLength, height: sideLength)
        let scaled = NSImage(size: size)
        scaled.lockFocus()
        defer { scaled.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high
        let src = image.size
        guard src.width > 0, src.height > 0 else {
            return scaled
        }

        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: src),
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        scaled.isTemplate = false
        return scaled
    }
}
