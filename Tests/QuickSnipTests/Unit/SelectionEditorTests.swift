import CoreGraphics
import Testing

@testable import QuickSnip

struct SelectionEditorTests {
    private let bounds = CGRect(x: 0, y: 0, width: 200, height: 100)

    private func editor(with selection: CGRect) -> SelectionEditor {
        var editor = SelectionEditor(bounds: bounds)
        editor.mouseDown(at: selection.origin)
        editor.mouseUp(at: CGPoint(x: selection.maxX, y: selection.maxY))
        return editor
    }

    // MARK: Creating

    @Test func dragCreatesSelection() {
        var editor = SelectionEditor(bounds: bounds)
        editor.mouseDown(at: CGPoint(x: 10, y: 20))
        editor.mouseDragged(to: CGPoint(x: 50, y: 60))
        #expect(editor.isDragging)
        editor.mouseUp(at: CGPoint(x: 60, y: 70))
        #expect(editor.selection == CGRect(x: 10, y: 20, width: 50, height: 50))
        #expect(!editor.isDragging)
    }

    @Test func reverseDragIsNormalized() {
        var editor = SelectionEditor(bounds: bounds)
        editor.mouseDown(at: CGPoint(x: 80, y: 60))
        editor.mouseUp(at: CGPoint(x: 30, y: 20))
        #expect(editor.selection == CGRect(x: 30, y: 20, width: 50, height: 40))
    }

    @Test func dragBeyondBoundsIsClamped() {
        var editor = SelectionEditor(bounds: bounds)
        editor.mouseDown(at: CGPoint(x: 150, y: 50))
        editor.mouseUp(at: CGPoint(x: 400, y: -30))
        #expect(editor.selection == CGRect(x: 150, y: 0, width: 50, height: 50))
    }

    @Test func mouseDownOutsideBoundsAnchorsAtEdge() {
        var editor = SelectionEditor(bounds: bounds)
        editor.mouseDown(at: CGPoint(x: -10, y: -10))
        editor.mouseUp(at: CGPoint(x: 20, y: 20))
        #expect(editor.selection == CGRect(x: 0, y: 0, width: 20, height: 20))
    }

    @Test func clickWithoutDragLeavesNoSelection() {
        var editor = SelectionEditor(bounds: bounds)
        editor.mouseDown(at: CGPoint(x: 10, y: 10))
        editor.mouseUp(at: CGPoint(x: 11, y: 10))
        #expect(editor.selection == nil)
    }

    @Test func thinDragBelowMinimumIsDiscarded() {
        var editor = SelectionEditor(bounds: bounds)
        editor.mouseDown(at: CGPoint(x: 10, y: 10))
        editor.mouseUp(at: CGPoint(x: 90, y: 11))
        #expect(editor.selection == nil)
    }

    @Test func newDragOutsideReplacesSelection() {
        var editor = editor(with: CGRect(x: 10, y: 10, width: 20, height: 20))
        editor.mouseDown(at: CGPoint(x: 100, y: 50))
        editor.mouseUp(at: CGPoint(x: 150, y: 90))
        #expect(editor.selection == CGRect(x: 100, y: 50, width: 50, height: 40))
    }

    @Test func dragEventsWithoutMouseDownAreIgnored() {
        var editor = SelectionEditor(bounds: bounds)
        editor.mouseDragged(to: CGPoint(x: 50, y: 50))
        editor.mouseUp(at: CGPoint(x: 50, y: 50))
        #expect(editor.selection == nil)
    }

    // MARK: Hit testing

    @Test(arguments: [
        (CGPoint(x: 50, y: 20), SelectionHit.handle(.topLeft)),
        (CGPoint(x: 150, y: 20), .handle(.topRight)),
        (CGPoint(x: 150, y: 80), .handle(.bottomRight)),
        (CGPoint(x: 50, y: 80), .handle(.bottomLeft)),
        (CGPoint(x: 100, y: 22), .handle(.top)),
        (CGPoint(x: 70, y: 79), .handle(.bottom)),
        (CGPoint(x: 52, y: 40), .handle(.left)),
        (CGPoint(x: 148, y: 60), .handle(.right)),
        (CGPoint(x: 100, y: 50), .inside),
        (CGPoint(x: 10, y: 10), .outside),
        (CGPoint(x: 190, y: 50), .outside),
    ])
    func hitTest(point: CGPoint, expected: SelectionHit) {
        let editor = editor(with: CGRect(x: 50, y: 20, width: 100, height: 60))
        #expect(editor.hitTest(point) == expected)
    }

    @Test func hitTestWithoutSelectionIsOutside() {
        #expect(SelectionEditor(bounds: bounds).hitTest(CGPoint(x: 10, y: 10)) == .outside)
    }

    @Test func cornersWinOverEdges() {
        let editor = editor(with: CGRect(x: 50, y: 20, width: 100, height: 60))
        #expect(editor.hitTest(CGPoint(x: 53, y: 23)) == .handle(.topLeft))
    }

    // MARK: Moving

    @Test func dragInsideMovesSelection() {
        var editor = editor(with: CGRect(x: 50, y: 20, width: 40, height: 30))
        editor.mouseDown(at: CGPoint(x: 70, y: 35))
        editor.mouseUp(at: CGPoint(x: 80, y: 40))
        #expect(editor.selection == CGRect(x: 60, y: 25, width: 40, height: 30))
    }

    @Test func moveIsClampedInsideBounds() {
        var editor = editor(with: CGRect(x: 50, y: 20, width: 40, height: 30))
        editor.mouseDown(at: CGPoint(x: 70, y: 35))
        editor.mouseUp(at: CGPoint(x: 500, y: -500))
        #expect(editor.selection == CGRect(x: 160, y: 0, width: 40, height: 30))
    }

    // MARK: Resizing

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
    func resizeFromHandle(handle: SelectionHandle, to point: CGPoint, expected: CGRect) {
        let original = CGRect(x: 50, y: 20, width: 100, height: 60)
        var editor = editor(with: original)
        editor.mouseDown(at: handle.point(in: original))
        editor.mouseUp(at: point)
        #expect(editor.selection == expected)
    }

    @Test func resizePastOppositeEdgeFlips() {
        var editor = editor(with: CGRect(x: 50, y: 20, width: 100, height: 60))
        editor.mouseDown(at: CGPoint(x: 50, y: 50))  // left edge
        editor.mouseUp(at: CGPoint(x: 180, y: 50))
        #expect(editor.selection == CGRect(x: 150, y: 20, width: 30, height: 60))
    }

    @Test func resizeIsClampedToBounds() {
        var editor = editor(with: CGRect(x: 50, y: 20, width: 100, height: 60))
        editor.mouseDown(at: CGPoint(x: 150, y: 80))
        editor.mouseUp(at: CGPoint(x: 999, y: 999))
        #expect(editor.selection == CGRect(x: 50, y: 20, width: 150, height: 80))
    }

    @Test func clearRemovesSelection() {
        var editor = editor(with: CGRect(x: 50, y: 20, width: 100, height: 60))
        editor.clear()
        #expect(editor.selection == nil)
        #expect(!editor.isDragging)
    }

    // MARK: Handles

    @Test func handlePositions() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 50)
        #expect(SelectionHandle.topLeft.point(in: rect) == CGPoint(x: 10, y: 20))
        #expect(SelectionHandle.top.point(in: rect) == CGPoint(x: 60, y: 20))
        #expect(SelectionHandle.right.point(in: rect) == CGPoint(x: 110, y: 45))
        #expect(SelectionHandle.bottomLeft.point(in: rect) == CGPoint(x: 10, y: 70))
        #expect(SelectionHandle.allCases.filter(\.isCorner).count == 4)
    }
}
