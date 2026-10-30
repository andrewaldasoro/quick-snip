import CoreGraphics

/// Handle positions and resize math for one annotation, in display-local points.
///
/// Rectangles and pixelate get all eight frame handles, lines and arrows one per end, and
/// freehand strokes the four corners of their points' bounding box (scaled as a whole), and
/// one-line text the four corners of its frame (scaling the font size, the opposite corner
/// staying put), and boxed text its left and right edges (the box's width; text rewraps).
@MainActor
enum AnnotationResizer {
    static let hitTolerance = SelectionEditor.hitTolerance

    static func handles(for annotation: Annotation) -> [(handle: AnnotationHandle, point: CGPoint)] {
        switch annotation.kind {
        case .rectangle(let rect), .pixelate(let rect):
            return SelectionHandle.allCases.map { (.frame($0), $0.point(in: rect)) }
        case .line(let from, let to), .arrow(let from, let to):
            return [(.start, from), (.end, to)]
        case .pen(let points), .marker(let points):
            return cornerHandles(of: Geometry.boundingRect(of: points))
        case .text(_, _, nil):
            return cornerHandles(of: annotation.bounds)
        case .text:
            let box = annotation.bounds
            return [SelectionHandle.left, .right].map { (.frame($0), $0.point(in: box)) }
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
        case (.text(let string, _, nil), .frame(let frame)) where frame.isCorner:
            return scaledText(original, string, frame, to: point)
        case (.text(let string, let origin, _?), .frame(let frame)) where frame == .left || frame == .right:
            return resizedBox(original, string, origin: origin, frame, to: point)
        default:
            return nil
        }
        return result
    }

    private static func cornerHandles(of box: CGRect) -> [(handle: AnnotationHandle, point: CGPoint)] {
        SelectionHandle.allCases.filter(\.isCorner).map { (.frame($0), $0.point(in: box)) }
    }

    /// Text scales by height: the font size follows the dragged corner, and the box is
    /// re-measured and pinned to the opposite corner.
    private static func scaledText(_ original: Annotation, _ string: String, _ handle: SelectionHandle, to point: CGPoint) -> Annotation? {
        let box = original.bounds
        let new = handle.resize(box, to: point)
        guard box.height > 0, new.height >= AnnotationBuilder.minimumSize else { return nil }
        var result = original
        result.style.fontSize = TextSize.clamp(original.style.fontSize * new.height / box.height)
        let size = Annotation.attributedText(string, style: result.style).size()
        let fixed = opposite(of: handle).point(in: box)
        let isLeft = handle == .topLeft || handle == .bottomLeft
        let isTop = handle == .topLeft || handle == .topRight
        let frame = CGRect(
            x: isLeft ? fixed.x - size.width : fixed.x, y: isTop ? fixed.y - size.height : fixed.y, width: size.width, height: size.height)
        result.kind = .text(string, origin: TextLayout.origin(forLineFrame: frame, alignment: original.style.alignment))
        return result
    }

    /// A text box gets wider or narrower from its left or right edge; its text rewraps.
    private static func resizedBox(
        _ original: Annotation, _ string: String, origin: CGPoint, _ handle: SelectionHandle, to point: CGPoint
    ) -> Annotation? {
        let new = handle.resize(original.bounds, to: point)
        guard new.width >= TextLayout.minimumBoxWidth else { return nil }
        var result = original
        result.kind = .text(string, origin: CGPoint(x: new.minX, y: origin.y), boxWidth: new.width)
        return result
    }

    private static func opposite(of corner: SelectionHandle) -> SelectionHandle {
        switch corner {
        case .topLeft: .bottomRight
        case .topRight: .bottomLeft
        case .bottomRight: .topLeft
        case .bottomLeft: .topRight
        case .top: .bottom
        case .bottom: .top
        case .left: .right
        case .right: .left
        }
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
