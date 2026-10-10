import AppKit

/// Overlay keyboard commands: Esc cancels, Return/Enter or ⌘C copies, ⌘S saves,
/// ⌘Z / ⌘⇧Z undo/redo, Delete removes the selected annotation, letters pick tools
/// (R A L P M T X), digits 1–8 pick colors.
enum OverlayKeyMap {
    static let toolKeys: [String: AnnotationTool] = [
        "r": .rectangle, "a": .arrow, "l": .line, "p": .pen, "m": .marker, "t": .text, "x": .pixelate,
    ]

    static func toolKey(for tool: AnnotationTool) -> String {
        toolKeys.first { $0.value == tool }!.key
    }

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
        let modifiers =
            modifiers
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])

        if modifiers.isEmpty {
            switch keyCode {
            case escape: return .cancel
            case returnKey, enterKey: return .copy
            case deleteKey, forwardDeleteKey: return .deleteAnnotation
            default: break
            }
            let key = charactersIgnoringModifiers?.lowercased() ?? ""
            if let tool = toolKeys[key] { return .selectTool(tool) }
            if let digit = Int(key), (1...AnnotationColor.allCases.count).contains(digit) {
                return .selectColor(AnnotationColor.allCases[digit - 1])
            }
            return nil
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
