import CoreGraphics

/// Handle positions and resize math for one annotation, in display-local points.
///
/// Rectangles and pixelate get all eight frame handles, lines and arrows one per end, and
/// freehand strokes the four corners of their points' bounding box (scaled as a whole).
enum AnnotationResizer {
    static let hitTolerance = SelectionEditor.hitTolerance

    static func handles(for annotation: Annotation) -> [(handle: AnnotationHandle, point: CGPoint)] {
        switch annotation.kind {
        case .rectangle(let rect), .pixelate(let rect):
            return SelectionHandle.allCases.map { (.frame($0), $0.point(in: rect)) }
        case .line(let from, let to), .arrow(let from, let to):
            return [(.start, from), (.end, to)]
        case .pen(let points), .marker(let points):
            let box = Geometry.boundingRect(of: points)
            return SelectionHandle.allCases.filter(\.isCorner).map { (.frame($0), $0.point(in: box)) }
        case .text:
            return []
        }
    }

    /// The handle under `point`; corners and ends win over edges when they overlap.
    static func hitTest(_ point: CGPoint, on annotation: Annotation) -> AnnotationHandle? {
        let candidates = handles(for: annotation).filter {
            abs(point.x - $0.point.x) <= hitTolerance && abs(point.y - $0.point.y) <= hitTolerance
        }
        let preferred = candidates.first { candidate in
            if case .frame(let handle) = candidate.handle { return handle.isCorner }
            return true
        }
        return (preferred ?? candidates.first)?.handle
    }

    /// `original` with `handle` dragged to `point`, or nil when that would collapse it below
    /// `AnnotationBuilder.minimumSize` (the caller keeps the last valid shape).
    static func resized(_ original: Annotation, dragging handle: AnnotationHandle, to point: CGPoint) -> Annotation? {
        var result = original
        switch (original.kind, handle) {
        case (.rectangle(let rect), .frame(let frame)):
            guard let new = resizedRect(rect, frame, to: point) else { return nil }
            result.kind = .rectangle(new)
        case (.pixelate(let rect), .frame(let frame)):
            guard let new = resizedRect(rect, frame, to: point) else { return nil }
            result.kind = .pixelate(new)
        case (.line(let from, let to), _), (.arrow(let from, let to), _):
            guard let (newFrom, newTo) = movedEnd(from: from, to: to, handle, to: point) else { return nil }
            result.kind = isArrow(original) ? .arrow(from: newFrom, to: newTo) : .line(from: newFrom, to: newTo)
        case (.pen(let points), .frame(let frame)):
            guard let new = scaled(points, frame, to: point) else { return nil }
            result.kind = .pen(new)
        case (.marker(let points), .frame(let frame)):
            guard let new = scaled(points, frame, to: point) else { return nil }
            result.kind = .marker(new)
        default:
            return nil
        }
        return result
    }

    private static func resizedRect(_ rect: CGRect, _ handle: SelectionHandle, to point: CGPoint) -> CGRect? {
        let new = handle.resize(rect, to: point)
        let minimum = AnnotationBuilder.minimumSize
        return new.width >= minimum && new.height >= minimum ? new : nil
    }

    private static func movedEnd(
        from: CGPoint, to: CGPoint, _ handle: AnnotationHandle, to point: CGPoint
    ) -> (CGPoint, CGPoint)? {
        let ends: (CGPoint, CGPoint)
        switch handle {
        case .start: ends = (point, to)
        case .end: ends = (from, point)
        case .frame: return nil
        }
        return Geometry.distance(ends.0, ends.1) >= AnnotationBuilder.minimumSize ? ends : nil
    }

    /// Maps every point from the old bounding box into the resized one. A flat axis (a
    /// straight stroke) can't be scaled, so it stays as drawn.
    private static func scaled(_ points: [CGPoint], _ handle: SelectionHandle, to point: CGPoint) -> [CGPoint]? {
        let box = Geometry.boundingRect(of: points)
        let new = handle.resize(box, to: point)
        let minimum = AnnotationBuilder.minimumSize
        let scalesX = box.width >= minimum
        let scalesY = box.height >= minimum
        guard scalesX || scalesY, !scalesX || new.width >= minimum, !scalesY || new.height >= minimum else { return nil }
        return points.map { p in
            CGPoint(
                x: scalesX ? new.minX + (p.x - box.minX) * new.width / box.width : p.x,
                y: scalesY ? new.minY + (p.y - box.minY) * new.height / box.height : p.y
            )
        }
    }

    private static func isArrow(_ annotation: Annotation) -> Bool {
        if case .arrow = annotation.kind { return true }
        return false
    }
}
