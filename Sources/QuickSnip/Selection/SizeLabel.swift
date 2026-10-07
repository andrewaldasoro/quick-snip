import CoreGraphics

/// Text and placement of the live "W × H" pixel size label.
enum SizeLabel {
    static let gap: CGFloat = 6

    static func text(for pixelSize: CGSize) -> String {
        "\(Int(pixelSize.width)) × \(Int(pixelSize.height))"
    }

    /// Above the selection's top-left corner; inside it when there's no room above.
    /// Kept horizontally within `bounds`.
    static func origin(labelSize: CGSize, selection: CGRect, bounds: CGRect) -> CGPoint {
        var y = selection.minY - gap - labelSize.height
        if y < bounds.minY {
            y = selection.minY + gap
        }
        let x = min(max(selection.minX, bounds.minX), bounds.maxX - labelSize.width)
        return CGPoint(x: x, y: y)
    }
}
