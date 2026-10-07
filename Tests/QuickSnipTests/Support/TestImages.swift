import CoreGraphics
import Foundation
import ImageIO
@testable import QuickSnip

struct RGBA: Equatable {
    var r: UInt8, g: UInt8, b: UInt8, a: UInt8
}

/// Synthetic captures whose pixels encode their own coordinates (r = x % 256, g = y % 256),
/// so tests can verify exactly which region a crop came from.
enum TestImages {
    static func coordinateImage(width: Int, height: Int) -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                bytes[i] = UInt8(x % 256)
                bytes[i + 1] = UInt8(y % 256)
                bytes[i + 2] = 0
                bytes[i + 3] = 255
            }
        }
        let context = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    static func solidImage(width: Int, height: Int, color: RGBA) -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            bytes[i] = color.r; bytes[i + 1] = color.g; bytes[i + 2] = color.b; bytes[i + 3] = color.a
        }
        let context = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    /// Pixel at (x, y), top-left origin.
    static func pixel(_ image: CGImage, x: Int, y: Int) -> RGBA {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let i = (y * width + x) * 4
        return RGBA(r: bytes[i], g: bytes[i + 1], b: bytes[i + 2], a: bytes[i + 3])
    }

    /// A display at `frame` (AppKit global points) captured at `scale`.
    static func display(id: CGDirectDisplayID, frame: CGRect, scale: CGFloat) -> CapturedDisplay {
        let image = coordinateImage(width: Int(frame.width * scale), height: Int(frame.height * scale))
        return CapturedDisplay(displayID: id, frame: frame, image: image)
    }

    static func decodePNG(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("QuickSnipTests-\(UUID().uuidString)", isDirectory: true)
    }
}

extension RGBA {
    /// Roughly the annotation color (antialiasing/colour management tolerant).
    func isClose(to color: AnnotationColor, tolerance: Int = 40) -> Bool {
        let c = color.components
        let expected = [c.red, c.green, c.blue].map { Int(($0 * 255).rounded()) }
        return zip([Int(r), Int(g), Int(b)], expected).allSatisfy { abs($0 - $1) <= tolerance }
    }
}

enum TestSessions {
    /// Selects `rect` on `display` by dragging.
    @MainActor
    static func select(_ session: CaptureSession, on display: CGDirectDisplayID, _ rect: CGRect) {
        session.mouseDown(on: display, at: rect.origin)
        session.mouseDragged(on: display, to: CGPoint(x: rect.maxX, y: rect.maxY))
        session.mouseUp(on: display, at: CGPoint(x: rect.maxX, y: rect.maxY))
    }

    /// A drag with the current tool (or a move without one).
    @MainActor
    static func drag(_ session: CaptureSession, on display: CGDirectDisplayID, from start: CGPoint, through points: [CGPoint] = [], to end: CGPoint) {
        session.mouseDown(on: display, at: start)
        for point in points { session.mouseDragged(on: display, to: point) }
        session.mouseDragged(on: display, to: end)
        session.mouseUp(on: display, at: end)
    }
}
