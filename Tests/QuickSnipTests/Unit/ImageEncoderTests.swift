import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import QuickSnip

struct ImageEncoderTests {
    private func properties(_ data: Data) -> [CFString: Any] {
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    }

    @Test func encodesPNGSignature() throws {
        let data = try #require(ImageEncoder.encode(TestImages.coordinateImage(width: 4, height: 3), as: .png))
        #expect(Array(data.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }

    @Test func encodesJPEGSignature() throws {
        let data = try #require(ImageEncoder.encode(TestImages.coordinateImage(width: 4, height: 3), as: .jpeg))
        #expect(Array(data.prefix(3)) == [0xFF, 0xD8, 0xFF])
    }

    @Test func pngRoundTripPreservesSizeAndPixels() throws {
        let data = try #require(ImageEncoder.encode(TestImages.coordinateImage(width: 40, height: 30), as: .png))
        let decoded = try #require(TestImages.decodePNG(data))
        #expect(decoded.width == 40)
        #expect(decoded.height == 30)
        #expect(TestImages.pixel(decoded, x: 13, y: 21) == RGBA(r: 13, g: 21, b: 0, a: 255))
    }

    @Test func jpegRoundTripPreservesSize() throws {
        let data = try #require(ImageEncoder.encode(TestImages.coordinateImage(width: 40, height: 30), as: .jpeg))
        let decoded = try #require(TestImages.decodePNG(data))
        #expect(decoded.width == 40)
        #expect(decoded.height == 30)
    }

    @Test(arguments: [(ImageFormat.png, CGFloat(2), 144.0), (.png, 1, 72), (.jpeg, 2, 144)] as [(ImageFormat, CGFloat, Double)])
    func taggedWithRetinaAwareDPI(format: ImageFormat, scale: CGFloat, dpi: Double) throws {
        let data = try #require(ImageEncoder.encode(TestImages.coordinateImage(width: 8, height: 8), as: format, scale: scale))
        let props = properties(data)
        #expect((props[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue.rounded() == dpi)
        #expect((props[kCGImagePropertyDPIHeight] as? NSNumber)?.doubleValue.rounded() == dpi)
    }

    @Test func formatsDescribeThemselves() {
        #expect(ImageFormat.png.fileExtension == "png")
        #expect(ImageFormat.jpeg.fileExtension == "jpg")
        #expect(ImageFormat.jpeg.displayName == "JPEG")
        #expect(ImageFormat.png.utType == .png)
    }
}
