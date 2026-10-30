import CoreGraphics

enum SelectionHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    /// Handle position on `rect` (top-left origin).
    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .top: CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .right: CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .left: CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    /// `rect` with this handle's edges moved to `point`; dragging past the opposite edge flips it.
    func resize(_ rect: CGRect, to point: CGPoint) -> CGRect {
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY
        switch self {
        case .topLeft:
            minX = point.x
            minY = point.y
        case .top: minY = point.y
        case .topRight:
            maxX = point.x
            minY = point.y
        case .right: maxX = point.x
        case .bottomRight:
            maxX = point.x
            maxY = point.y
        case .bottom: maxY = point.y
        case .bottomLeft:
            minX = point.x
            maxY = point.y
        case .left: minX = point.x
        }
        return Geometry.rect(from: CGPoint(x: minX, y: minY), to: CGPoint(x: maxX, y: maxY))
    }

    var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomRight, .bottomLeft: true
        case .top, .right, .bottom, .left: false
        }
    }
}
