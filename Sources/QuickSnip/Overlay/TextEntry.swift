import AppKit

/// Typing a text annotation in place, in the field `field` shown on the overlay: one line for a
/// click (it grows from the click by the alignment), or a box of fixed width whose height grows
/// as the text wraps. Return places a line; in a box it starts a new line, and a click
/// elsewhere places it. Esc throws the text away.
@MainActor
final class TextEntry: NSObject, NSTextFieldDelegate {
    /// Horizontal padding NSTextField adds before its text (line fragment padding).
    static let fieldInset: CGFloat = 2
    /// Room for the caret past the last character of a line.
    static let caretRoom: CGFloat = 8
    static let minimumLineWidth: CGFloat = 40

    let field = NSTextField(string: "")
    let placement: TextPlacement
    private let style: AnnotationStyle
    private let onCommit: @MainActor (String) -> Void
    private let onCancel: @MainActor () -> Void
    private var isFinished = false

    init(
        placement: TextPlacement, style: AnnotationStyle, onCommit: @escaping @MainActor (String) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self.placement = placement
        self.style = style
        self.onCommit = onCommit
        self.onCancel = onCancel
        super.init()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = style.font.font(size: style.fontSize)
        field.textColor = style.color.nsColor
        field.alignment = style.alignment.nsAlignment
        field.delegate = self
        field.target = self
        field.action = #selector(fieldAction(_:))
        field.cell?.isScrollable = !isBox
        field.cell?.wraps = isBox
        field.setAccessibilityLabel(isBox ? "Annotation text box" : "Annotation text")
        layout()
    }

    var isBox: Bool { placement.boxWidth != nil }

    /// Fits the field to its text: a line grows sideways around its anchor; a box grows down.
    func layout() {
        let lineHeight = TextLayout.lineHeight(style) + 2
        if let boxWidth = placement.boxWidth {
            let width = boxWidth + Self.fieldInset * 2
            let height = max(lineHeight, ceil(boxTextHeight(width: width)))
            field.frame = CGRect(x: placement.origin.x - Self.fieldInset, y: placement.origin.y, width: width, height: height)
            return
        }
        let textWidth = field.attributedStringValue.size().width
        let width = max(Self.minimumLineWidth, (textWidth + Self.fieldInset * 2 + Self.caretRoom).rounded(.up))
        let x = placement.origin.x - Self.fieldInset - (width - Self.fieldInset * 2) * style.alignment.anchorFraction
        field.frame = CGRect(x: x, y: placement.origin.y, width: width, height: lineHeight)
    }

    /// While typing, the field editor's layout is the truth: it counts the empty line after a
    /// trailing Return, which the cell's own measurement leaves out (so the box stayed a line
    /// short and the editor scrolled the first line away).
    private func boxTextHeight(width: CGFloat) -> CGFloat {
        if let editor = field.currentEditor() as? NSTextView, let layout = editor.layoutManager, let container = editor.textContainer {
            layout.ensureLayout(for: container)
            return layout.usedRect(for: container).height + editor.textContainerInset.height * 2 + 2
        }
        return field.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)).height ?? 0
    }

    func commit() {
        guard !isFinished else { return }
        isFinished = true
        onCommit(field.stringValue)
    }

    func cancel() {
        guard !isFinished else { return }
        isFinished = true
        onCancel()
    }

    @objc private func fieldAction(_ sender: NSTextField) {
        commit()
    }

    func controlTextDidChange(_ notification: Notification) {
        layout()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        commit()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.cancelOperation(_:)):
            cancel()
            return true
        case #selector(NSResponder.insertNewline(_:)) where isBox:
            textView.insertNewlineIgnoringFieldEditor(nil)
            return true
        default:
            return false
        }
    }
}
