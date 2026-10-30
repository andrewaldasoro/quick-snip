import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct ImageInkTests {
    /// A 20×10 px image with an opaque 4×2 block at (6, 3) from the top-left.
    private func block() throws -> CGImage {
        let context = try #require(
            CGContext(
                data: nil, width: 20, height: 10, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 6, y: 10 - 3 - 2, width: 4, height: 2))  // Core Graphics: bottom-left origin
        return try #require(context.makeImage())
    }

    @Test func findsTheInkFromTheTopLeft() throws {
        #expect(ImageInk.pixelBounds(of: try block()) == CGRect(x: 6, y: 3, width: 4, height: 2))
    }

    @Test func aBlankImageHasNoInk() throws {
        let context = try #require(
            CGContext(
                data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        #expect(ImageInk.pixelBounds(of: try #require(context.makeImage())) == nil)
    }

    @Test func centersTheInkNotTheImage() throws {
        let image = NSImage(cgImage: try block(), size: NSSize(width: 20, height: 10))
        let rect = ImageInk.centeredRect(for: image, in: CGRect(x: 0, y: 0, width: 40, height: 40), scale: 1)
        // Ink midpoint in the image is (8, 4); it lands on the bounds' center (20, 20).
        #expect(rect == CGRect(x: 12, y: 16, width: 20, height: 10))
    }

    @Test func snapsToWholePixels() throws {
        let image = NSImage(cgImage: try block(), size: NSSize(width: 20, height: 10))
        let rect = ImageInk.centeredRect(for: image, in: CGRect(x: 0, y: 0, width: 41, height: 41), scale: 2)
        #expect((rect.minX * 2).rounded() == rect.minX * 2)
        #expect((rect.minY * 2).rounded() == rect.minY * 2)
    }

    @Test func aBlankImageIsCenteredByItsSize() {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        let rect = ImageInk.centeredRect(for: image, in: CGRect(x: 0, y: 0, width: 30, height: 30), scale: 1)
        #expect(rect == CGRect(x: 10, y: 10, width: 10, height: 10))
    }
}
