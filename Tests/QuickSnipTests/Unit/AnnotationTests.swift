import CoreGraphics
import Testing

@testable import QuickSnip

@MainActor
struct AnnotationTests {
    private let style = AnnotationStyle(color: .red, width: .medium)  // 4pt

    private func make(_ kind: AnnotationKind) -> Annotation {
        Annotation(kind: kind, style: style)
    }

    // MARK: Hit testing

    @Test func rectangleHitsOnOutlineOnly() {
        let a = make(.rectangle(CGRect(x: 10, y: 10, width: 100, height: 60)))
        #expect(a.hitTest(CGPoint(x: 10, y: 40)))  // left edge
        #expect(a.hitTest(CGPoint(x: 60, y: 72)))  // just outside bottom edge, within reach
        #expect(!a.hitTest(CGPoint(x: 60, y: 40)))  // middle
        #expect(!a.hitTest(CGPoint(x: 200, y: 40)))
    }

    @Test func smallRectangleHitsInside() {
        let a = make(.rectangle(CGRect(x: 10, y: 10, width: 6, height: 6)))
        #expect(a.hitTest(CGPoint(x: 13, y: 13)))
    }

    @Test func pixelateHitsAnywhereInside() {
        let a = make(.pixelate(CGRect(x: 10, y: 10, width: 100, height: 60)))
        #expect(a.hitTest(CGPoint(x: 60, y: 40)))
        #expect(!a.hitTest(CGPoint(x: 200, y: 40)))
    }

    @Test(arguments: [AnnotationKind.line(from: .zero, to: CGPoint(x: 100, y: 0)), .arrow(from: .zero, to: CGPoint(x: 100, y: 0))])
    func lineAndArrowHitNearSegment(kind: AnnotationKind) {
        let a = make(kind)
        #expect(a.hitTest(CGPoint(x: 50, y: 7)))  // 6 tolerance + 2 half-width
        #expect(!a.hitTest(CGPoint(x: 50, y: 9)))
    }

    @Test func penHitsNearPath() {
        let a = make(.pen([CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 50)]))
        #expect(a.hitTest(CGPoint(x: 53, y: 25)))
        #expect(!a.hitTest(CGPoint(x: 25, y: 25)))
    }

    @Test func markerReachesFurtherThanPen() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)]
        let probe = CGPoint(x: 50, y: 12)
        #expect(!make(.pen(points)).hitTest(probe))
        #expect(make(.marker(points)).hitTest(probe))  // 16pt wide marker
    }

    @Test func textHitsWithinItsBounds() {
        let a = make(.text("Hello", origin: CGPoint(x: 20, y: 20)))
        #expect(a.hitTest(CGPoint(x: 25, y: 30)))
        #expect(!a.hitTest(CGPoint(x: 5, y: 5)))
    }

    // MARK: Geometry

    @Test func markerStrokeIsWider() {
        #expect(make(.pen([.zero])).strokeWidth == 4)
        #expect(make(.marker([.zero])).strokeWidth == 4 * Annotation.markerWidthMultiplier)
    }

    @Test func rectangleBoundsIncludeStroke() {
        #expect(make(.rectangle(CGRect(x: 10, y: 10, width: 20, height: 20))).bounds == CGRect(x: 8, y: 8, width: 24, height: 24))
    }

    @Test func textBoundsGrowWithFontSize() {
        var small = make(.text("Hi", origin: .zero))
        small.style.width = .thin
        var large = small
        large.style.width = .thick
        #expect(large.bounds.height > small.bounds.height)
        #expect(large.bounds.width > small.bounds.width)
        #expect(small.bounds.origin == .zero)
    }

    @Test(arguments: [
        AnnotationKind.rectangle(CGRect(x: 1, y: 2, width: 3, height: 4)),
        .pixelate(CGRect(x: 1, y: 2, width: 3, height: 4)),
        .line(from: CGPoint(x: 1, y: 2), to: CGPoint(x: 3, y: 4)),
        .arrow(from: CGPoint(x: 1, y: 2), to: CGPoint(x: 3, y: 4)),
        .pen([CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)]),
        .marker([CGPoint(x: 1, y: 2)]),
        .text("x", origin: CGPoint(x: 1, y: 2)),
    ])
    func offsetMovesEveryKindAndKeepsIdentity(kind: AnnotationKind) {
        let original = make(kind)
        let moved = original.offsetBy(dx: 10, dy: 20)
        #expect(moved.id == original.id)
        #expect(moved.style == original.style)
        #expect(moved.bounds.origin.x == original.bounds.origin.x + 10)
        #expect(moved.bounds.origin.y == original.bounds.origin.y + 20)
    }

    @Test func namesForUndoMenu() {
        #expect(make(.arrow(from: .zero, to: .zero)).name == "Arrow")
        #expect(make(.pixelate(.zero)).name == "Pixelate")
    }

    // MARK: Style

    @Test func strokeWidthsAndFontSizesIncrease() {
        let widths = StrokeWidth.allCases
        #expect(widths.map(\.lineWidth) == widths.map(\.lineWidth).sorted())
        #expect(widths.map(\.fontSize) == widths.map(\.fontSize).sorted())
    }

    @Test func colorsAreDistinctAndConvertible() {
        let all = AnnotationColor.allCases
        #expect(Set(all.map { "\($0.components)" }).count == all.count)
        #expect(AnnotationColor.red.cgColor.alpha == 1)
        #expect(AnnotationColor.blue.nsColor.blueComponent == 1)
    }
}
