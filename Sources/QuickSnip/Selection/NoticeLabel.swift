import CoreGraphics

/// Placement of a status notice ("Reading text…"): centered on the selection, kept on screen.
enum NoticeLabel {
    static let padding = CGSize(width: 12, height: 7)
    static let cornerRadius: CGFloat = 9
    static let fontSize: CGFloat = 13

    static func frame(textSize: CGSize, selection: CGRect, bounds: CGRect) -> CGRect {
        let size = CGSize(width: textSize.width + padding.width * 2, height: textSize.height + padding.height * 2)
        let x = min(max(selection.midX - size.width / 2, bounds.minX), bounds.maxX - size.width)
        let y = min(max(selection.midY - size.height / 2, bounds.minY), bounds.maxY - size.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: size).integral
    }
}
