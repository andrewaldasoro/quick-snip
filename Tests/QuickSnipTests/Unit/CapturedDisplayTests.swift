import CoreGraphics
import Testing

@testable import QuickSnip

struct CapturedDisplayTests {
    @Test func localBoundsAreZeroOriginPoints() {
        let display = TestImages.display(id: 3, frame: CGRect(x: -1440, y: 200, width: 1440, height: 900), scale: 1)
        #expect(display.localBounds == CGRect(x: 0, y: 0, width: 1440, height: 900))
    }

    @Test func pixelSizeComesFromImage() {
        let display = TestImages.display(id: 3, frame: CGRect(x: 0, y: 0, width: 50, height: 40), scale: 2)
        #expect(display.pixelSize == CGSize(width: 100, height: 80))
    }

    private let red = RGBA(r: 255, g: 0, b: 0, a: 255)

    private func window(_ id: CGWindowID, _ frame: CGRect, visible: CGRect? = nil) -> SnapWindow {
        SnapWindow(id: id, frame: frame, visibleFrame: visible ?? frame)
    }

    /// 100 × 80 points at 2×, pixels encoding their own coordinates.
    private func display(windows: [SnapWindow]) -> CapturedDisplay {
        let base = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)
        return CapturedDisplay(displayID: 1, frame: base.frame, image: base.image, windows: windows)
    }

    @Test func windowAtAPointIsTheFrontmost() {
        let front = window(1, CGRect(x: 20, y: 20, width: 30, height: 30))
        let back = window(2, CGRect(x: 0, y: 0, width: 100, height: 80))
        let display = display(windows: [front, back])

        #expect(display.window(at: CGPoint(x: 25, y: 25)) == front)
        #expect(display.window(at: CGPoint(x: 5, y: 5)) == back)
        #expect(display.window(at: CGPoint(x: 150, y: 5)) == nil)
    }

    @Test func windowAtAPointUsesThePartOnThisDisplay() {
        let spanning = window(1, CGRect(x: 80, y: 0, width: 60, height: 40), visible: CGRect(x: 80, y: 0, width: 20, height: 40))
        #expect(display(windows: [spanning]).window(at: CGPoint(x: 90, y: 10)) == spanning)
    }

    @Test func aWindowIsCoveredWhenOneInFrontOverlapsIt() {
        let front = window(1, CGRect(x: 20, y: 20, width: 30, height: 30))
        let back = window(2, CGRect(x: 0, y: 0, width: 40, height: 40))
        let apart = window(3, CGRect(x: 60, y: 50, width: 30, height: 20))
        let display = display(windows: [front, back, apart])

        #expect(display.isCovered(back))
        #expect(!display.isCovered(front))
        #expect(!display.isCovered(apart))
        #expect(!display.isCovered(window(9, .zero)))
    }

    @Test func windowPixelSizeUsesTheDisplayScaleAndTheFullFrame() {
        let spanning = window(1, CGRect(x: 80, y: 0, width: 60, height: 40), visible: CGRect(x: 80, y: 0, width: 20, height: 40))
        #expect(display(windows: [spanning]).pixelSize(of: spanning) == CGSize(width: 120, height: 80))
    }

    @Test func bringingAWindowToFrontPaintsItsImageOverTheCapture() throws {
        let back = window(2, CGRect(x: 30, y: 20, width: 40, height: 30))
        let front = window(1, CGRect(x: 0, y: 0, width: 50, height: 40))
        let windowImage = TestImages.solidImage(width: 80, height: 60, color: red)

        let composed = try #require(display(windows: [front, back]).bringingToFront(back, image: windowImage))

        // The window covers pixels 60..<140 × 40..<100 (top-left origin).
        #expect(TestImages.pixel(composed.image, x: 60, y: 40) == red)
        #expect(TestImages.pixel(composed.image, x: 139, y: 99) == red)
        #expect(TestImages.pixel(composed.image, x: 59, y: 40) == RGBA(r: 59, g: 40, b: 0, a: 255))
        #expect(TestImages.pixel(composed.image, x: 60, y: 100) == RGBA(r: 60, g: 100, b: 0, a: 255))
        #expect(composed.windows == [back, front])
        #expect(composed.pixelSize == CGSize(width: 200, height: 160))
    }

    @Test func aWindowPastTheEdgeIsPaintedOnlyWhereItsOnTheDisplay() throws {
        let spanning = window(1, CGRect(x: 80, y: 60, width: 40, height: 40), visible: CGRect(x: 80, y: 60, width: 20, height: 20))
        let windowImage = TestImages.solidImage(width: 80, height: 80, color: red)

        let composed = try #require(display(windows: [spanning]).bringingToFront(spanning, image: windowImage))

        #expect(TestImages.pixel(composed.image, x: 199, y: 159) == red)
        #expect(TestImages.pixel(composed.image, x: 159, y: 119) == RGBA(r: 159, g: 119, b: 0, a: 255))
    }
}
