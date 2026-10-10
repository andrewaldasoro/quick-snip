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
}
