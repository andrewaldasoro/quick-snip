import CoreGraphics
import Testing

@testable import QuickSnip

struct GeometryTests {
    @Test func rectFromPointsIsNormalized() {
        #expect(Geometry.rect(from: CGPoint(x: 30, y: 40), to: CGPoint(x: 10, y: 5)) == CGRect(x: 10, y: 5, width: 20, height: 35))
    }

    @Test func boundingRectOfPoints() {
        let points = [CGPoint(x: 5, y: 9), CGPoint(x: -2, y: 4), CGPoint(x: 8, y: 1)]
        #expect(Geometry.boundingRect(of: points) == CGRect(x: -2, y: 1, width: 10, height: 8))
        #expect(Geometry.boundingRect(of: []).isNull)
    }

    @Test(
        arguments: [
            (CGPoint(x: 5, y: 3), CGFloat(3)),  // above the middle
            (CGPoint(x: -4, y: 0), 4),  // beyond the start
            (CGPoint(x: 13, y: 4), 5),  // beyond the end (3-4-5)
        ] as [(CGPoint, CGFloat)])
    func distanceToSegment(point: CGPoint, expected: CGFloat) {
        #expect(Geometry.distance(from: point, toSegment: CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)) == expected)
    }

    @Test func distanceToDegenerateSegmentIsPointDistance() {
        #expect(Geometry.distance(from: CGPoint(x: 3, y: 4), toSegment: .zero, .zero) == 5)
    }

    @Test func distanceToPolylineUsesNearestSegment() {
        let path = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10)]
        #expect(Geometry.distance(from: CGPoint(x: 12, y: 5), toPolyline: path) == 2)
        #expect(Geometry.distance(from: CGPoint(x: 3, y: 4), toPolyline: [.zero]) == 5)
        #expect(Geometry.distance(from: .zero, toPolyline: []) == .infinity)
    }
}
