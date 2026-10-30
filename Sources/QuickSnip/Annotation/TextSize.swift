import CoreGraphics

/// Text annotation sizes, in points (pixels at 1×).
enum TextSize {
    /// Sizes a corner drag can reach; the menu offers `presets`.
    static let range: ClosedRange<CGFloat> = 8...200
    static let presets: [CGFloat] = [10, 12, 14, 16, 18, 22, 28, 36, 48, 64, 96]
    static let `default`: CGFloat = 22

    static func clamp(_ size: CGFloat) -> CGFloat {
        min(max(size.rounded(), range.lowerBound), range.upperBound)
    }

    /// The sizes to offer: the presets, plus `current` in order when a corner drag made it
    /// something else, so the menu always shows what's selected.
    static func choices(including current: CGFloat) -> [CGFloat] {
        presets.contains(current) ? presets : (presets + [current]).sorted()
    }
}
