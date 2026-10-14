import CoreGraphics
import Testing

@testable import QuickSnip

@MainActor
struct PixelateCacheTests {
    @Test func pixelatedBlocksAreUniform() throws {
        let image = TestImages.coordinateImage(width: 40, height: 40)
        let result = try #require(PixelateCache.pixelate(image, blockSize: 10))

        #expect(result.width == 40)
        #expect(result.height == 40)
        let reference = TestImages.pixel(result, x: 12, y: 12)
        for (x, y) in [(10, 10), (19, 19), (15, 11)] {
            #expect(TestImages.pixel(result, x: x, y: y) == reference)
        }
        #expect(TestImages.pixel(result, x: 25, y: 12) != reference)
    }

    @Test func pixelationDestroysDetail() throws {
        let image = TestImages.coordinateImage(width: 40, height: 40)
        let result = try #require(PixelateCache.pixelate(image, blockSize: 10))
        #expect(TestImages.pixel(result, x: 10, y: 10) == TestImages.pixel(result, x: 11, y: 10))
        #expect(TestImages.pixel(image, x: 10, y: 10) != TestImages.pixel(image, x: 11, y: 10))
    }

    @Test func cachesPerRegion() throws {
        let cache = PixelateCache()
        let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)
        let rect = CGRect(x: 10, y: 10, width: 40, height: 40)

        let first = try #require(cache.image(for: display, pixelRect: rect))
        let second = try #require(cache.image(for: display, pixelRect: rect))
        #expect(first === second)
        #expect(cache.count == 1)

        _ = cache.image(for: display, pixelRect: rect.offsetBy(dx: 1, dy: 0))
        #expect(cache.count == 2)
    }

    @Test func removeAllEmptiesTheCache() {
        let cache = PixelateCache()
        let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 1)
        _ = cache.image(for: display, pixelRect: CGRect(x: 0, y: 0, width: 10, height: 10))

        cache.removeAll()

        #expect(cache.count == 0)
    }

    @Test func cacheIsBounded() {
        let cache = PixelateCache()
        let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 1)
        for i in 0...PixelateCache.capacity {
            _ = cache.image(for: display, pixelRect: CGRect(x: i % 50, y: 0, width: 10 + i / 50, height: 10))
        }
        #expect(cache.count <= PixelateCache.capacity)
    }

    @Test func blockSizeScalesWithDisplay() throws {
        // 10pt blocks: 20px on a 2x display. Pixels 0…19 share a block.
        let cache = PixelateCache()
        let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)
        let image = try #require(cache.image(for: display, pixelRect: CGRect(x: 0, y: 0, width: 80, height: 80)))
        #expect(TestImages.pixel(image, x: 0, y: 0) == TestImages.pixel(image, x: 19, y: 19))
    }
}
