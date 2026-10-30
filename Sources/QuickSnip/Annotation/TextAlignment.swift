import AppKit

/// How text lines up: inside its box, or around the point where it was placed.
enum TextAlignment: String, CaseIterable, Sendable {
    case left, center, right

    var displayName: String {
        switch self {
        case .left: "Align Left"
        case .center: "Align Center"
        case .right: "Align Right"
        }
    }

    var symbol: String {
        switch self {
        case .left: "text.alignleft"
        case .center: "text.aligncenter"
        case .right: "text.alignright"
        }
    }

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        }
    }

    /// Where the placement point sits across a line of text: its start, middle or end.
    var anchorFraction: CGFloat {
        switch self {
        case .left: 0
        case .center: 0.5
        case .right: 1
        }
    }
}
