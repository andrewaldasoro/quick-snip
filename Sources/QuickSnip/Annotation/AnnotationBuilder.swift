import CoreGraphics
import Foundation

/// Turns one mouse drag with a drawing tool into an annotation. `annotation` is the live
/// preview; `finish()` drops degenerate results (tiny shapes from a stray click).
struct AnnotationBuilder {
    static let minimumSize: CGFloat = 3

    let tool: AnnotationTool
    let style: AnnotationStyle
    let start: CGPoint
    private let id = UUID()
    private(set) var points: [CGPoint]

    init(tool: AnnotationTool, style: AnnotationStyle, start: CGPoint) {
        self.tool = tool
        self.style = style
        self.start = start
        points = [start]
    }

    mutating func add(_ point: CGPoint) {
        switch tool {
        case .pen, .marker:
            if point != points.last { points.append(point) }
        case .rectangle, .arrow, .line, .pixelate, .text:
            points = [start, point]
        }
    }

    var annotation: Annotation? {
        let end = points.last ?? start
        let kind: AnnotationKind
        switch tool {
        case .rectangle: kind = .rectangle(Geometry.rect(from: start, to: end))
        case .pixelate: kind = .pixelate(Geometry.rect(from: start, to: end))
        case .line: kind = .line(from: start, to: end)
        case .arrow: kind = .arrow(from: start, to: end)
        case .pen: kind = .pen(points)
        case .marker: kind = .marker(points)
        case .text: return nil
        }
        return Annotation(id: id, kind: kind, style: style)
    }

    func finish() -> Annotation? {
        guard let annotation else { return nil }
        let end = points.last ?? start
        switch annotation.kind {
        case .rectangle(let rect), .pixelate(let rect):
            return rect.width >= Self.minimumSize && rect.height >= Self.minimumSize ? annotation : nil
        case .line, .arrow:
            return Geometry.distance(start, end) >= Self.minimumSize ? annotation : nil
        case .pen, .marker, .text:
            return annotation
        }
    }
}
