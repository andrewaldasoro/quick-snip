import CoreGraphics
import Testing
@testable import QuickSnip

@MainActor
struct ExportRendererTests {
    /// 100×80 pt display captured at 2x; selection (10, 10)–(60, 50) → 100×80 px output.
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)
    private let selection = CGRect(x: 10, y: 10, width: 50, height: 40)

    private func render(_ annotations: [Annotation]) throws -> CGImage {
        try #require(ExportRenderer.render(display: display, selection: selection, annotations: annotations, cache: PixelateCache()))
    }

    /// Output pixel for a display-local point.
    private func pixel(_ image: CGImage, atPoint x: CGFloat, _ y: CGFloat) -> RGBA {
        TestImages.pixel(image, x: Int((x - selection.minX) * 2), y: Int((y - selection.minY) * 2))
    }

    /// Source pixel the export should keep where nothing is drawn.
    private func original(atPoint x: CGFloat, _ y: CGFloat) -> RGBA {
        TestImages.pixel(display.image, x: Int(x * 2), y: Int(y * 2))
    }

    @Test func withoutAnnotationsMatchesPlainCrop() throws {
        let image = try render([])
        #expect(image.width == 100)
        #expect(image.height == 80)
        #expect(pixel(image, atPoint: 10, 10) == original(atPoint: 10, 10))
        #expect(pixel(image, atPoint: 59.5, 49.5) == original(atPoint: 59.5, 49.5))
    }

    @Test func annotationsKeepFullResolutionAndUntouchedPixels() throws {
        let image = try render([Annotation(kind: .rectangle(CGRect(x: 20, y: 20, width: 20, height: 20)), style: .default)])
        #expect(image.width == 100)
        #expect(image.height == 80)
        #expect(pixel(image, atPoint: 30, 30) == original(atPoint: 30, 30))   // inside the outline
        #expect(pixel(image, atPoint: 12, 45) == original(atPoint: 12, 45))   // elsewhere
    }

    @Test func rectangleStrokeLandsOnItsEdgesInPixelSpace() throws {
        let image = try render([Annotation(kind: .rectangle(CGRect(x: 20, y: 20, width: 20, height: 20)), style: .default)])
        #expect(pixel(image, atPoint: 20, 30).isClose(to: .red))     // left edge
        #expect(pixel(image, atPoint: 30, 40).isClose(to: .red))     // bottom edge (top-left origin)
        #expect(!pixel(image, atPoint: 30, 25).isClose(to: .red))
    }

    @Test func strokeWidthScalesWithRetina() throws {
        // 4pt medium stroke = 8px: covers x 18…22 pt → pixels 36…43 from display origin.
        let image = try render([Annotation(kind: .line(from: CGPoint(x: 20, y: 15), to: CGPoint(x: 20, y: 45)), style: .default)])
        let y = Int((30 - selection.minY) * 2)
        let x = Int((20 - selection.minX) * 2)
        #expect(TestImages.pixel(image, x: x - 3, y: y).isClose(to: .red))
        #expect(TestImages.pixel(image, x: x + 3, y: y).isClose(to: .red))
        #expect(!TestImages.pixel(image, x: x + 6, y: y).isClose(to: .red))
    }

    @Test func arrowHasAHeadWiderThanTheShaft() throws {
        let style = AnnotationStyle(color: .blue, width: .thin)
        let image = try render([Annotation(kind: .arrow(from: CGPoint(x: 15, y: 30), to: CGPoint(x: 55, y: 30)), style: style)])
        #expect(pixel(image, atPoint: 30, 30).isClose(to: .blue))       // shaft
        #expect(!pixel(image, atPoint: 30, 33).isClose(to: .blue))      // shaft is thin
        #expect(pixel(image, atPoint: 47, 32).isClose(to: .blue))       // head is wide
    }

    @Test func penFollowsItsPoints() throws {
        let style = AnnotationStyle(color: .green, width: .medium)
        let image = try render([Annotation(kind: .pen([CGPoint(x: 15, y: 15), CGPoint(x: 50, y: 15), CGPoint(x: 50, y: 45)]), style: style)])
        #expect(pixel(image, atPoint: 30, 15).isClose(to: .green))
        #expect(pixel(image, atPoint: 50, 30).isClose(to: .green))
        #expect(!pixel(image, atPoint: 30, 30).isClose(to: .green))
    }

    @Test func markerIsTranslucent() throws {
        let style = AnnotationStyle(color: .yellow, width: .thin)
        let base = TestImages.solidImage(width: 200, height: 160, color: RGBA(r: 0, g: 0, b: 255, a: 255))
        let blue = CapturedDisplay(displayID: 1, frame: display.frame, image: base)
        let image = try #require(ExportRenderer.render(
            display: blue, selection: selection,
            annotations: [Annotation(kind: .marker([CGPoint(x: 15, y: 30), CGPoint(x: 55, y: 30)]), style: style)],
            cache: PixelateCache()
        ))
        let mixed = pixel(image, atPoint: 30, 30)
        #expect(mixed.r > 60 && mixed.r < 200)    // yellow over blue, partially
        #expect(mixed.b > 60)                     // blue still shows through
    }

    @Test func textIsDrawnUprightAtItsOrigin() throws {
        let style = AnnotationStyle(color: .red, width: .thick)
        let white = CapturedDisplay(
            displayID: 1, frame: display.frame,
            image: TestImages.solidImage(width: 200, height: 160, color: RGBA(r: 255, g: 255, b: 255, a: 255))
        )
        let annotation = Annotation(kind: .text("HI", origin: CGPoint(x: 15, y: 15)), style: style)
        let image = try #require(ExportRenderer.render(display: white, selection: selection, annotations: [annotation], cache: PixelateCache()))

        // Red ink inside the text bounds, none above them.
        let bounds = annotation.bounds
        var inkRows: [Int] = []
        for y in stride(from: bounds.minY, to: min(bounds.maxY, selection.maxY), by: 0.5) {
            for x in stride(from: bounds.minX, to: bounds.maxX, by: 0.5) where pixel(image, atPoint: x, y).isClose(to: .red, tolerance: 80) {
                inkRows.append(Int(y))
                break
            }
        }
        #expect(!inkRows.isEmpty)
        #expect(pixel(image, atPoint: 20, 12) == RGBA(r: 255, g: 255, b: 255, a: 255))
    }

    @Test func pixelateReplacesRegionWithBlocks() throws {
        let image = try render([Annotation(kind: .pixelate(CGRect(x: 20, y: 20, width: 20, height: 20)), style: .default)])
        // Coordinate pixels differ every pixel; pixelated ones repeat within a block.
        #expect(pixel(image, atPoint: 20, 20) == pixel(image, atPoint: 20.5, 20))
        #expect(pixel(image, atPoint: 20, 20) != original(atPoint: 20.5, 20))
        #expect(pixel(image, atPoint: 45, 45) == original(atPoint: 45, 45))   // outside untouched
    }

    @Test func annotationsOutsideSelectionAreClipped() throws {
        let image = try render([Annotation(kind: .rectangle(CGRect(x: 70, y: 60, width: 20, height: 10)), style: .default)])
        #expect(pixel(image, atPoint: 30, 30) == original(atPoint: 30, 30))
        #expect(pixel(image, atPoint: 59.5, 49.5) == original(atPoint: 59.5, 49.5))
    }

    @Test func emptySelectionRendersNothing() {
        #expect(ExportRenderer.render(display: display, selection: .zero, annotations: [], cache: PixelateCache()) == nil)
    }
}
