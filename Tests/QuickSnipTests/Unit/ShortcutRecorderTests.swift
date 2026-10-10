import AppKit
import KeyboardShortcuts
import Testing

@testable import QuickSnip

/// The Settings shortcut recorder took several tries: on macOS 26+ AppKit ends and restarts
/// editing on the click that focuses the field, and KeyboardShortcuts before 3.1 treated
/// that as the end of recording, so the next key press was ignored.
@MainActor
struct ShortcutRecorderTests {
    /// KeyboardShortcuts keeps this notification internal; the name is its stable string.
    private static let activeStatusDidChange = Notification.Name("KeyboardShortcuts_recorderActiveStatusDidChange")

    @Test func recorderKeepsRecordingWhenAppKitRestartsEditing() async throws {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 80), styleMask: [.titled], backing: .buffered, defer: false)
        let recorder = KeyboardShortcuts.RecorderCocoa(for: .captureArea)
        window.contentView?.addSubview(recorder)
        var activeStates: [Bool] = []
        let observer = NotificationCenter.default.addObserver(forName: Self.activeStatusDidChange, object: nil, queue: nil) { note in
            if let isActive = note.userInfo?["isActive"] as? Bool { MainActor.assumeIsolated { activeStates.append(isActive) } }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        // Click: recording starts, then AppKit's internal restart posts end-editing while the field editor stays installed.
        window.makeFirstResponder(recorder)
        recorder.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: recorder))
        await Task.yield()
        await Task.yield()

        #expect(activeStates == [true])
        window.makeFirstResponder(nil)
    }
}
