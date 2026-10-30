/// Splits a shortcut as macOS writes it ("⇧⌘2", "⌥Space") into one key cap per key.
enum ShortcutKeys {
    static let modifierSymbols: Set<Character> = ["⌃", "⌥", "⇧", "⌘", "🌐"]

    static func caps(for shortcut: String) -> [String] {
        let modifiers = shortcut.prefix { modifierSymbols.contains($0) }
        let key = shortcut.dropFirst(modifiers.count)
        return modifiers.map(String.init) + (key.isEmpty ? [] : [String(key)])
    }
}
