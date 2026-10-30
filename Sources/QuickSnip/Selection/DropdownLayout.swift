import CoreGraphics

/// Where an open dropdown list goes: under its button, left-aligned like a pop-up menu; above
/// it when there's no room below. When neither side holds the whole list, it takes the side
/// with more room and gets shorter (its rows scroll). Always within `bounds`.
enum DropdownLayout {
    static let gap: CGFloat = 6
    /// Shorter than this and the list isn't usable; it overlaps rather than shrinking further.
    static let minimumHeight: CGFloat = 80

    static func frame(size: CGSize, anchor: CGRect, bounds: CGRect) -> CGRect {
        let margin = ToolbarLayout.margin
        let x = min(max(anchor.minX, bounds.minX + margin), bounds.maxX - margin - size.width)
        let roomBelow = bounds.maxY - margin - (anchor.maxY + gap)
        let roomAbove = anchor.minY - gap - (bounds.minY + margin)

        if size.height <= roomBelow {
            return CGRect(x: x, y: anchor.maxY + gap, width: size.width, height: size.height)
        }
        if size.height <= roomAbove {
            return CGRect(x: x, y: anchor.minY - gap - size.height, width: size.width, height: size.height)
        }
        let height = max(min(size.height, max(roomBelow, roomAbove)), minimumHeight)
        let y = roomBelow >= roomAbove ? anchor.maxY + gap : anchor.minY - gap - height
        let clampedY = min(max(y, bounds.minY + margin), bounds.maxY - margin - height)
        return CGRect(x: x, y: clampedY, width: size.width, height: height)
    }
}
