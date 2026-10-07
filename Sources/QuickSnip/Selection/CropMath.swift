import CoreGraphics

/// Point ↔ pixel mapping for selections. Selections live in display-local points
/// (top-left origin); captured images are pixels (top-left origin).
enum CropMath {
    /// Pixel rect in the captured image for `selection`. Edges are rounded independently so
    /// adjacent selections tile without gaps or overlap. `nil` when nothing remains after clamping.
    static func pixelRect(for selection: CGRect, pointSize: CGSize, pixelSize: CGSize) -> CGRect? {
        guard pointSize.width > 0, pointSize.height > 0 else { return nil }
        let scaleX = pixelSize.width / pointSize.width
        let scaleY = pixelSize.height / pointSize.height
        let points = selection.standardized

        let minX = (points.minX * scaleX).rounded()
        let maxX = (points.maxX * scaleX).rounded()
        let minY = (points.minY * scaleY).rounded()
        let maxY = (points.maxY * scaleY).rounded()

        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            .intersection(CGRect(origin: .zero, size: pixelSize))
        guard !rect.isNull, rect.width >= 1, rect.height >= 1 else { return nil }
        return rect
    }

    static func pixelRect(for selection: CGRect, in display: CapturedDisplay) -> CGRect? {
        pixelRect(for: selection, pointSize: display.frame.size, pixelSize: display.pixelSize)
    }

    static func crop(_ display: CapturedDisplay, to selection: CGRect) -> CGImage? {
        guard let rect = pixelRect(for: selection, in: display) else { return nil }
        return display.image.cropping(to: rect)
    }
}
