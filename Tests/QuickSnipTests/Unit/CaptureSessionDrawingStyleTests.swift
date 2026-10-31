import CoreGraphics
import Testing

@testable import QuickSnip

/// Rectangle or oval, arrowheads, and Shift/Option while drawing and resizing.
@MainActor
struct CaptureSessionDrawingStyleTests {
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 200, height: 150), scale: 2)
    private let selection = CGRect(x: 20, y: 20, width: 120, height: 100)
    private let shift = DrawModifiers(isConstrained: true)

    private func makeSession() -> CaptureSession {
        let session = CaptureSession(displays: [display])
        TestSessions.select(session, on: 1, selection)
        return session
    }

    private func draw(_ tool: AnnotationTool, _ session: CaptureSession, from start: CGPoint, to end: CGPoint) {
        if session.tool != tool { session.toggleTool(tool) }
        TestSessions.drag(session, on: 1, from: start, to: end)
    }

    // MARK: Shape and arrowheads

    @Test func ovalChoiceTurnsTheSelectedRectangleIntoAnOvalInOneUndoStep() {
        let session = makeSession()
        draw(.shape, session, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 70, y: 60))

        session.setShape(.oval)

        #expect(session.document.annotations.first?.style.shape == .oval)
        #expect(session.document.annotations.first?.kind == .shape(CGRect(x: 40, y: 40, width: 30, height: 20)))
        #expect(session.styleOptions == .shape(.oval, lineWidth: LineWidth.default))
        session.undo()
        #expect(session.document.annotations.first?.style.shape == .rectangle)
    }

    @Test func shapeChoiceAppliesToTheNextShape() {
        let session = makeSession()
        session.toggleTool(.shape)
        session.setShape(.oval)
        #expect(session.styleOptions == .shape(.oval, lineWidth: LineWidth.default))

        draw(.shape, session, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 70, y: 60))

        #expect(session.document.annotations.first?.name == "Oval")
    }

    @Test func shapeChoiceLeavesASelectedArrowAlone() {
        let session = makeSession()
        draw(.arrow, session, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 90, y: 60))

        session.setShape(.oval)

        #expect(session.document.undoManager.undoActionName == "Add Arrow")
        #expect(session.style.shape == .oval)
    }

    @Test func arrowheadChoiceChangesTheSelectedArrow() {
        let session = makeSession()
        draw(.arrow, session, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 90, y: 60))

        session.setArrowHeads(.both)

        #expect(session.document.annotations.first?.name == "Double Arrow")
        #expect(session.styleOptions == .arrow(.both, lineWidth: LineWidth.default))
    }

    @Test func choicesAreReportedSoTheyCanBeRemembered() {
        let session = makeSession()
        var reported: [(ShapeKind, ArrowHeads)] = []
        session.onDrawingStyleChange = { reported.append(($0, $1)) }

        session.setShape(.oval)
        session.setArrowHeads(.none)

        #expect(reported.map(\.0) == [.oval, .oval])
        #expect(reported.map(\.1) == [.end, .none])
    }

    // MARK: Modifiers

    @Test func shiftDragDrawsASquare() {
        let session = makeSession()
        session.toggleTool(.shape)
        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 40))
        session.mouseDragged(on: 1, to: CGPoint(x: 90, y: 60), modifiers: shift)
        session.mouseUp(on: 1, at: CGPoint(x: 90, y: 60), modifiers: shift)

        #expect(session.document.annotations.first?.kind == .shape(CGRect(x: 40, y: 40, width: 50, height: 50)))
    }

    @Test func pressingShiftMidDragSquaresThePreviewRightAway() {
        let session = makeSession()
        session.toggleTool(.shape)
        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 40))
        session.mouseDragged(on: 1, to: CGPoint(x: 90, y: 60))
        var changes = 0
        session.onChange = { changes += 1 }

        session.modifiersChanged(shift)

        #expect(changes == 1)
        #expect(session.visibleAnnotations.first?.kind == .shape(CGRect(x: 40, y: 40, width: 50, height: 50)))
    }

    @Test func modifiersWithoutADragChangeNothing() {
        let session = makeSession()
        var changes = 0
        session.onChange = { changes += 1 }
        session.modifiersChanged(shift)
        #expect(changes == 0)
    }

    @Test func shiftWhileResizingAShapeKeepsItsProportions() {
        let session = makeSession()
        draw(.shape, session, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 70, y: 60))
        session.mouseDown(on: 1, at: CGPoint(x: 70, y: 60))  // bottom-right handle
        session.mouseDragged(on: 1, to: CGPoint(x: 100, y: 70))
        #expect(session.visibleAnnotations.first?.kind == .shape(CGRect(x: 40, y: 40, width: 60, height: 30)))

        session.modifiersChanged(shift)
        #expect(session.visibleAnnotations.first?.kind == .shape(CGRect(x: 40, y: 40, width: 60, height: 40)))

        session.mouseUp(on: 1, at: CGPoint(x: 100, y: 70), modifiers: shift)
        #expect(session.document.annotations.first?.kind == .shape(CGRect(x: 40, y: 40, width: 60, height: 40)))
    }

    @Test func shiftDragSnapsAnArrowToAStraightLine() {
        let session = makeSession()
        session.toggleTool(.arrow)
        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 40))
        session.mouseUp(on: 1, at: CGPoint(x: 100, y: 46), modifiers: shift)

        #expect(session.document.annotations.first?.kind == .arrow(from: CGPoint(x: 40, y: 40), to: CGPoint(x: 100, y: 40)))
    }
}
