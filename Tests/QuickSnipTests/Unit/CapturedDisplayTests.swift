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
}
