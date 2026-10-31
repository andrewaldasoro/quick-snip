import CoreGraphics

enum Geometry {
    static func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    static func boundingRect(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { rect, p in
            rect.union(CGRect(origin: p, size: .zero))
        }
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }

    static func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return distance(p, a) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        return distance(p, CGPoint(x: a.x + t * dx, y: a.y + t * dy))
    }

    static func distance(from p: CGPoint, toPolyline points: [CGPoint]) -> CGFloat {
        guard let first = points.first else { return .infinity }
        guard points.count > 1 else { return distance(p, first) }
        return zip(points, points.dropFirst()).map { distance(from: p, toSegment: $0, $1) }.min() ?? .infinity
    }

    static func clamp(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX), y: min(max(point.y, bounds.minY), bounds.maxY))
    }

    // MARK: Constrained drags

    /// The rect dragged from `start` to `end`. Constrained, it's a square as big as the longer
    /// axis of the drag; from center, `start` is its middle. It's shrunk to fit `bounds` (the
    /// selection) keeping both, since clamping the end point alone would bend the square.
    static func shapeRect(from start: CGPoint, to end: CGPoint, modifiers: DrawModifiers, within bounds: CGRect?) -> CGRect {
        var delta = CGSize(width: end.x - start.x, height: end.y - start.y)
        if modifiers.isConstrained {
            delta = proportionalDelta(delta, aspect: CGSize(width: 1, height: 1))
        }
        if let bounds {
            delta = fitted(delta, from: start, within: bounds, fromCenter: modifiers.isFromCenter, keepsAspect: modifiers.isConstrained)
        }
        let far = CGPoint(x: start.x + delta.width, y: start.y + delta.height)
        guard modifiers.isFromCenter else { return rect(from: start, to: far) }
        return rect(from: CGPoint(x: start.x - delta.width, y: start.y - delta.height), to: far)
    }

    /// The rect from `anchor` toward `point` with `aspect`'s proportions, scaled to the longer
    /// axis of the drag (a Shift corner drag in Figma and Preview). It flips past the anchor.
    static func proportionalRect(from anchor: CGPoint, to point: CGPoint, aspect: CGSize) -> CGRect {
        let delta = proportionalDelta(CGSize(width: point.x - anchor.x, height: point.y - anchor.y), aspect: aspect)
        return rect(from: anchor, to: CGPoint(x: anchor.x + delta.width, y: anchor.y + delta.height))
    }

    /// Every 45° from +x, in `atan2` order (y grows downward), as whole steps so axis-aligned
    /// results stay exact.
    private static let snapDirections = [
        CGVector(dx: 1, dy: 0), CGVector(dx: 1, dy: 1), CGVector(dx: 0, dy: 1), CGVector(dx: -1, dy: 1),
        CGVector(dx: -1, dy: 0), CGVector(dx: -1, dy: -1), CGVector(dx: 0, dy: -1), CGVector(dx: 1, dy: -1),
    ]

    /// `end` moved onto the nearest 45° direction from `start` (its projection on it).
    static func snapped(_ end: CGPoint, from start: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let octant = Int((atan2(dy, dx) / (.pi / 4)).rounded())
        let direction = snapDirections[(octant + snapDirections.count) % snapDirections.count]
        let length = (dx * direction.dx + dy * direction.dy) / (direction.dx * direction.dx + direction.dy * direction.dy)
        return CGPoint(x: start.x + direction.dx * length, y: start.y + direction.dy * length)
    }

    /// `end` pulled back toward `start` along the same direction until it's inside `bounds`,
    /// so a snapped line keeps its angle.
    static func clamp(_ end: CGPoint, from start: CGPoint, to bounds: CGRect) -> CGPoint {
        let delta = CGSize(width: end.x - start.x, height: end.y - start.y)
        let fit = fitted(delta, from: start, within: bounds, fromCenter: false, keepsAspect: true)
        return CGPoint(x: start.x + fit.width, y: start.y + fit.height)
    }

    private static func proportionalDelta(_ delta: CGSize, aspect: CGSize) -> CGSize {
        guard aspect.width > 0, aspect.height > 0 else { return delta }
        let scale = max(abs(delta.width) / aspect.width, abs(delta.height) / aspect.height)
        return CGSize(
            width: (delta.width < 0 ? -1 : 1) * aspect.width * scale,
            height: (delta.height < 0 ? -1 : 1) * aspect.height * scale
        )
    }

    /// `delta` from `start` limited to the room left in `bounds` (on both sides, from center).
    /// Keeping the aspect scales both axes by the tighter limit.
    private static func fitted(_ delta: CGSize, from start: CGPoint, within bounds: CGRect, fromCenter: Bool, keepsAspect: Bool) -> CGSize {
        func room(_ value: CGFloat, _ origin: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
            let ahead = value < 0 ? origin - low : high - origin
            return max(0, fromCenter ? min(origin - low, high - origin) : ahead)
        }
        let roomX = room(delta.width, start.x, bounds.minX, bounds.maxX)
        let roomY = room(delta.height, start.y, bounds.minY, bounds.maxY)
        if keepsAspect {
            let scale = min(
                1, abs(delta.width) > roomX ? roomX / abs(delta.width) : 1, abs(delta.height) > roomY ? roomY / abs(delta.height) : 1)
            return CGSize(width: delta.width * scale, height: delta.height * scale)
        }
        return CGSize(
            width: (delta.width < 0 ? -1 : 1) * min(abs(delta.width), roomX),
            height: (delta.height < 0 ? -1 : 1) * min(abs(delta.height), roomY)
        )
    }

    /// Whether `point` is inside the ellipse inscribed in `rect`.
    static func ellipse(_ rect: CGRect, contains point: CGPoint) -> Bool {
        guard rect.width > 0, rect.height > 0 else { return false }
        let x = (point.x - rect.midX) / (rect.width / 2)
        let y = (point.y - rect.midY) / (rect.height / 2)
        return x * x + y * y <= 1
    }
}
