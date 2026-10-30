import AppKit

/// Which cursor the overlay shows for the current pointer position and mode.
enum OverlayCursor: Equatable {
    case crosshair
    case arrow
    case iBeam
    case openHand
    case closedHand
    case resize(SelectionHandle)

    static func resolve(
        hit: SelectionHit,
        annotationHandle: AnnotationHandle? = nil,
        tool: AnnotationTool?,
        insideSelection: Bool,
        overAnnotation: Bool,
        hasAnnotations: Bool,
        isMoving: Bool
    ) -> OverlayCursor {
        if isMoving { return .closedHand }
        switch annotationHandle {
        case .frame(let handle): return .resize(handle)
        case .start, .end: return .crosshair
        case nil: break
        }
        if case .handle(let handle) = hit { return .resize(handle) }
        if let tool {
            guard insideSelection else { return .arrow }
            return tool == .text ? .iBeam : .crosshair
        }
        if insideSelection { return .openHand }
        if hasAnnotations { return .arrow }
        return .crosshair
    }

    var nsCursor: NSCursor {
        switch self {
        case .crosshair: .crosshair
        case .arrow: .arrow
        case .iBeam: .iBeam
        case .openHand: .openHand
        case .closedHand: .closedHand
        case .resize(let handle): Self.resizeCursor(for: handle)
        }
    }

    private static func resizeCursor(for handle: SelectionHandle) -> NSCursor {
        let position: NSCursor.FrameResizePosition =
            switch handle {
            case .topLeft: .topLeft
            case .top: .top
            case .topRight: .topRight
            case .right: .right
            case .bottomRight: .bottomRight
            case .bottom: .bottom
            case .bottomLeft: .bottomLeft
            case .left: .left
            }
        return NSCursor.frameResize(position: position, directions: .all)
    }
}
