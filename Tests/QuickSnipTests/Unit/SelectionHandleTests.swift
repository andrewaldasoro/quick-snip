import CoreGraphics
import Testing

@testable import QuickSnip

struct SelectionHandleTests {
    private let rect = CGRect(x: 50, y: 20, width: 100, height: 60)

    @Test(arguments: [
        (SelectionHandle.topLeft, CGPoint(x: 40, y: 10), CGRect(x: 40, y: 10, width: 110, height: 70)),
        (.top, CGPoint(x: 999, y: 10), CGRect(x: 50, y: 10, width: 100, height: 70)),
        (.topRight, CGPoint(x: 160, y: 10), CGRect(x: 50, y: 10, width: 110, height: 70)),
        (.right, CGPoint(x: 170, y: 999), CGRect(x: 50, y: 20, width: 120, height: 60)),
        (.bottomRight, CGPoint(x: 160, y: 90), CGRect(x: 50, y: 20, width: 110, height: 70)),
        (.bottom, CGPoint(x: -5, y: 95), CGRect(x: 50, y: 20, width: 100, height: 75)),
        (.bottomLeft, CGPoint(x: 40, y: 90), CGRect(x: 40, y: 20, width: 110, height: 70)),
        (.left, CGPoint(x: 30, y: -5), CGRect(x: 30, y: 20, width: 120, height: 60)),
    ])
    func resizeMovesOnlyTheHandlesEdges(handle: SelectionHandle, to point: CGPoint, expected: CGRect) {
        #expect(handle.resize(rect, to: point) == expected)
    }

    @Test func resizePastTheOppositeEdgeFlips() {
        #expect(SelectionHandle.left.resize(rect, to: CGPoint(x: 180, y: 0)) == CGRect(x: 150, y: 20, width: 30, height: 60))
    }
}
