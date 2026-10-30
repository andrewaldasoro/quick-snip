import AppKit
import KeyboardShortcuts
import SwiftUI

/// KeyboardShortcuts' recorder, focused as soon as it appears so the next key press is
/// recorded, and reporting when recording ends (a shortcut, Esc, or a click elsewhere).
struct ShortcutRecorderField: NSViewRepresentable {
    let name: KeyboardShortcuts.Name
    let onEnd: @MainActor () -> Void

    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        let recorder = KeyboardShortcuts.RecorderCocoa(for: name)
        context.coordinator.observe(recorder, onEnd: onEnd)
        // Not in a window yet; focus once SwiftUI has attached it.
        DispatchQueue.main.async { recorder.window?.makeFirstResponder(recorder) }
        return recorder
    }

    func updateNSView(_ recorder: KeyboardShortcuts.RecorderCocoa, context: Context) {}

    static func dismantleNSView(_ recorder: KeyboardShortcuts.RecorderCocoa, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        private var observer: NSObjectProtocol?

        /// The recorder gives up focus however recording ends, which ends its text editing.
        func observe(_ recorder: NSTextField, onEnd: @escaping @MainActor () -> Void) {
            observer = NotificationCenter.default.addObserver(
                forName: NSControl.textDidEndEditingNotification, object: recorder, queue: .main
            ) { _ in
                MainActor.assumeIsolated { onEnd() }
            }
        }

        func stopObserving() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
        }
    }
}
