import AppKit

/// Typing a text annotation in place, in `editor` on the overlay: new text, or existing text
/// reopened with a double-click. Click text grows sideways from its anchor (start, middle or end
/// by alignment) and only breaks lines at Return; box text wraps to the box's width. Both grow
/// down a line at a time, so the lines above never move. The text is measured the way
/// `TextLayout` draws it, so nothing jumps when typing ends.
@MainActor
final class TextEntry {
    /// Room for the caret past the end of the longest line.
    static let caretRoom: CGFloat = 2

    let editor = TextEditorView(frame: .zero)
    let request: TextEditRequest
    /// Start from the request; the style panel can change them while typing.
    private(set) var style: AnnotationStyle
    private(set) var placement: TextPlacement
    private let onFinish: @MainActor (String) -> Void
    private var isFinished = false

    init(request: TextEditRequest, onFinish: @escaping @MainActor (String) -> Void) {
        self.request = request
        style = request.style
        placement = request.placement
        self.onFinish = onFinish
        configure()
        editor.string = request.text
        editor.onChange = { [weak self] in self?.layout() }
        editor.onFinish = { [weak self] in self?.finish() }
        layout()
    }

    var isBox: Bool { placement.boxWidth != nil }
    var text: String { editor.string }

    /// Follows the style panel while typing: the font, color and alignment change in place.
    func update(style: AnnotationStyle, placement: TextPlacement) {
        guard style != self.style || placement != self.placement else { return }
        self.style = style
        self.placement = placement
        applyStyle()
        layout()
    }

    private func configure() {
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        applyStyle()
        editor.textContainerInset = .zero
        editor.isVerticallyResizable = false
        editor.isHorizontallyResizable = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        // Text starts exactly at the placement, like the drawn annotation (no line padding).
        editor.textContainer?.lineFragmentPadding = 0
        editor.textContainer?.widthTracksTextView = true
        editor.setAccessibilityLabel(isBox ? "Annotation text box" : "Annotation text")
    }

    private func applyStyle() {
        editor.font = style.font.font(size: style.fontSize)
        editor.textColor = style.color.nsColor
        editor.insertionPointColor = style.color.nsColor
        editor.alignment = style.alignment.nsAlignment
        // New text typed from here on takes the style too, not only what's already there.
        editor.typingAttributes = TextLayout.attributed(" ", style: style).attributes(at: 0, effectiveRange: nil)
    }

    /// Fits the editor to its text.
    func layout() {
        let lineHeight = TextLayout.lineHeight(style)
        if let boxWidth = placement.boxWidth {
            // Width first: the text wraps to it, and the height comes from that wrapping.
            editor.frame = CGRect(x: placement.origin.x, y: placement.origin.y, width: boxWidth, height: lineHeight)
            editor.setFrameSize(NSSize(width: boxWidth, height: max(lineHeight, boxHeight())))
            return
        }
        let size = TextLayout.attributed(text, style: style).size()
        // A trailing Return opens an empty line that the string's size doesn't count yet.
        let height = max(lineHeight, ceil(size.height) + (text.hasSuffix("\n") ? lineHeight : 0))
        let width = ceil(size.width) + Self.caretRoom
        let anchor = style.alignment.anchorFraction
        editor.frame = CGRect(x: placement.origin.x - width * anchor, y: placement.origin.y, width: width, height: height)
    }

    /// The box's text as laid out, including the empty line after a trailing Return.
    private func boxHeight() -> CGFloat {
        guard let layout = editor.layoutManager, let container = editor.textContainer else { return 0 }
        layout.ensureLayout(for: container)
        return ceil(layout.usedRect(for: container).height)
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        onFinish(text)
    }
}
