import CoreGraphics

/// Where the style panel sits: beside the toolbar (to its left, same top edge) when the
/// selection is wide enough to hold both; otherwise stacked on the toolbar's far side from the
/// selection (below a toolbar under the selection, above one over it), right-aligned with it.
/// Always within `bounds`.
enum StylePanelLayout {
    static let gap: CGFloat = 6

    static func frame(size: CGSize, toolbar: CGRect, selection: CGRect, bounds: CGRect) -> CGRect {
        let margin = ToolbarLayout.margin
        let besideX = toolbar.minX - gap - size.width
        let fitsBeside = toolbar.width + gap + size.width <= selection.width && besideX >= bounds.minX + margin
        if fitsBeside {
            return CGRect(x: besideX, y: toolbar.minY, width: size.width, height: size.height)
        }

        let x = min(max(toolbar.maxX - size.width, bounds.minX + margin), bounds.maxX - margin - size.width)
        let below = toolbar.maxY + gap
        let above = toolbar.minY - gap - size.height
        let isToolbarAboveSelection = toolbar.maxY <= selection.minY
        let prefersBelow = !isToolbarAboveSelection
        let fitsBelow = below + size.height <= bounds.maxY - margin
        let fitsAbove = above >= bounds.minY + margin
        let y: CGFloat
        if prefersBelow ? fitsBelow : !fitsAbove && fitsBelow {
            y = below
        } else if fitsAbove {
            y = above
        } else {
            y = min(max(below, bounds.minY + margin), bounds.maxY - margin - size.height)
        }
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
