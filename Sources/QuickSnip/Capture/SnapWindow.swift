import CoreGraphics

/// A window a click can select, in its display's local points (top-left origin).
struct SnapWindow: Equatable, Sendable {
    let id: CGWindowID
    /// The whole window; can reach past the display's edges.
    let frame: CGRect
    /// The part on this display: what a click selects.
    let visibleFrame: CGRect
}
