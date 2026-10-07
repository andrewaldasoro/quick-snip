import CoreGraphics
import Testing
@testable import QuickSnip

struct CropMathTests {
    private let points = CGSize(width: 100, height: 80)

    @Test func oneXIsIdentity() {
        let rect = CropMath.pixelRect(for: CGRect(x: 10, y: 20, width: 30, height: 40), pointSize: points, pixelSize: points)
        #expect(rect == CGRect(x: 10, y: 20, width: 30, height: 40))
    }

    @Test func retinaDoublesEverything() {
        let rect = CropMath.pixelRect(
            for: CGRect(x: 10, y: 20, width: 30, height: 40),
            pointSize: points,
            pixelSize: CGSize(width: 200, height: 160)
        )
        #expect(rect == CGRect(x: 20, y: 40, width: 60, height: 80))
    }

    @Test func nonIntegerScaleRoundsEdgesIndependently() {
        // 1.5x (e.g. scaled display mode): 10.0→15, 13.0→19.5→20.
        let rect = CropMath.pixelRect(
            for: CGRect(x: 10, y: 10, width: 3, height: 3),
            pointSize: points,
            pixelSize: CGSize(width: 150, height: 120)
        )
        #expect(rect == CGRect(x: 15, y: 15, width: 5, height: 5))
    }

    @Test func adjacentSelectionsTileWithoutGapOrOverlap() {
        let pixels = CGSize(width: 150, height: 120)
        let left = CropMath.pixelRect(for: CGRect(x: 0, y: 0, width: 33.3, height: 10), pointSize: points, pixelSize: pixels)!
        let right = CropMath.pixelRect(for: CGRect(x: 33.3, y: 0, width: 20, height: 10), pointSize: points, pixelSize: pixels)!
        #expect(left.maxX == right.minX)
    }

    @Test func fractionalPointsRoundToNearestPixel() {
        let rect = CropMath.pixelRect(
            for: CGRect(x: 10.3, y: 10.6, width: 5.4, height: 5.2),
            pointSize: points,
            pixelSize: CGSize(width: 200, height: 160)
        )
        // x: 20.6→21, maxX 31.4→31 · y: 21.2→21, maxY 31.6→32
        #expect(rect == CGRect(x: 21, y: 21, width: 10, height: 11))
    }

    @Test func nonUniformScaleUsesEachAxis() {
        let rect = CropMath.pixelRect(
            for: CGRect(x: 10, y: 10, width: 10, height: 10),
            pointSize: points,
            pixelSize: CGSize(width: 200, height: 80)
        )
        #expect(rect == CGRect(x: 20, y: 10, width: 20, height: 10))
    }

    @Test func clampsToImageBounds() {
        let rect = CropMath.pixelRect(for: CGRect(x: 90, y: 70, width: 50, height: 50), pointSize: points, pixelSize: points)
        #expect(rect == CGRect(x: 90, y: 70, width: 10, height: 10))
    }

    @Test func negativeSizeIsStandardized() {
        let rect = CropMath.pixelRect(for: CGRect(x: 40, y: 50, width: -30, height: -20), pointSize: points, pixelSize: points)
        #expect(rect == CGRect(x: 10, y: 30, width: 30, height: 20))
    }

    @Test(arguments: [
        CGRect(x: 10, y: 10, width: 0, height: 10),
        CGRect(x: 10, y: 10, width: 0.2, height: 0.2),
        CGRect(x: 200, y: 200, width: 10, height: 10),
    ])
    func emptyOrOutsideSelectionIsNil(selection: CGRect) {
        #expect(CropMath.pixelRect(for: selection, pointSize: points, pixelSize: points) == nil)
    }

    @Test func zeroPointSizeIsNil() {
        #expect(CropMath.pixelRect(for: CGRect(x: 0, y: 0, width: 1, height: 1), pointSize: .zero, pixelSize: points) == nil)
    }

    @Test func cropTakesPixelsFromSelectedRegionOnRetina() throws {
        let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)
        let image = try #require(CropMath.crop(display, to: CGRect(x: 10, y: 20, width: 30, height: 15)))

        #expect(image.width == 60)
        #expect(image.height == 30)
        #expect(TestImages.pixel(image, x: 0, y: 0) == RGBA(r: 20, g: 40, b: 0, a: 255))
        #expect(TestImages.pixel(image, x: 59, y: 29) == RGBA(r: 79, g: 69, b: 0, a: 255))
    }

    @Test func cropUsesDisplayLocalCoordinatesNotGlobalFrame() throws {
        // Secondary display offset in global space; selection is display-local.
        let display = TestImages.display(id: 2, frame: CGRect(x: 1000, y: -500, width: 100, height: 80), scale: 1)
        let image = try #require(CropMath.crop(display, to: CGRect(x: 5, y: 6, width: 10, height: 10)))
        #expect(TestImages.pixel(image, x: 0, y: 0) == RGBA(r: 5, g: 6, b: 0, a: 255))
    }
}
