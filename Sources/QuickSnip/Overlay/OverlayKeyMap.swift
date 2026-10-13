import AppKit

/// Every overlay key binding. Key handling, toolbar tooltips and the shortcut cheatsheet
/// all read `bindings`, so they can't drift apart.
enum OverlayKeyMap {
    static let escape: UInt16 = 53
    static let returnKey: UInt16 = 36
    static let enterKey: UInt16 = 76
    static let deleteKey: UInt16 = 51
    static let forwardDeleteKey: UInt16 = 117

    /// Earlier entries are shown first (the first one in tooltips).
    static let editingBindings: [KeyBinding] = [
        KeyBinding(.character("c"), .command, .copy),
        KeyBinding(.code(returnKey, name: "Return"), .copy),
        KeyBinding(.code(enterKey, name: "Enter"), .copy),
        KeyBinding(.character("s"), .command, .save),
        KeyBinding(.code(escape, name: "Esc"), .cancel),
        KeyBinding(.character("z"), .command, .undo),
        KeyBinding(.character("z"), [.command, .shift], .redo),
        KeyBinding(.code(deleteKey, name: "Delete"), .deleteAnnotation),
        KeyBinding(.code(forwardDeleteKey, name: "⌦"), .deleteAnnotation),
        KeyBinding(.symbol("?"), .toggleCheatsheet),
    ]

    /// In toolbar order.
    static let toolBindings: [KeyBinding] = [
        (AnnotationTool.rectangle, "r"), (.arrow, "a"), (.line, "l"), (.pen, "p"), (.marker, "m"), (.text, "t"), (.pixelate, "x"),
    ].map { tool, key in KeyBinding(.character(key), .selectTool(tool)) }

    /// 1–8, in toolbar order.
    static let colorBindings: [KeyBinding] = AnnotationColor.allCases.enumerated().map { index, color in
        KeyBinding(.character(String(index + 1)), .selectColor(color))
    }

    static let bindings = editingBindings + toolBindings + colorBindings

    /// Every key for a command as shown to the user, e.g. ["⌘C", "Return", "Enter"].
    static func keys(for command: OverlayCommand) -> [String] {
        bindings.filter { $0.command == command }.map(\.displayText)
    }

    static func command(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        charactersIgnoringModifiers: String?
    ) -> OverlayCommand? {
        let modifiers =
            modifiers
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        return bindings.first { $0.matches(keyCode: keyCode, modifiers: modifiers, characters: charactersIgnoringModifiers) }?.command
    }

    static func command(for event: NSEvent) -> OverlayCommand? {
        guard event.type == .keyDown else { return nil }
        return command(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers
        )
    }
}
