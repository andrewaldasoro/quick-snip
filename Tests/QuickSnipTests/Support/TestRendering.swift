import AppKit
import Testing

/// Renders a view into a bitmap at an exact scale, whatever this Mac's screen is: CI draws at
/// 1×, a Retina Mac at 2×, and some bugs only show at one of them.
enum TestRendering {
    @MainActor
    static func render(_ view: NSView, scale: Int) throws -> CGImage {
        let width = Int(view.bounds.width) * scale
        let height = Int(view.bounds.height) * scale
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        return try #require(rep.cgImage)
    }
}
