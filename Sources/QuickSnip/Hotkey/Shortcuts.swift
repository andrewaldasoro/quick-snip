import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// ⌘⇧2 — avoids the system ⌘⇧3/4/5/6 screenshot shortcuts.
    static let captureArea = Self("captureArea", default: .init(.two, modifiers: [.command, .shift]))
}
