import CoreGraphics
import Testing

@testable import QuickSnip

struct ToolbarLayoutTests {
    private let bounds = CGRect(x: 0, y: 0, width: 1000, height: 600)
    private let size = CGSize(width: 300, height: 30)
    private let margin = ToolbarLayout.margin

    @Test func belowSelectionRightAligned() {
        let frame = ToolbarLayout.frame(size: size, selection: CGRect(x: 400, y: 100, width: 400, height: 200), bounds: bounds)
        #expect(frame == CGRect(x: 500, y: 300 + margin, width: 300, height: 30))
    }

    @Test func aboveWhenNoRoomBelow() {
        let frame = ToolbarLayout.frame(size: size, selection: CGRect(x: 400, y: 300, width: 400, height: 290), bounds: bounds)
        #expect(frame.maxY == 300 - margin)
    }

    @Test func insideWhenSelectionFillsTheScreen() {
        let frame = ToolbarLayout.frame(size: size, selection: bounds, bounds: bounds)
        #expect(frame.maxY == bounds.maxY - margin)
        #expect(bounds.contains(frame))
    }

    @Test func clampedToLeftEdgeForNarrowSelections() {
        let frame = ToolbarLayout.frame(size: size, selection: CGRect(x: 10, y: 100, width: 50, height: 50), bounds: bounds)
        #expect(frame.minX == margin)
    }

    @Test func clampedToRightEdge() {
        let frame = ToolbarLayout.frame(size: size, selection: CGRect(x: 900, y: 100, width: 100, height: 50), bounds: bounds)
        #expect(frame.maxX == bounds.maxX - margin)
    }
}
