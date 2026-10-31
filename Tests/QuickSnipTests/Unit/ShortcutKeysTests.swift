import Testing

@testable import QuickSnip

struct ShortcutKeysTests {
    @Test(arguments: [
        ("⇧⌘2", ["⇧", "⌘", "2"]),
        ("⌥Space", ["⌥", "Space"]),
        ("⌃⌥⇧⌘F5", ["⌃", "⌥", "⇧", "⌘", "F5"]),
        ("Esc", ["Esc"]),
        ("⌘", ["⌘"]),
        ("", []),
    ])
    func splitsModifiersFromTheKey(shortcut: String, caps: [String]) {
        #expect(ShortcutKeys.caps(for: shortcut) == caps)
    }
}
