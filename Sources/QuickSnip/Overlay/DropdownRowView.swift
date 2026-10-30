import AppKit

/// A row in a dropdown list. The selection is a rounded rect, matching the dropdown's own
/// corners, in the solid accent fill of the toolbar's "on" buttons; the row's text and line
/// glyph switch to that fill's readable foreground (`ToolbarButton.accentForeground`).
final class DropdownRowView: NSTableRowView {
    static let cornerRadius: CGFloat = 6
    /// A hairline gap between rows, so neighboring highlights don't touch.
    static let verticalInset: CGFloat = 1

    override var isSelected: Bool {
        didSet { updateForeground() }
    }

    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        updateForeground()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        ToolbarButton.accentFill(isHighlighted: false, isHovered: false).setFill()
        let shape = bounds.insetBy(dx: 0, dy: Self.verticalInset)
        NSBezierPath(roundedRect: shape, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius).fill()
    }

    /// Text and template glyphs (the line-width previews) follow the selection; color swatches
    /// aren't templates and keep their color.
    private func updateForeground() {
        let color: NSColor = isSelected ? ToolbarButton.accentForeground : .labelColor
        for view in Self.descendants(of: self) {
            if let label = view as? NSTextField {
                label.textColor = color
            } else if let image = view as? NSImageView, image.image?.isTemplate == true {
                image.contentTintColor = color
            }
        }
    }

    private static func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants(of:))
    }
}
