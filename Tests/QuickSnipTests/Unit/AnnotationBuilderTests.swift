import CoreGraphics
import Testing

@testable import QuickSnip

struct AnnotationBuilderTests {
    private func build(_ tool: AnnotationTool, _ points: [CGPoint]) -> AnnotationBuilder {
        var builder = AnnotationBuilder(tool: tool, style: .default, start: points[0])
        for point in points.dropFirst() { builder.add(point) }
        return builder
    }

    @Test func rectangleFromDragIsNormalized() {
        let b = build(.shape, [CGPoint(x: 50, y: 40), CGPoint(x: 30, y: 30), CGPoint(x: 10, y: 20)])
        #expect(b.finish()?.kind == .shape(CGRect(x: 10, y: 20, width: 40, height: 20)))
    }

    @Test func pixelateFromDrag() {
        let b = build(.pixelate, [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)])
        #expect(b.finish()?.kind == .pixelate(CGRect(x: 0, y: 0, width: 10, height: 10)))
    }

    @Test func arrowUsesStartAndLastPoint() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 50), CGPoint(x: 20, y: 10)]
        #expect(build(.arrow, points).finish()?.kind == .arrow(from: .zero, to: CGPoint(x: 20, y: 10)))
    }

    @Test func penAndMarkerKeepEveryDistinctPoint() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 0)]
        let expected = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 0)]
        #expect(build(.pen, points).finish()?.kind == .pen(expected))
        #expect(build(.marker, points).finish()?.kind == .marker(expected))
    }

    @Test func penClickMakesADot() {
        #expect(build(.pen, [CGPoint(x: 5, y: 5)]).finish()?.kind == .pen([CGPoint(x: 5, y: 5)]))
    }

    @Test(arguments: [AnnotationTool.shape, .pixelate, .arrow])
    func strayClickIsDiscarded(tool: AnnotationTool) {
        #expect(build(tool, [CGPoint(x: 5, y: 5), CGPoint(x: 6, y: 6)]).finish() == nil)
    }

    @Test func thinRectangleIsDiscarded() {
        #expect(build(.shape, [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 1)]).finish() == nil)
    }

    @Test func textToolBuildsNothing() {
        #expect(build(.text, [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 50)]).annotation == nil)
    }

    @Test func previewKeepsTheSameIdentityAsTheResult() {
        var builder = AnnotationBuilder(tool: .shape, style: .default, start: .zero)
        builder.add(CGPoint(x: 10, y: 10))
        let preview = builder.annotation
        builder.add(CGPoint(x: 20, y: 20))
        #expect(preview?.id == builder.finish()?.id)
    }

    @Test func usesStyleFromStart() {
        let style = AnnotationStyle(color: .blue, lineWidth: 8)
        var builder = AnnotationBuilder(tool: .arrow, style: style, start: .zero)
        builder.add(CGPoint(x: 30, y: 0))
        #expect(builder.finish()?.style == style)
    }

    // MARK: Modifiers

    private func build(_ tool: AnnotationTool, to end: CGPoint, modifiers: DrawModifiers, bounds: CGRect? = nil) -> Annotation? {
        var builder = AnnotationBuilder(tool: tool, style: .default, start: CGPoint(x: 50, y: 50), bounds: bounds)
        builder.modifiers = modifiers
        builder.add(end)
        return builder.finish()
    }

    @Test func shiftDrawsASquare() {
        let shape = build(.shape, to: CGPoint(x: 90, y: 60), modifiers: DrawModifiers(isConstrained: true))
        #expect(shape?.kind == .shape(CGRect(x: 50, y: 50, width: 40, height: 40)))
    }

    @Test func optionDrawsFromTheCenter() {
        let shape = build(.shape, to: CGPoint(x: 90, y: 60), modifiers: DrawModifiers(isFromCenter: true))
        #expect(shape?.kind == .shape(CGRect(x: 10, y: 40, width: 80, height: 20)))
    }

    @Test func squareStaysInsideTheSelection() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 80)
        let shape = build(.shape, to: CGPoint(x: 120, y: 60), modifiers: DrawModifiers(isConstrained: true), bounds: bounds)
        #expect(shape?.kind == .shape(CGRect(x: 50, y: 50, width: 30, height: 30)))
    }

    @Test func shiftSnapsAnArrowTo45Degrees() {
        let arrow = build(.arrow, to: CGPoint(x: 90, y: 54), modifiers: DrawModifiers(isConstrained: true))
        #expect(arrow?.kind == .arrow(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 90, y: 50)))
    }

    @Test func snappedArrowIsShortenedAlongItsLineToFit() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 70)
        let arrow = build(.arrow, to: CGPoint(x: 90, y: 92), modifiers: DrawModifiers(isConstrained: true), bounds: bounds)
        #expect(arrow?.kind == .arrow(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 70, y: 70)))
    }

    @Test func pixelateIgnoresModifiers() {
        let pixelate = build(.pixelate, to: CGPoint(x: 90, y: 60), modifiers: DrawModifiers(isConstrained: true, isFromCenter: true))
        #expect(pixelate?.kind == .pixelate(CGRect(x: 50, y: 50, width: 40, height: 10)))
    }

    @Test func releasingShiftMidDragRestoresTheFreeShape() {
        var builder = AnnotationBuilder(tool: .shape, style: .default, start: .zero)
        builder.modifiers = DrawModifiers(isConstrained: true)
        builder.add(CGPoint(x: 40, y: 10))
        builder.modifiers = .none
        #expect(builder.annotation?.kind == .shape(CGRect(x: 0, y: 0, width: 40, height: 10)))
    }

    @Test func penPointsStayInsideTheSelection() {
        var builder = AnnotationBuilder(
            tool: .pen, style: .default, start: CGPoint(x: 5, y: 5), bounds: CGRect(x: 0, y: 0, width: 10, height: 10))
        builder.add(CGPoint(x: 30, y: -4))
        #expect(builder.finish()?.kind == .pen([CGPoint(x: 5, y: 5), CGPoint(x: 10, y: 0)]))
    }
}
