import AppKit

/// The text view text is typed into on the overlay. Return always starts a new line, as in
/// Markup, Figma and Keynote; Esc, ⌘Return or clicking elsewhere finishes (keeping the text).
final class TextEditorView: NSTextView {
    /// Called once typing should end; the owner decides what happens to the text.
    var onFinish: (@MainActor () -> Void)?
    /// Called after every edit, so the owner can fit the view to the text.
    var onChange: (@MainActor () -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onFinish?()
    }

    /// ⌘Return finishes; plain Return falls through to a new line.
    override func keyDown(with event: NSEvent) {
        if Self.isFinishKey(keyCode: event.keyCode, modifiers: event.modifierFlags) {
            onFinish?()
            return
        }
        super.keyDown(with: event)
    }

    /// ⌘Return or ⌘Enter, whatever else is held.
    static func isFinishKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        let returnKeys: Set<UInt16> = [36, 76]  // Return, keypad Enter
        return returnKeys.contains(keyCode) && modifiers.contains(.command)
    }

    override func didChangeText() {
        super.didChangeText()
        onChange?()
    }

    /// Losing focus (a click on the toolbar, a dropdown's search field) finishes too. The owner
    /// removes this view, which can't happen while AppKit is still moving focus away from it.
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            DispatchQueue.main.async { [weak self] in self?.onFinish?() }
        }
        return resigned
    }
}
