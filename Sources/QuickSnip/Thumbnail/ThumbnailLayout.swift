import CoreGraphics

/// Size and position of the post-capture thumbnail: aspect-fit within `maxSize`,
/// bottom-right of the screen's visible frame (AppKit coordinates, bottom-left origin).
enum ThumbnailLayout {
    static let maxSize = CGSize(width: 240, height: 160)
    static let minSide: CGFloat = 40
    static let margin: CGFloat = 16

    static func size(for imageSize: CGSize, maxSize: CGSize = maxSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGSize(width: minSide, height: minSide) }
        let scale = min(maxSize.width / imageSize.width, maxSize.height / imageSize.height, 1)
        return CGSize(
            width: max(minSide, (imageSize.width * scale).rounded()),
            height: max(minSide, (imageSize.height * scale).rounded())
        )
    }

    static func frame(size: CGSize, visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleFrame.maxX - margin - size.width,
            y: visibleFrame.minY + margin,
            width: size.width,
            height: size.height
        )
    }
}
