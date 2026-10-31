import KeyboardShortcuts
import SwiftUI

/// The capture shortcut as key caps, like macOS menus. Click to record a new one; the
/// reset arrow puts back the default.
struct ShortcutField: View {
    let hotkey: CaptureHotkey
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            if hotkey.canReset {
                Button {
                    hotkey.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Restore the default shortcut")
                .accessibilityLabel("Restore the default shortcut")
            }
            if isRecording {
                ShortcutRecorderField(name: .captureArea) {
                    isRecording = false
                    hotkey.refresh()
                }
                .frame(width: 130)
            } else {
                Button {
                    isRecording = true
                } label: {
                    if let text = hotkey.displayText {
                        KeyCapsView(keys: ShortcutKeys.caps(for: text), isCombination: true)
                    } else {
                        Text("Record shortcut").foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Click to record a new shortcut")
                .accessibilityLabel("Capture shortcut: \(hotkey.displayText ?? "none"). Click to change")
            }
        }
    }
}
