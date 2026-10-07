import AppKit

/// Overlay keyboard commands: Esc cancels, Return/Enter or ⌘C copies, ⌘S saves,
/// ⌘Z / ⌘⇧Z undo/redo, Delete removes the selected annotation.
enum OverlayKeyMap {
    static let escape: UInt16 = 53
    static let returnKey: UInt16 = 36
    static let enterKey: UInt16 = 76
    static let deleteKey: UInt16 = 51
    static let forwardDeleteKey: UInt16 = 117

    static func command(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        charactersIgnoringModifiers: String?
    ) -> OverlayCommand? {
        let modifiers = modifiers
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])

        if modifiers.isEmpty {
            switch keyCode {
            case escape: return .cancel
            case returnKey, enterKey: return .copy
            case deleteKey, forwardDeleteKey: return .deleteAnnotation
            default: return nil
            }
        }

        if modifiers == .command {
            switch charactersIgnoringModifiers?.lowercased() {
            case "c": return .copy
            case "s": return .save
            case "z": return .undo
            default: return nil
            }
        }

        if modifiers == [.command, .shift], charactersIgnoringModifiers?.lowercased() == "z" {
            return .redo
        }

        return nil
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
