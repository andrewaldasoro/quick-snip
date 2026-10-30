import CoreGraphics
import Testing

@testable import QuickSnip

struct DropdownLayoutTests {
    private let bounds = CGRect(x: 0, y: 0, width: 1000, height: 700)
    private let anchor = CGRect(x: 300, y: 300, width: 80, height: 28)

    @Test func hangsUnderItsButtonWhenThereIsRoom() {
        let frame = DropdownLayout.frame(size: CGSize(width: 150, height: 200), anchor: anchor, bounds: bounds)
        #expect(frame == CGRect(x: 300, y: 328 + DropdownLayout.gap, width: 150, height: 200))
    }

    @Test func opensAboveWhenOnlyAboveHasRoom() {
        let low = CGRect(x: 300, y: 600, width: 80, height: 28)
        let frame = DropdownLayout.frame(size: CGSize(width: 150, height: 200), anchor: low, bounds: bounds)
        #expect(frame.maxY == 600 - DropdownLayout.gap)
        #expect(frame.height == 200)
    }

    /// Regression: on a short display the list overlapped the style panel it hangs from.
    @Test func shrinksIntoTheRoomierSideWhenNeitherFits() {
        let short = CGRect(x: 0, y: 0, width: 1000, height: 420)
        let middle = CGRect(x: 300, y: 160, width: 80, height: 28)
        let frame = DropdownLayout.frame(size: CGSize(width: 150, height: 300), anchor: middle, bounds: short)

        #expect(frame.minY == 188 + DropdownLayout.gap)  // below has more room
        #expect(frame.maxY == 420 - ToolbarLayout.margin)
        #expect(!frame.intersects(middle))
    }

    @Test func neverShrinksBelowAUsableHeight() {
        let tiny = CGRect(x: 0, y: 0, width: 1000, height: 120)
        let middle = CGRect(x: 300, y: 46, width: 80, height: 28)
        let frame = DropdownLayout.frame(size: CGSize(width: 150, height: 300), anchor: middle, bounds: tiny)
        #expect(frame.height == DropdownLayout.minimumHeight)
        #expect(tiny.contains(frame))
    }

    @Test func staysOnTheDisplaySideways() {
        let edge = CGRect(x: 950, y: 300, width: 40, height: 28)
        let frame = DropdownLayout.frame(size: CGSize(width: 150, height: 100), anchor: edge, bounds: bounds)
        #expect(frame.maxX == 1000 - ToolbarLayout.margin)
    }
}
