/// What the Shape tool draws: an outlined rectangle or oval, picked in the style panel.
enum ShapeKind: String, CaseIterable, Sendable {
    case rectangle, oval

    var displayName: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .rectangle: "rectangle"
        case .oval: "oval"
        }
    }
}
