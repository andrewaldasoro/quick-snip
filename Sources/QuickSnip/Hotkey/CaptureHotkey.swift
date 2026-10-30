import KeyboardShortcuts
import Observation

/// The capture hotkey as shown to the user ("⇧⌘2"), shared by every view that lists it.
@MainActor
@Observable
final class CaptureHotkey {
    private(set) var displayText: String?
    @ObservationIgnored private let read: @MainActor () -> String?
    @ObservationIgnored private let restoreDefault: @MainActor () -> Void
    @ObservationIgnored private let defaultText: String?

    init(
        read: @escaping @MainActor () -> String? = { KeyboardShortcuts.getShortcut(for: .captureArea)?.description },
        restoreDefault: @escaping @MainActor () -> Void = { KeyboardShortcuts.reset(.captureArea) },
        defaultText: String? = KeyboardShortcuts.Name.captureArea.initialShortcut?.description
    ) {
        self.read = read
        self.restoreDefault = restoreDefault
        self.defaultText = defaultText
        displayText = read()
    }

    /// Call after the shortcut is recorded or cleared.
    func refresh() {
        displayText = read()
    }

    /// The shortcut was changed or cleared, so there's a default to go back to.
    var canReset: Bool {
        displayText != defaultText
    }

    func reset() {
        restoreDefault()
        refresh()
    }

    var cheatsheet: ShortcutCheatsheet {
        ShortcutCheatsheet(captureShortcut: displayText)
    }
}
