import Testing
@testable import QuickSnip

struct PNGEncoderTests {
    @Test func encodesPNGSignature() throws {
        let data = try #require(PNGEncoder.encode(TestImages.coordinateImage(width: 4, height: 3)))
        #expect(Array(data.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }

    @Test func roundTripPreservesSizeAndPixels() throws {
        let original = TestImages.coordinateImage(width: 40, height: 30)
        let data = try #require(PNGEncoder.encode(original))
        let decoded = try #require(TestImages.decodePNG(data))

        #expect(decoded.width == 40)
        #expect(decoded.height == 30)
        #expect(TestImages.pixel(decoded, x: 13, y: 21) == RGBA(r: 13, g: 21, b: 0, a: 255))
    }
}
