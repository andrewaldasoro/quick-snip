import AppKit

/// Where an image's visible pixels are. SF Symbols carry padding (room for descenders, optical
/// balance), so centering an image's bounds or alignment rect can leave the glyph you see
/// off-center; centering its ink doesn't.
enum ImageInk {
    /// Pixels at least this opaque count as ink; softer ones are anti-aliasing.
    static let alphaThreshold: UInt8 = 64

    /// The ink's bounding box in `image`'s pixels, top-left origin; nil when it's blank.
    static func pixelBounds(of image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        var alpha = [UInt8](repeating: 0, count: width * height)
        let drawn = alpha.withUnsafeMutableBytes { buffer in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var minX = width
        var maxX = -1
        var minY = height
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width where alpha[y * width + x] >= alphaThreshold {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// Where to draw `image` (in a flipped view) so its ink is centered in `bounds`, on whole
    /// pixels at `scale`. Falls back to centering the image itself when it has no ink.
    @MainActor
    static func centeredRect(for image: NSImage, in bounds: CGRect, scale: CGFloat) -> CGRect {
        let size = image.size
        var proposed = CGRect(origin: .zero, size: size)
        let ink: CGRect
        if let cgImage = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil),
            let pixels = pixelBounds(of: cgImage), cgImage.width > 0
        {
            let toPoints = size.width / CGFloat(cgImage.width)
            ink = CGRect(
                x: pixels.minX * toPoints, y: pixels.minY * toPoints, width: pixels.width * toPoints, height: pixels.height * toPoints)
        } else {
            ink = CGRect(origin: .zero, size: size)
        }
        func snap(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
        let x = snap(bounds.midX - ink.midX)
        let y = snap(bounds.midY - ink.midY)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
