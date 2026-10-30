import CoreGraphics
import Testing

@testable import QuickSnip

@MainActor
struct AnnotationTests {
    private let style = AnnotationStyle(color: .red, lineWidth: 4)  // 4pt

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

    @Test func textBoundsStartAtTheOriginAndIgnoreStrokeWidth() {
        var thin = make(.text("Hi", origin: CGPoint(x: 5, y: 7)))
        thin.style.lineWidth = 2
        var thick = thin
        thick.style.lineWidth = 8
        #expect(thin.bounds.origin == CGPoint(x: 5, y: 7))
        #expect(thick.bounds == thin.bounds)
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

    @Test func realigningOneLineTextKeepsItInPlace() {
        let text = Annotation(kind: .text("Hello", origin: CGPoint(x: 50, y: 60)), style: .default)
        let right = text.aligned(.right)
        #expect(right.style.alignment == .right)
        #expect(right.bounds == text.bounds)
        #expect(right.kind == .text("Hello", origin: CGPoint(x: text.bounds.maxX, y: 60)))
    }

    @Test func realigningABoxKeepsTheBox() {
        let box = Annotation(kind: .text("Hello", origin: CGPoint(x: 50, y: 60), boxWidth: 100), style: .default)
        #expect(box.aligned(.center).kind == box.kind)
        #expect(box.aligned(.center).style.alignment == .center)
    }

    @Test func movingABoxKeepsItsWidth() {
        let box = Annotation(kind: .text("Hello", origin: CGPoint(x: 50, y: 60), boxWidth: 100), style: .default)
        #expect(box.offsetBy(dx: 5, dy: 10).kind == .text("Hello", origin: CGPoint(x: 55, y: 70), boxWidth: 100))
    }

    @Test func lineWidthPresetsIncreaseAndIncludeTheDefault() {
        #expect(LineWidth.presets == LineWidth.presets.sorted())
        #expect(LineWidth.presets.contains(LineWidth.default))
    }

    @Test func markerIsWiderThanItsLineWidth() {
        let marker = Annotation(kind: .marker([.zero]), style: AnnotationStyle(lineWidth: 3))
        #expect(marker.strokeWidth == 3 * Annotation.markerWidthMultiplier)
    }

    @Test func textBoundsFollowTheFontSize() {
        var style = AnnotationStyle.default
        let small = Annotation(kind: .text("Hello", origin: .zero), style: style).bounds
        style.fontSize = 44
        let large = Annotation(kind: .text("Hello", origin: .zero), style: style).bounds
        #expect(large.height > small.height * 1.8)
        #expect(large.width > small.width * 1.8)
    }

    @Test func textBoundsFollowTheFont() {
        let proportional = Annotation(kind: .text("iiii", origin: .zero), style: .default).bounds
        let monospaced = Annotation(kind: .text("iiii", origin: .zero), style: AnnotationStyle(font: .monospaced)).bounds
        #expect(monospaced.width > proportional.width)
    }

    @Test func colorsAreDistinctAndConvertible() {
        let all = AnnotationColor.allCases
        #expect(Set(all.map { "\($0.components)" }).count == all.count)
        #expect(AnnotationColor.red.cgColor.alpha == 1)
        #expect(AnnotationColor.blue.nsColor.blueComponent == 1)
    }
}
