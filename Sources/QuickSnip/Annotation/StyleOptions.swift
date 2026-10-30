import CoreGraphics

/// What the style panel offers for the current tool or selected annotation.
enum StyleOptions: Equatable, Sendable {
    /// Shapes, lines and strokes: their line width.
    case stroke(lineWidth: CGFloat)
    /// Text: its font, size and alignment.
    case text(font: TextFont, size: CGFloat, alignment: TextAlignment)
}
