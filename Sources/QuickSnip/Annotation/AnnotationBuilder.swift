import CoreGraphics
import Foundation

/// Turns one mouse drag with a drawing tool into an annotation. `annotation` is the live
/// preview; `finish()` drops degenerate results (tiny shapes from a stray click).
///
/// Everything stays inside `bounds` (the selection). `modifiers` can change mid-drag (Shift
/// pressed or released), so the last raw point is kept and the shape re-derived from it.
struct AnnotationBuilder {
    static let minimumSize: CGFloat = 3

    let tool: AnnotationTool
    let style: AnnotationStyle
    let start: CGPoint
    let bounds: CGRect?
    var modifiers = DrawModifiers.none
    private let id = UUID()
    private(set) var points: [CGPoint]

    init(tool: AnnotationTool, style: AnnotationStyle, start: CGPoint, bounds: CGRect? = nil) {
        self.tool = tool
        self.style = style
        self.start = start
        self.bounds = bounds
        points = [start]
    }

    mutating func add(_ point: CGPoint) {
        switch tool {
        case .pen, .marker:
            let clamped = bounds.map { Geometry.clamp(point, to: $0) } ?? point
            if clamped != points.last { points.append(clamped) }
        case .shape, .arrow, .pixelate, .text:
            points = [start, point]
        }
    }

    private var end: CGPoint { points.last ?? start }

    var annotation: Annotation? {
        let kind: AnnotationKind
        switch tool {
        case .shape: kind = .shape(Geometry.shapeRect(from: start, to: end, modifiers: modifiers, within: bounds))
        case .pixelate: kind = .pixelate(Geometry.shapeRect(from: start, to: end, modifiers: .none, within: bounds))
        case .arrow: kind = .arrow(from: start, to: arrowEnd)
        case .pen: kind = .pen(points)
        case .marker: kind = .marker(points)
        case .text: return nil
        }
        return Annotation(id: id, kind: kind, style: style)
    }

    /// Shift snaps to 45°; the snapped end is pulled back along the line to stay inside.
    private var arrowEnd: CGPoint {
        guard modifiers.isConstrained else { return bounds.map { Geometry.clamp(end, to: $0) } ?? end }
        let snapped = Geometry.snapped(end, from: start)
        return bounds.map { Geometry.clamp(snapped, from: start, to: $0) } ?? snapped
    }

    func finish() -> Annotation? {
        guard let annotation else { return nil }
        switch annotation.kind {
        case .shape(let rect), .pixelate(let rect):
            return rect.width >= Self.minimumSize && rect.height >= Self.minimumSize ? annotation : nil
        case .arrow(let from, let to):
            return Geometry.distance(from, to) >= Self.minimumSize ? annotation : nil
        case .pen, .marker, .text:
            return annotation
        }
    }
}
