import CoreGraphics

/// What the style panel offers for the current tool or selected annotation.
enum StyleOptions: Equatable, Sendable {
    /// Freehand strokes: their line width.
    case stroke(lineWidth: CGFloat)
    /// Shapes: line width and rectangle or oval.
    case shape(ShapeKind, lineWidth: CGFloat)
    /// Arrows: line width and which ends have heads.
    case arrow(ArrowHeads, lineWidth: CGFloat)
    /// Text: its font, size and alignment.
    case text(font: TextFont, size: CGFloat, alignment: TextAlignment)

    /// The options for what `tool` draws (or an annotation it drew) in `style`. Nil for
    /// pixelate, which has no style.
    static func make(for tool: AnnotationTool, style: AnnotationStyle) -> StyleOptions? {
        switch tool {
        case .pixelate: nil
        case .text: .text(font: style.font, size: style.fontSize, alignment: style.alignment)
        case .shape: .shape(style.shape, lineWidth: style.lineWidth)
        case .arrow: .arrow(style.arrowHeads, lineWidth: style.lineWidth)
        case .pen, .marker: .stroke(lineWidth: style.lineWidth)
        }
    }

    /// The line width, for everything drawn with a line.
    var lineWidth: CGFloat? {
        switch self {
        case .stroke(let width), .shape(_, let width), .arrow(_, let width): width
        case .text: nil
        }
    }
}
