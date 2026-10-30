import CoreGraphics

enum SelectionHit: Equatable, Sendable {
    case handle(SelectionHandle)
    case inside
    case outside
}

/// Drag-to-select state for one display: create, move, and resize, clamped to `bounds`.
/// Coordinates are display-local points with a top-left origin.
struct SelectionEditor {
    static let hitTolerance: CGFloat = 6
    /// Smaller drags on creation count as a click and clear the selection.
    static let minimumSize: CGFloat = 2

    private enum Drag {
        case creating(anchor: CGPoint)
        case moving(start: CGPoint, original: CGRect)
        case resizing(SelectionHandle, original: CGRect)
    }

    let bounds: CGRect
    private(set) var selection: CGRect?
    private var drag: Drag?

    init(bounds: CGRect) {
        self.bounds = bounds
    }

    var isDragging: Bool { drag != nil }

    var isMoving: Bool {
        if case .moving = drag { return true }
        return false
    }

    func hitTest(_ point: CGPoint) -> SelectionHit {
        guard let rect = selection else { return .outside }
        let tolerance = Self.hitTolerance

        for handle in SelectionHandle.allCases where handle.isCorner {
            let p = handle.point(in: rect)
            if abs(point.x - p.x) <= tolerance, abs(point.y - p.y) <= tolerance {
                return .handle(handle)
            }
        }

        let withinX = point.x >= rect.minX - tolerance && point.x <= rect.maxX + tolerance
        let withinY = point.y >= rect.minY - tolerance && point.y <= rect.maxY + tolerance
        if withinX, abs(point.y - rect.minY) <= tolerance { return .handle(.top) }
        if withinX, abs(point.y - rect.maxY) <= tolerance { return .handle(.bottom) }
        if withinY, abs(point.x - rect.minX) <= tolerance { return .handle(.left) }
        if withinY, abs(point.x - rect.maxX) <= tolerance { return .handle(.right) }

        return rect.contains(point) ? .inside : .outside
    }

    mutating func mouseDown(at point: CGPoint) {
        switch (hitTest(point), selection) {
        case (.handle(let handle), let selection?):
            drag = .resizing(handle, original: selection)
        case (.inside, let selection?):
            drag = .moving(start: point, original: selection)
        default:
            let anchor = clamp(point)
            drag = .creating(anchor: anchor)
            selection = CGRect(origin: anchor, size: .zero)
        }
    }

    mutating func mouseDragged(to point: CGPoint) {
        guard let drag else { return }
        let p = clamp(point)

        switch drag {
        case .creating(let anchor):
            selection = Geometry.rect(from: anchor, to: p)

        case .moving(let start, let original):
            let x = min(max(original.minX + point.x - start.x, bounds.minX), bounds.maxX - original.width)
            let y = min(max(original.minY + point.y - start.y, bounds.minY), bounds.maxY - original.height)
            selection = CGRect(origin: CGPoint(x: x, y: y), size: original.size)

        case .resizing(let handle, let original):
            selection = handle.resize(original, to: p)
        }
    }

    mutating func mouseUp(at point: CGPoint) {
        guard let drag else { return }
        mouseDragged(to: point)
        if case .creating = drag, let rect = selection,
            rect.width < Self.minimumSize || rect.height < Self.minimumSize
        {
            selection = nil
        }
        self.drag = nil
    }

    /// Replaces the selection with `rect`, clipped to the display (a snapped window).
    mutating func select(_ rect: CGRect) {
        let clipped = rect.intersection(bounds)
        selection = clipped.isNull ? nil : clipped
        drag = nil
    }

    mutating func clear() {
        selection = nil
        drag = nil
    }

    private func clamp(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}
