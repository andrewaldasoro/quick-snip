import AppKit

/// A secondary action that still reads as a button (Save): the corner radius and height of the
/// primary Copy button, icon only and square like the glyphs, with a hairline border instead
/// of a fill, so Copy stays the one that stands out. A soft fill shows on hover and press.
final class OutlineToolbarButton: NSButton {
    static let cornerRadius: CGFloat = 7
    static let borderWidth: CGFloat = 1

    private let icon: NSImage
    private var isHovered = false { didSet { needsDisplay = true } }

    init(symbol: String, label: String) {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        icon = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?.withSymbolConfiguration(config) ?? NSImage()
        super.init(frame: .zero)
        title = ""
        image = icon
        imagePosition = .imageOnly
        imageScaling = .scaleNone
        isBordered = false
        setButtonType(.momentaryChange)
        contentTintColor = .labelColor
        if let cell = cell as? NSButtonCell {
            // Hover and press are drawn by `draw(_:)`.
            cell.highlightsBy = []
            cell.showsStateBy = []
        }
        toolTip = label
        setAccessibilityLabel(label)
        translatesAutoresizingMaskIntoConstraints = false
        setFrameSize(intrinsicContentSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets() }

    override var intrinsicContentSize: NSSize {
        AnnotationToolbar.buttonSize
    }

    override var isHighlighted: Bool {
        didSet { needsDisplay = true }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    /// The fill under the icon: none at rest, soft on hover, stronger while pressed.
    var fillAlpha: CGFloat {
        isHighlighted ? 0.14 : isHovered ? 0.08 : 0
    }

    override func draw(_ dirtyRect: NSRect) {
        let inset = Self.borderWidth / 2
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: Self.cornerRadius, yRadius: Self.cornerRadius)
        if fillAlpha > 0 {
            NSColor.labelColor.withAlphaComponent(fillAlpha).setFill()
            shape.fill()
        }
        NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
        shape.lineWidth = Self.borderWidth
        shape.stroke()

        // The button centers the symbol by its alignment rect, as it does for the glyph buttons;
        // centering the image's raw bounds sat it off-center.
        super.draw(dirtyRect)
    }
}
