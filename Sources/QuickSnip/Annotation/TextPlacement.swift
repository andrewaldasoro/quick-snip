import CoreGraphics

/// Where new text goes: a click's point (one line), or a box dragged out with the text tool.
struct TextPlacement: Equatable, Sendable {
    let origin: CGPoint
    /// Nil for a click.
    let boxWidth: CGFloat?

    /// One line of text starting at `point` (anchored there by its alignment).
    static func line(at point: CGPoint) -> TextPlacement {
        TextPlacement(origin: point, boxWidth: nil)
    }

    /// A drag of at least `TextLayout.minimumBoxWidth` makes a box from its left edge;
    /// anything shorter is a click at `start`.
    static func from(drag start: CGPoint, to end: CGPoint, minimumBoxWidth: CGFloat) -> TextPlacement {
        let box = Geometry.rect(from: start, to: end)
        guard box.width >= minimumBoxWidth else { return .line(at: start) }
        return TextPlacement(origin: box.origin, boxWidth: box.width)
    }
}
