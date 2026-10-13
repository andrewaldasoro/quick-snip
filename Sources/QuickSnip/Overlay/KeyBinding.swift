import AppKit

/// One key that runs an overlay command, and how that key is shown to the user.
struct KeyBinding: Sendable {
    enum Key: Equatable, Sendable {
        /// A physical key matched by key code (Esc, Return), shown by name.
        case code(UInt16, name: String)
        /// A letter or digit, matched case-insensitively.
        case character(String)
        /// A punctuation character. Shift is ignored: whether it's needed depends on the keyboard layout (`?`).
        case symbol(String)
    }

    /// Modifier symbols in the order macOS menus show them.
    private static let modifierSymbols: [(flag: NSEvent.ModifierFlags, symbol: String)] = [
        (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
    ]

    let key: Key
    let modifiers: NSEvent.ModifierFlags
    let command: OverlayCommand

    init(_ key: Key, _ modifiers: NSEvent.ModifierFlags, _ command: OverlayCommand) {
        self.key = key
        self.modifiers = modifiers
        self.command = command
    }

    init(_ key: Key, _ command: OverlayCommand) {
        self.init(key, [], command)
    }

    /// `modifiers` must already be reduced to ⌃⌥⇧⌘.
    func matches(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String?) -> Bool {
        switch key {
        case .code(let code, _): keyCode == code && modifiers == self.modifiers
        case .character(let character): characters?.lowercased() == character && modifiers == self.modifiers
        case .symbol(let symbol): characters == symbol && modifiers.subtracting(.shift) == self.modifiers
        }
    }

    /// As menus show it: modifiers in ⌃⌥⇧⌘ order, then the key ("⇧⌘Z").
    var displayText: String {
        let modifierText = Self.modifierSymbols.filter { modifiers.contains($0.flag) }.map(\.symbol).joined()
        switch key {
        case .code(_, let name): return modifierText + name
        case .character(let character): return modifierText + character.uppercased()
        case .symbol(let symbol): return modifierText + symbol
        }
    }
}
