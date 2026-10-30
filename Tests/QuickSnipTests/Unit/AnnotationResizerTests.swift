import CoreGraphics
import Testing

@testable import QuickSnip

@MainActor
struct AnnotationResizerTests {
    private let rect = CGRect(x: 50, y: 20, width: 100, height: 60)

    private func annotation(_ kind: AnnotationKind) -> Annotation {
        Annotation(kind: kind, style: .default)
    }

    // MARK: Handles

    @Test func rectanglesAndPixelateHaveAllEightFrameHandles() {
        for kind in [AnnotationKind.rectangle(rect), .pixelate(rect)] {
            let handles = AnnotationResizer.handles(for: annotation(kind))
            #expect(handles.map(\.handle) == SelectionHandle.allCases.map { .frame($0) })
            #expect(handles.first?.point == CGPoint(x: 50, y: 20))
        }
    }

    @Test func linesAndArrowsHaveOneHandlePerEnd() {
        let line = annotation(.line(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 90, y: 40)))
        let handles = AnnotationResizer.handles(for: line)
        #expect(handles.map(\.handle) == [.start, .end])
        #expect(handles.map(\.point) == [CGPoint(x: 10, y: 10), CGPoint(x: 90, y: 40)])
    }

    @Test func freehandStrokesHaveCornerHandlesOnTheirPoints() {
        let pen = annotation(.pen([CGPoint(x: 10, y: 50), CGPoint(x: 40, y: 10), CGPoint(x: 70, y: 30)]))
        let handles = AnnotationResizer.handles(for: pen)
        #expect(handles.map(\.handle) == [.frame(.topLeft), .frame(.topRight), .frame(.bottomRight), .frame(.bottomLeft)])
        #expect(handles.first?.point == CGPoint(x: 10, y: 10))
    }

    @Test func textHasCornerHandlesOnItsBox() {
        let text = annotation(.text("Hi", origin: CGPoint(x: 10, y: 20)))
        let handles = AnnotationResizer.handles(for: text)
        #expect(handles.map(\.handle) == [.frame(.topLeft), .frame(.topRight), .frame(.bottomRight), .frame(.bottomLeft)])
        #expect(handles.first?.point == CGPoint(x: 10, y: 20))
        #expect(handles[2].point == CGPoint(x: text.bounds.maxX, y: text.bounds.maxY))
    }

    // MARK: Hit testing

    @Test func hitTestFindsTheHandleWithinTolerance() {
        let rectangle = annotation(.rectangle(rect))
        #expect(AnnotationResizer.hitTest(CGPoint(x: 154, y: 84), on: rectangle) == .frame(.bottomRight))
        #expect(AnnotationResizer.hitTest(CGPoint(x: 100, y: 22), on: rectangle) == .frame(.top))
        #expect(AnnotationResizer.hitTest(CGPoint(x: 100, y: 50), on: rectangle) == nil)
    }

    @Test func cornersWinOverEdgesOnTinyShapes() {
        let tiny = annotation(.rectangle(CGRect(x: 50, y: 50, width: 4, height: 4)))
        #expect(AnnotationResizer.hitTest(CGPoint(x: 51, y: 51), on: tiny) == .frame(.topLeft))
    }

    // MARK: Resizing

    @Test(arguments: [
        (SelectionHandle.topLeft, CGPoint(x: 40, y: 10), CGRect(x: 40, y: 10, width: 110, height: 70)),
        (.right, CGPoint(x: 170, y: 999), CGRect(x: 50, y: 20, width: 120, height: 60)),
        (.bottom, CGPoint(x: 0, y: 100), CGRect(x: 50, y: 20, width: 100, height: 80)),
    ])
    func rectangleResizesFromItsHandle(handle: SelectionHandle, to point: CGPoint, expected: CGRect) {
        let resized = AnnotationResizer.resized(annotation(.rectangle(rect)), dragging: .frame(handle), to: point)
        #expect(resized?.kind == .rectangle(expected))
    }

    @Test func pixelateResizesLikeARectangle() {
        let resized = AnnotationResizer.resized(annotation(.pixelate(rect)), dragging: .frame(.bottomRight), to: CGPoint(x: 200, y: 100))
        #expect(resized?.kind == .pixelate(CGRect(x: 50, y: 20, width: 150, height: 80)))
    }

    @Test func resizeKeepsIDAndStyle() {
        let original = Annotation(kind: .rectangle(rect), style: AnnotationStyle(color: .blue, width: .thick))
        let resized = AnnotationResizer.resized(original, dragging: .frame(.right), to: CGPoint(x: 200, y: 50))
        #expect(resized?.id == original.id)
        #expect(resized?.style == original.style)
    }

    @Test func draggingALineEndMovesOnlyThatEnd() {
        let from = CGPoint(x: 10, y: 10)
        let to = CGPoint(x: 90, y: 40)
        let line = annotation(.line(from: from, to: to))
        let arrow = annotation(.arrow(from: from, to: to))

        #expect(AnnotationResizer.resized(line, dragging: .start, to: CGPoint(x: 0, y: 0))?.kind == .line(from: .zero, to: to))
        #expect(
            AnnotationResizer.resized(arrow, dragging: .end, to: CGPoint(x: 120, y: 60))?.kind
                == .arrow(from: from, to: CGPoint(x: 120, y: 60)))
    }

    @Test func penPointsScaleIntoTheNewBox() {
        let pen = annotation(.pen([CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 20), CGPoint(x: 50, y: 50)]))
        let resized = AnnotationResizer.resized(pen, dragging: .frame(.bottomRight), to: CGPoint(x: 90, y: 90))
        #expect(resized?.kind == .pen([CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 30), CGPoint(x: 90, y: 90)]))
    }

    @Test func aStraightMarkerStrokeOnlyScalesAlongItsLength() {
        let marker = annotation(.marker([CGPoint(x: 10, y: 40), CGPoint(x: 50, y: 40)]))
        let resized = AnnotationResizer.resized(marker, dragging: .frame(.topRight), to: CGPoint(x: 90, y: 0))
        #expect(resized?.kind == .marker([CGPoint(x: 10, y: 40), CGPoint(x: 90, y: 40)]))
    }

    @Test func resizingBelowTheMinimumSizeIsRejected() {
        #expect(AnnotationResizer.resized(annotation(.rectangle(rect)), dragging: .frame(.right), to: CGPoint(x: 51, y: 50)) == nil)
        let line = annotation(.line(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 90, y: 40)))
        #expect(AnnotationResizer.resized(line, dragging: .end, to: CGPoint(x: 11, y: 11)) == nil)
    }

    @Test func mismatchedHandlesAreIgnored() {
        #expect(AnnotationResizer.resized(annotation(.rectangle(rect)), dragging: .start, to: .zero) == nil)
        #expect(AnnotationResizer.resized(annotation(.text("Hi", origin: .zero)), dragging: .frame(.top), to: .zero) == nil)
        #expect(AnnotationResizer.resized(annotation(.text("Hi", origin: .zero)), dragging: .end, to: .zero) == nil)
    }

    // MARK: Text

    @Test func draggingATextCornerScalesTheFontSize() {
        let text = annotation(.text("Hello", origin: CGPoint(x: 10, y: 20)))
        let box = text.bounds

        let resized = AnnotationResizer.resized(
            text, dragging: .frame(.bottomRight), to: CGPoint(x: box.maxX, y: box.minY + box.height * 2))

        #expect(resized?.style.fontSize == TextSize.default * 2)
        #expect(resized?.bounds.origin == box.origin)  // the opposite corner stays put
    }

    @Test func draggingTheTopLeftCornerKeepsTheBottomRightCorner() throws {
        let text = annotation(.text("Hello", origin: CGPoint(x: 100, y: 100)))
        let box = text.bounds

        let resized = try #require(
            AnnotationResizer.resized(text, dragging: .frame(.topLeft), to: CGPoint(x: box.minX, y: box.maxY - box.height * 2)))

        #expect(resized.style.fontSize == TextSize.default * 2)
        #expect(abs(resized.bounds.maxX - box.maxX) < 0.001)
        #expect(abs(resized.bounds.maxY - box.maxY) < 0.001)
    }

    @Test func textScalingIsClampedToTheSizeRange() {
        let text = annotation(.text("Hello", origin: .zero))
        let resized = AnnotationResizer.resized(text, dragging: .frame(.bottomRight), to: CGPoint(x: 0, y: 5000))
        #expect(resized?.style.fontSize == TextSize.range.upperBound)
    }
}
