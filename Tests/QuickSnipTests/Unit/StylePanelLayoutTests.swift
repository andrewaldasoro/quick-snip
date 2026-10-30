import CoreGraphics
import Testing

@testable import QuickSnip

struct StylePanelLayoutTests {
    private let bounds = CGRect(x: 0, y: 0, width: 1000, height: 700)
    private let size = CGSize(width: 120, height: 40)

    @Test func sitsBesideTheToolbarWhenTheSelectionIsWideEnough() {
        let selection = CGRect(x: 100, y: 100, width: 600, height: 300)
        let toolbar = CGRect(x: 300, y: 408, width: 400, height: 70)

        let frame = StylePanelLayout.frame(size: size, toolbar: toolbar, selection: selection, bounds: bounds)

        #expect(frame == CGRect(x: 300 - StylePanelLayout.gap - 120, y: 408, width: 120, height: 40))
    }

    @Test func stacksBelowTheToolbarWhenTheSelectionIsNarrow() {
        let selection = CGRect(x: 400, y: 100, width: 300, height: 300)
        let toolbar = CGRect(x: 300, y: 408, width: 400, height: 70)

        let frame = StylePanelLayout.frame(size: size, toolbar: toolbar, selection: selection, bounds: bounds)

        #expect(frame == CGRect(x: 700 - 120, y: 478 + StylePanelLayout.gap, width: 120, height: 40))
    }

    @Test func stacksAboveAToolbarThatIsAboveTheSelection() {
        let selection = CGRect(x: 400, y: 500, width: 300, height: 150)
        let toolbar = CGRect(x: 300, y: 422, width: 400, height: 70)

        let frame = StylePanelLayout.frame(size: size, toolbar: toolbar, selection: selection, bounds: bounds)

        #expect(frame.maxY == 422 - StylePanelLayout.gap)
        #expect(frame.maxX == 700)
    }

    @Test func goesAboveWhenThereIsNoRoomBelow() {
        let selection = CGRect(x: 400, y: 100, width: 300, height: 500)
        let toolbar = CGRect(x: 300, y: 610, width: 400, height: 70)

        let frame = StylePanelLayout.frame(size: size, toolbar: toolbar, selection: selection, bounds: bounds)

        #expect(frame.maxY == 610 - StylePanelLayout.gap)
    }

    @Test func doesntGoBesideOffTheDisplay() {
        let selection = CGRect(x: 0, y: 100, width: 900, height: 300)
        let toolbar = CGRect(x: 20, y: 408, width: 400, height: 70)

        let frame = StylePanelLayout.frame(size: size, toolbar: toolbar, selection: selection, bounds: bounds)

        #expect(frame.minY == 478 + StylePanelLayout.gap)
        #expect(bounds.contains(frame))
    }

    @Test func staysOnTheDisplayWhenNothingFits() {
        let tiny = CGRect(x: 0, y: 0, width: 300, height: 100)
        let frame = StylePanelLayout.frame(
            size: size, toolbar: CGRect(x: 0, y: 8, width: 300, height: 84), selection: CGRect(x: 0, y: 0, width: 300, height: 100),
            bounds: tiny)
        #expect(frame.minX >= ToolbarLayout.margin)
        #expect(frame.maxY <= 100 - ToolbarLayout.margin)
    }
}
