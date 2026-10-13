import KeyboardShortcuts
import Observation

/// The capture hotkey as shown to the user ("⇧⌘2"), shared by every view that lists it.
@MainActor
@Observable
final class CaptureHotkey {
    private(set) var displayText: String?
    @ObservationIgnored private let read: @MainActor () -> String?

    init(read: @escaping @MainActor () -> String? = { KeyboardShortcuts.getShortcut(for: .captureArea)?.description }) {
        self.read = read
        displayText = read()
    }

    /// Call after the shortcut is recorded or cleared.
    func refresh() {
        displayText = read()
    }

    var cheatsheet: ShortcutCheatsheet {
        ShortcutCheatsheet(captureShortcut: displayText)
    }
}
