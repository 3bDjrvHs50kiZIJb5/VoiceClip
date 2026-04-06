import AppKit
import SwiftUI

/// 对应 Electron 设置页里「点击后按下快捷键」的只读输入框行为。
struct HotkeyCaptureField: NSViewRepresentable {
    @Binding var accelerator: String
    @Binding var hint: String

    func makeCoordinator() -> Coordinator {
        Coordinator(accelerator: $accelerator, hint: $hint)
    }

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? KeyCaptureNSView else { return }
        view.coordinator = context.coordinator
    }

    final class Coordinator {
        var accelerator: Binding<String>
        var hint: Binding<String>

        init(accelerator: Binding<String>, hint: Binding<String>) {
            self.accelerator = accelerator
            self.hint = hint
        }

        func handle(_ event: NSEvent) {
            if let combo = HotkeyAcceleratorBuilder.build(from: event) {
                accelerator.wrappedValue = combo
                hint.wrappedValue = ""
            } else {
                hint.wrappedValue = "请至少按下一个非修饰键"
            }
        }
    }
}

private final class KeyCaptureNSView: NSView {
    weak var coordinator: HotkeyCaptureField.Coordinator?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        coordinator?.handle(event)
    }
}
