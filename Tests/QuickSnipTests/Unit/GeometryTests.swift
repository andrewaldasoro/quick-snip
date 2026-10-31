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

    // MARK: Constrained drags

    private let bounds = CGRect(x: 0, y: 0, width: 200, height: 100)
    private let shift = DrawModifiers(isConstrained: true)
    private let option = DrawModifiers(isFromCenter: true)

    @Test(
        arguments: [
            (CGPoint(x: 80, y: 70), CGRect(x: 50, y: 50, width: 30, height: 30)),  // wider drag down-right
            (CGPoint(x: 40, y: 70), CGRect(x: 30, y: 50, width: 20, height: 20)),  // taller drag down-left
            (CGPoint(x: 20, y: 40), CGRect(x: 20, y: 20, width: 30, height: 30)),  // up-left
            (CGPoint(x: 60, y: 20), CGRect(x: 50, y: 20, width: 30, height: 30)),  // up-right
        ] as [(CGPoint, CGRect)])
    func shiftMakesASquareOnTheLongerAxisInTheDragDirection(end: CGPoint, expected: CGRect) {
        #expect(Geometry.shapeRect(from: CGPoint(x: 50, y: 50), to: end, modifiers: shift, within: nil) == expected)
    }

    @Test func plainDragIsTheRectBetweenThePoints() {
        let rect = Geometry.shapeRect(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 80, y: 60), modifiers: .none, within: bounds)
        #expect(rect == CGRect(x: 50, y: 50, width: 30, height: 10))
    }

    @Test func optionGrowsFromTheStartPoint() {
        let rect = Geometry.shapeRect(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 80, y: 60), modifiers: option, within: bounds)
        #expect(rect == CGRect(x: 20, y: 40, width: 60, height: 20))
    }

    @Test func shiftAndOptionMakeACenteredSquare() {
        let both = DrawModifiers(isConstrained: true, isFromCenter: true)
        let rect = Geometry.shapeRect(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 70, y: 55), modifiers: both, within: bounds)
        #expect(rect == CGRect(x: 30, y: 30, width: 40, height: 40))
    }

    @Test func plainDragIsClampedPerAxis() {
        let rect = Geometry.shapeRect(from: CGPoint(x: 150, y: 50), to: CGPoint(x: 250, y: 70), modifiers: .none, within: bounds)
        #expect(rect == CGRect(x: 150, y: 50, width: 50, height: 20))
    }

    /// Clamping only the end point would turn the square into a rectangle.
    @Test func squareShrinksToFitAndStaysSquare() {
        let rect = Geometry.shapeRect(from: CGPoint(x: 150, y: 50), to: CGPoint(x: 230, y: 60), modifiers: shift, within: bounds)
        #expect(rect == CGRect(x: 150, y: 50, width: 50, height: 50))
    }

    @Test func centeredShapeFitsTheRoomOnBothSides() {
        let rect = Geometry.shapeRect(from: CGPoint(x: 20, y: 50), to: CGPoint(x: 60, y: 60), modifiers: option, within: bounds)
        #expect(rect == CGRect(x: 0, y: 40, width: 40, height: 20))
    }

    @Test func proportionalRectKeepsTheAspectAndFlipsPastTheAnchor() {
        let aspect = CGSize(width: 40, height: 20)
        #expect(
            Geometry.proportionalRect(from: .zero, to: CGPoint(x: 10, y: 30), aspect: aspect) == CGRect(x: 0, y: 0, width: 60, height: 30))
        #expect(
            Geometry.proportionalRect(from: .zero, to: CGPoint(x: -80, y: 5), aspect: aspect) == CGRect(x: -80, y: 0, width: 80, height: 40)
        )
    }

    @Test(
        arguments: [
            (CGPoint(x: 50, y: 4), CGPoint(x: 50, y: 0)),  // nearly flat → horizontal
            (CGPoint(x: -3, y: 40), CGPoint(x: 0, y: 40)),  // nearly vertical
            (CGPoint(x: 30, y: 34), CGPoint(x: 32, y: 32)),  // near 45° down-right
            (CGPoint(x: -30, y: -34), CGPoint(x: -32, y: -32)),  // up-left
            (CGPoint(x: -40, y: 2), CGPoint(x: -40, y: 0)),  // leftward
            (CGPoint(x: 20, y: -22), CGPoint(x: 21, y: -21)),  // up-right
        ] as [(CGPoint, CGPoint)])
    func snapsToTheNearest45Degrees(end: CGPoint, expected: CGPoint) {
        #expect(Geometry.snapped(end, from: .zero) == expected)
    }

    @Test func clampAlongALineKeepsItsAngle() {
        let end = Geometry.clamp(CGPoint(x: 250, y: 150), from: CGPoint(x: 150, y: 50), to: bounds)
        #expect(end == CGPoint(x: 200, y: 100))
        #expect(Geometry.clamp(CGPoint(x: 100, y: 200), from: CGPoint(x: 100, y: 50), to: bounds) == CGPoint(x: 100, y: 100))
    }

    @Test func ellipseContainment() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 50)
        #expect(Geometry.ellipse(rect, contains: CGPoint(x: 50, y: 25)))
        #expect(Geometry.ellipse(rect, contains: CGPoint(x: 0, y: 25)))
        #expect(!Geometry.ellipse(rect, contains: CGPoint(x: 5, y: 5)))
        #expect(!Geometry.ellipse(.zero, contains: .zero))
    }
}
