import CoreGraphics
import Testing
@testable import QuickSnip

struct SizeLabelTests {
    private let bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
    private let label = CGSize(width: 60, height: 20)

    @Test func textShowsPixelDimensions() {
        #expect(SizeLabel.text(for: CGSize(width: 640, height: 480)) == "640 × 480")
    }

    @Test func placedAboveSelection() {
        let origin = SizeLabel.origin(labelSize: label, selection: CGRect(x: 50, y: 100, width: 80, height: 40), bounds: bounds)
        #expect(origin == CGPoint(x: 50, y: 100 - SizeLabel.gap - 20))
    }

    @Test func movesInsideWhenNoRoomAbove() {
        let origin = SizeLabel.origin(labelSize: label, selection: CGRect(x: 50, y: 10, width: 80, height: 40), bounds: bounds)
        #expect(origin == CGPoint(x: 50, y: 10 + SizeLabel.gap))
    }

    @Test func clampedToRightEdge() {
        let origin = SizeLabel.origin(labelSize: label, selection: CGRect(x: 280, y: 100, width: 20, height: 20), bounds: bounds)
        #expect(origin.x == 240)
    }
}
