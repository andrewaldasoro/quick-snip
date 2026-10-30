import CoreGraphics
import Foundation

/// Text annotation sizes, in points (pixels at 1×), as typed into the toolbar's size field.
enum TextSize {
    static let range: ClosedRange<CGFloat> = 8...200
    static let `default`: CGFloat = 22
    static let step: CGFloat = 1

    static func clamp(_ size: CGFloat) -> CGFloat {
        min(max(size.rounded(), range.lowerBound), range.upperBound)
    }

    /// A typed size ("36", "36px", " 36.4 "), clamped and rounded; nil for anything else.
    static func parse(_ text: String) -> CGFloat? {
        var trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.hasSuffix("px") { trimmed = String(trimmed.dropLast(2)).trimmingCharacters(in: .whitespaces) }
        guard let value = Double(trimmed), value.isFinite else { return nil }
        return clamp(CGFloat(value))
    }
}
