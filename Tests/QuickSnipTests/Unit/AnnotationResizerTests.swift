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
        for kind in [AnnotationKind.shape(rect), .pixelate(rect)] {
            let handles = AnnotationResizer.handles(for: annotation(kind))
            #expect(handles.map(\.handle) == SelectionHandle.allCases.map { .frame($0) })
            #expect(handles.first?.point == CGPoint(x: 50, y: 20))
        }
    }

    @Test func linesAndArrowsHaveOneHandlePerEnd() {
        let line = annotation(.arrow(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 90, y: 40)))
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
        let rectangle = annotation(.shape(rect))
        #expect(AnnotationResizer.hitTest(CGPoint(x: 154, y: 84), on: rectangle) == .frame(.bottomRight))
        #expect(AnnotationResizer.hitTest(CGPoint(x: 100, y: 22), on: rectangle) == .frame(.top))
        #expect(AnnotationResizer.hitTest(CGPoint(x: 100, y: 50), on: rectangle) == nil)
    }

    @Test func cornersWinOverEdgesOnTinyShapes() {
        let tiny = annotation(.shape(CGRect(x: 50, y: 50, width: 4, height: 4)))
        #expect(AnnotationResizer.hitTest(CGPoint(x: 51, y: 51), on: tiny) == .frame(.topLeft))
    }

    // MARK: Resizing

    @Test(arguments: [
        (SelectionHandle.topLeft, CGPoint(x: 40, y: 10), CGRect(x: 40, y: 10, width: 110, height: 70)),
        (.right, CGPoint(x: 170, y: 999), CGRect(x: 50, y: 20, width: 120, height: 60)),
        (.bottom, CGPoint(x: 0, y: 100), CGRect(x: 50, y: 20, width: 100, height: 80)),
    ])
    func rectangleResizesFromItsHandle(handle: SelectionHandle, to point: CGPoint, expected: CGRect) {
        let resized = AnnotationResizer.resized(annotation(.shape(rect)), dragging: .frame(handle), to: point)
        #expect(resized?.kind == .shape(expected))
    }

    @Test func pixelateResizesLikeARectangle() {
        let resized = AnnotationResizer.resized(annotation(.pixelate(rect)), dragging: .frame(.bottomRight), to: CGPoint(x: 200, y: 100))
        #expect(resized?.kind == .pixelate(CGRect(x: 50, y: 20, width: 150, height: 80)))
    }

    @Test func resizeKeepsIDAndStyle() {
        let original = Annotation(kind: .shape(rect), style: AnnotationStyle(color: .blue, lineWidth: 8))
        let resized = AnnotationResizer.resized(original, dragging: .frame(.right), to: CGPoint(x: 200, y: 50))
        #expect(resized?.id == original.id)
        #expect(resized?.style == original.style)
    }

    @Test func draggingALineEndMovesOnlyThatEnd() {
        let from = CGPoint(x: 10, y: 10)
        let to = CGPoint(x: 90, y: 40)
        let line = annotation(.arrow(from: from, to: to))
        let arrow = annotation(.arrow(from: from, to: to))

        #expect(AnnotationResizer.resized(line, dragging: .start, to: CGPoint(x: 0, y: 0))?.kind == .arrow(from: .zero, to: to))
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
        #expect(AnnotationResizer.resized(annotation(.shape(rect)), dragging: .frame(.right), to: CGPoint(x: 51, y: 50)) == nil)
        let line = annotation(.arrow(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 90, y: 40)))
        #expect(AnnotationResizer.resized(line, dragging: .end, to: CGPoint(x: 11, y: 11)) == nil)
    }

    @Test func mismatchedHandlesAreIgnored() {
        #expect(AnnotationResizer.resized(annotation(.shape(rect)), dragging: .start, to: .zero) == nil)
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

    // MARK: Text boxes

    @Test func aTextBoxHasLeftAndRightHandles() {
        let box = annotation(.text("Hello", origin: CGPoint(x: 10, y: 20), boxWidth: 120))
        #expect(AnnotationResizer.handles(for: box).map(\.handle) == [.frame(.left), .frame(.right)])
        #expect(AnnotationResizer.handles(for: box).first?.point.x == 10)
    }

    @Test func draggingABoxEdgeChangesItsWidthOnly() {
        let box = annotation(.text("Hello", origin: CGPoint(x: 10, y: 20), boxWidth: 120))
        let wider = AnnotationResizer.resized(box, dragging: .frame(.right), to: CGPoint(x: 200, y: 999))
        let fromLeft = AnnotationResizer.resized(box, dragging: .frame(.left), to: CGPoint(x: 40, y: 0))
        #expect(wider?.kind == .text("Hello", origin: CGPoint(x: 10, y: 20), boxWidth: 190))
        #expect(fromLeft?.kind == .text("Hello", origin: CGPoint(x: 40, y: 20), boxWidth: 90))
        #expect(wider?.style.fontSize == TextSize.default)
    }

    @Test func aBoxCantGetNarrowerThanTheMinimum() {
        let box = annotation(.text("Hello", origin: CGPoint(x: 10, y: 20), boxWidth: 120))
        #expect(AnnotationResizer.resized(box, dragging: .frame(.right), to: CGPoint(x: 20, y: 0)) == nil)
        #expect(AnnotationResizer.resized(box, dragging: .frame(.topLeft), to: .zero) == nil)
    }

    @Test func scalingCenteredTextKeepsItsOriginAtTheTopLeft() throws {
        var style = AnnotationStyle.default
        style.alignment = .center
        let text = Annotation(kind: .text("Hello", origin: CGPoint(x: 200, y: 100)), style: style)
        let box = text.bounds

        let resized = try #require(
            AnnotationResizer.resized(text, dragging: .frame(.bottomRight), to: CGPoint(x: box.maxX, y: box.minY + box.height * 2)))

        #expect(abs(resized.bounds.minX - box.minX) < 0.001)  // the opposite corner stays
        guard case .text(_, let origin, nil) = resized.kind else {
            Issue.record("Expected one-line text")
            return
        }
        #expect(origin == resized.bounds.origin)  // click text's origin is its box's top-left
    }

    // MARK: Shift

    private let shift = DrawModifiers(isConstrained: true)

    @Test func shiftCornerKeepsTheShapesProportions() {
        let resized = AnnotationResizer.resized(
            annotation(.shape(rect)), dragging: .frame(.bottomRight), to: CGPoint(x: 250, y: 90), modifiers: shift)
        #expect(resized?.kind == .shape(CGRect(x: 50, y: 20, width: 200, height: 120)))
    }

    @Test func shiftCornerKeepsACircleRound() {
        let circle = Annotation(kind: .shape(CGRect(x: 0, y: 0, width: 40, height: 40)), style: AnnotationStyle(shape: .oval))
        let resized = AnnotationResizer.resized(circle, dragging: .frame(.topLeft), to: CGPoint(x: -20, y: 30), modifiers: shift)
        #expect(resized?.kind == .shape(CGRect(x: -20, y: -20, width: 60, height: 60)))
    }

    @Test func shiftLeavesEdgeHandlesFree() {
        let resized = AnnotationResizer.resized(
            annotation(.shape(rect)), dragging: .frame(.right), to: CGPoint(x: 250, y: 50), modifiers: shift)
        #expect(resized?.kind == .shape(CGRect(x: 50, y: 20, width: 200, height: 60)))
    }

    @Test func shiftSnapsTheDraggedArrowEnd() {
        let arrow = annotation(.arrow(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 90, y: 40)))
        let end = AnnotationResizer.resized(arrow, dragging: .end, to: CGPoint(x: 92, y: 13), modifiers: shift)
        #expect(end?.kind == .arrow(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 92, y: 10)))
        let start = AnnotationResizer.resized(arrow, dragging: .start, to: CGPoint(x: 88, y: -10), modifiers: shift)
        #expect(start?.kind == .arrow(from: CGPoint(x: 90, y: -10), to: CGPoint(x: 90, y: 40)))
    }
}
