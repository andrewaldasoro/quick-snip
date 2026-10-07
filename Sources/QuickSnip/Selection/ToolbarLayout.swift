import CoreGraphics

/// Where the annotation toolbar sits: below the selection, right-aligned; above it when
/// there's no room below; inside its bottom edge as a last resort. Always within `bounds`.
enum ToolbarLayout {
    static let margin: CGFloat = 8

    static func frame(size: CGSize, selection: CGRect, bounds: CGRect) -> CGRect {
        let minX = bounds.minX + margin
        let maxX = bounds.maxX - margin - size.width
        let x = max(minX, min(selection.maxX - size.width, maxX))

        let below = selection.maxY + margin
        let above = selection.minY - margin - size.height
        let y: CGFloat
        if below + size.height <= bounds.maxY - margin {
            y = below
        } else if above >= bounds.minY + margin {
            y = above
        } else {
            y = max(bounds.minY + margin, selection.maxY - margin - size.height)
        }
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
