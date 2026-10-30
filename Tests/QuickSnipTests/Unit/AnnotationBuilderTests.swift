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
        let b = build(.rectangle, [CGPoint(x: 50, y: 40), CGPoint(x: 30, y: 30), CGPoint(x: 10, y: 20)])
        #expect(b.finish()?.kind == .rectangle(CGRect(x: 10, y: 20, width: 40, height: 20)))
    }

    @Test func pixelateFromDrag() {
        let b = build(.pixelate, [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)])
        #expect(b.finish()?.kind == .pixelate(CGRect(x: 0, y: 0, width: 10, height: 10)))
    }

    @Test func lineAndArrowUseStartAndLastPoint() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 50), CGPoint(x: 20, y: 10)]
        #expect(build(.line, points).finish()?.kind == .line(from: .zero, to: CGPoint(x: 20, y: 10)))
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

    @Test(arguments: [AnnotationTool.rectangle, .pixelate, .line, .arrow])
    func strayClickIsDiscarded(tool: AnnotationTool) {
        #expect(build(tool, [CGPoint(x: 5, y: 5), CGPoint(x: 6, y: 6)]).finish() == nil)
    }

    @Test func thinRectangleIsDiscarded() {
        #expect(build(.rectangle, [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 1)]).finish() == nil)
    }

    @Test func textToolBuildsNothing() {
        #expect(build(.text, [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 50)]).annotation == nil)
    }

    @Test func previewKeepsTheSameIdentityAsTheResult() {
        var builder = AnnotationBuilder(tool: .rectangle, style: .default, start: .zero)
        builder.add(CGPoint(x: 10, y: 10))
        let preview = builder.annotation
        builder.add(CGPoint(x: 20, y: 20))
        #expect(preview?.id == builder.finish()?.id)
    }

    @Test func usesStyleFromStart() {
        let style = AnnotationStyle(color: .blue, lineWidth: 8)
        var builder = AnnotationBuilder(tool: .line, style: style, start: .zero)
        builder.add(CGPoint(x: 30, y: 0))
        #expect(builder.finish()?.style == style)
    }
}
