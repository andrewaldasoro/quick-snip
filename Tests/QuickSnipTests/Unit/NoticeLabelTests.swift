import CoreGraphics
import Testing

@testable import QuickSnip

struct NoticeLabelTests {
    private let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
    private let text = CGSize(width: 100, height: 16)

    @Test func centeredOnTheSelection() {
        let frame = NoticeLabel.frame(textSize: text, selection: CGRect(x: 100, y: 100, width: 400, height: 200), bounds: bounds)
        #expect(frame.midX == 300)
        #expect(frame.midY == 200)
        #expect(frame.width == text.width + NoticeLabel.padding.width * 2)
    }

    @Test func keptOnScreenForASelectionAtTheEdge() {
        let frame = NoticeLabel.frame(textSize: text, selection: CGRect(x: 780, y: 590, width: 20, height: 10), bounds: bounds)
        #expect(bounds.contains(frame))
    }
}
