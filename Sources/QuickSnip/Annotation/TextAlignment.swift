import AppKit

/// How lines of text line up inside their box (a dragged box, or click text's own box: as wide
/// as its longest line).
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
}
