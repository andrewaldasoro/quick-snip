import AppKit

/// A pop-up-style button for the overlay: the current value and a chevron on a soft rounded
/// fill, the same height as the toolbar glyphs. Its list is a `DropdownListPanel` inside the
/// overlay; a real pop-up menu would open below the overlay's window level.
final class DropdownButton: NSButton {
    static let horizontalPadding: CGFloat = 9
    static let chevronSpacing: CGFloat = 6
    static let cornerRadius: CGFloat = 7
    static let titleFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)

    private let chevron: NSImage
    private var isHovered = false { didSet { needsDisplay = true } }
    /// Its list is showing.
    var isOpen = false { didSet { needsDisplay = true } }
    /// Draws the title in this font (the font menu shows the current font in itself).
    var titleFontOverride: NSFont? {
        didSet { invalidateIntrinsicContentSize() }
    }

    init(title: String, label: String) {
        let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        chevron = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?.withSymbolConfiguration(config) ?? NSImage()
        super.init(frame: .zero)
        self.title = title
        isBordered = false
        setButtonType(.momentaryChange)
        toolTip = label
        setAccessibilityRole(.popUpButton)
        setAccessibilityLabel(label)
        translatesAutoresizingMaskIntoConstraints = false
        setFrameSize(intrinsicContentSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var title: String {
        didSet {
            invalidateIntrinsicContentSize()
            setAccessibilityValue(title)
        }
    }

    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets() }

    private var drawnFont: NSFont { titleFontOverride ?? Self.titleFont }

    private var titleSize: NSSize {
        (title as NSString).size(withAttributes: [.font: drawnFont])
    }

    override var intrinsicContentSize: NSSize {
        let width = ceil(titleSize.width) + Self.chevronSpacing + chevron.size.width + Self.horizontalPadding * 2
        return NSSize(width: ceil(width), height: AnnotationToolbar.buttonSize.height)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func draw(_ dirtyRect: NSRect) {
        let alpha: CGFloat = isOpen || isHighlighted ? 0.18 : isHovered ? 0.13 : 0.08
        NSColor.labelColor.withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius).fill()

        let size = titleSize
        let text = NSAttributedString(string: title, attributes: [.font: drawnFont, .foregroundColor: NSColor.labelColor])
        text.draw(at: NSPoint(x: Self.horizontalPadding, y: (bounds.height - size.height) / 2))

        let chevronRect = NSRect(
            x: bounds.maxX - Self.horizontalPadding - chevron.size.width,
            y: (bounds.height - chevron.size.height) / 2,
            width: chevron.size.width,
            height: chevron.size.height
        )
        Self.tinted(chevron, .secondaryLabelColor).draw(in: chevronRect)
    }

    private static func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
