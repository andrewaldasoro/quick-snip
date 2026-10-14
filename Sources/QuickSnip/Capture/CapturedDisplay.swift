import CoreGraphics

/// One display frozen at capture time.
struct CapturedDisplay: @unchecked Sendable {
    let displayID: CGDirectDisplayID
    /// Display frame in AppKit global coordinates (points, bottom-left origin).
    let frame: CGRect
    /// Full-resolution capture (pixels, top-left origin).
    let image: CGImage
    /// Windows on this display at capture time, front to back.
    let windows: [SnapWindow]

    init(displayID: CGDirectDisplayID, frame: CGRect, image: CGImage, windows: [SnapWindow] = []) {
        self.displayID = displayID
        self.frame = frame
        self.image = image
        self.windows = windows
    }

    /// Display-local bounds in points, top-left origin — the overlay view's coordinate space.
    var localBounds: CGRect { CGRect(origin: .zero, size: frame.size) }
    var pixelSize: CGSize { CGSize(width: image.width, height: image.height) }

    /// The frontmost window under a display-local point.
    func window(at point: CGPoint) -> SnapWindow? {
        windows.first { $0.visibleFrame.contains(point) }
    }

    /// Another window in front overlaps it, so the frozen image doesn't show all of it.
    func isCovered(_ window: SnapWindow) -> Bool {
        guard let index = windows.firstIndex(of: window) else { return false }
        return windows[..<index].contains { $0.visibleFrame.intersects(window.visibleFrame) }
    }

    /// The window's full size in this display's pixels, to capture it at the same resolution.
    func pixelSize(of window: SnapWindow) -> CGSize {
        guard frame.width > 0, frame.height > 0 else { return .zero }
        return CGSize(
            width: (window.frame.width * pixelSize.width / frame.width).rounded(),
            height: (window.frame.height * pixelSize.height / frame.height).rounded()
        )
    }

    /// This display with `window` painted from its own capture on top, as if it had been
    /// brought to the front. `nil` if the image can't be composed.
    func bringingToFront(_ window: SnapWindow, image windowImage: CGImage) -> CapturedDisplay? {
        guard frame.width > 0, frame.height > 0,
            let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,  // sRGB always exists.
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }
        let scaleX = pixelSize.width / frame.width
        let scaleY = pixelSize.height / frame.height
        let pixels = localBounds.height * scaleY
        context.draw(image, in: CGRect(origin: .zero, size: pixelSize))
        // Core Graphics contexts have a bottom-left origin; window frames are top-left.
        let target = CGRect(
            x: window.frame.minX * scaleX, y: pixels - window.frame.maxY * scaleY,
            width: window.frame.width * scaleX, height: window.frame.height * scaleY)
        context.draw(windowImage, in: target)
        guard let composed = context.makeImage() else { return nil }
        let reordered = [window] + windows.filter { $0 != window }
        return CapturedDisplay(displayID: displayID, frame: frame, image: composed, windows: reordered)
    }
}
