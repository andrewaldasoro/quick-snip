import CoreGraphics

/// A drag point on the selected annotation: a corner or edge of its frame, or a line's end.
enum AnnotationHandle: Equatable, Sendable {
    case frame(SelectionHandle)
    case start
    case end
}
