import CoreGraphics

/// The line widths offered for shapes, lines and strokes, in points (pixels at 1×).
enum LineWidth {
    static let presets: [CGFloat] = [1, 2, 3, 4, 6, 8, 12, 16]
    static let `default`: CGFloat = 4
}
