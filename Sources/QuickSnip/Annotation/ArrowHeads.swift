/// Which ends of an arrow get a head. `none` is a plain line.
enum ArrowHeads: String, CaseIterable, Sendable {
    case none, end, both

    var displayName: String {
        switch self {
        case .none: "No Arrowhead"
        case .end: "Arrowhead at End"
        case .both: "Arrowheads at Both Ends"
        }
    }

    /// "Line", "Arrow" or "Double Arrow", for undo names.
    var annotationName: String {
        switch self {
        case .none: "Line"
        case .end: "Arrow"
        case .both: "Double Arrow"
        }
    }

    var symbol: String {
        switch self {
        case .none: "line.diagonal"
        case .end: "arrow.up.right"
        case .both: "arrow.up.left.and.arrow.down.right"
        }
    }

    var hasStartHead: Bool { self == .both }
    var hasEndHead: Bool { self != .none }
}
