import CoreGraphics

/// One display frozen at capture time.
struct CapturedDisplay: @unchecked Sendable {
    let displayID: CGDirectDisplayID
    /// Display frame in AppKit global coordinates (points, bottom-left origin).
    let frame: CGRect
    /// Full-resolution capture (pixels, top-left origin).
    let image: CGImage

    /// Display-local bounds in points, top-left origin — the overlay view's coordinate space.
    var localBounds: CGRect { CGRect(origin: .zero, size: frame.size) }
    var pixelSize: CGSize { CGSize(width: image.width, height: image.height) }
}
