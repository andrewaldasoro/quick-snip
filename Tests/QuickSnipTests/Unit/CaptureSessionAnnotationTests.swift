import CoreGraphics
import Testing

@testable import QuickSnip

@MainActor
struct CaptureSessionAnnotationTests {
    private let builtIn = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 200, height: 150), scale: 2)
    private let external = TestImages.display(id: 2, frame: CGRect(x: 200, y: 0, width: 200, height: 150), scale: 1)
    private let selection = CGRect(x: 20, y: 20, width: 120, height: 100)

    private func makeSession() -> CaptureSession {
        let session = CaptureSession(displays: [builtIn, external])
        TestSessions.select(session, on: 1, selection)
        return session
    }

    private func drawRectangle(_ session: CaptureSession, _ rect: CGRect) {
        if session.tool != .rectangle { session.toggleTool(.rectangle) }
        TestSessions.drag(session, on: 1, from: rect.origin, to: CGPoint(x: rect.maxX, y: rect.maxY))
    }

    // MARK: Tools

    @Test func toggleToolSelectsAndDeselects() {
        let session = makeSession()
        session.toggleTool(.arrow)
        #expect(session.tool == .arrow)
        session.toggleTool(.pen)
        #expect(session.tool == .pen)
        session.toggleTool(.pen)
        #expect(session.tool == nil)
    }

    @Test func drawingWithToolAddsAnnotationAndKeepsSelection() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))

        #expect(session.document.annotations.map(\.kind) == [.rectangle(CGRect(x: 40, y: 40, width: 30, height: 20))])
        #expect(session.activeSelection == selection)
    }

    @Test func draftIsVisibleWhileDrawing() {
        let session = makeSession()
        session.toggleTool(.line)
        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 40))
        session.mouseDragged(on: 1, to: CGPoint(x: 80, y: 40))

        #expect(session.isDrawing)
        #expect(session.document.annotations.isEmpty)
        #expect(session.visibleAnnotations.count == 1)

        session.mouseUp(on: 1, at: CGPoint(x: 80, y: 40))
        #expect(!session.isDrawing)
        #expect(session.visibleAnnotations.count == 1)
        #expect(session.document.annotations.count == 1)
    }

    @Test func drawingIsClampedToSelection() {
        let session = makeSession()
        session.toggleTool(.line)
        TestSessions.drag(session, on: 1, from: CGPoint(x: 100, y: 50), to: CGPoint(x: 500, y: -50))
        #expect(session.document.annotations.first?.kind == .line(from: CGPoint(x: 100, y: 50), to: CGPoint(x: 140, y: 20)))
    }

    @Test func toolDragOutsideSelectionDoesNothing() {
        let session = makeSession()
        session.toggleTool(.rectangle)
        TestSessions.drag(session, on: 1, from: CGPoint(x: 160, y: 130), to: CGPoint(x: 190, y: 140))
        #expect(session.document.annotations.isEmpty)
        #expect(session.activeSelection == selection)
    }

    @Test func handlesStillResizeWithAToolActive() {
        let session = makeSession()
        session.toggleTool(.pen)
        TestSessions.drag(session, on: 1, from: CGPoint(x: 140, y: 120), to: CGPoint(x: 160, y: 130))
        #expect(session.activeSelection == CGRect(x: 20, y: 20, width: 140, height: 110))
        #expect(session.document.annotations.isEmpty)
    }

    @Test func newAnnotationsUseCurrentStyle() {
        let session = makeSession()
        session.setColor(.blue)
        session.setWidth(.thick)
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        #expect(session.document.annotations.first?.style == AnnotationStyle(color: .blue, width: .thick))
    }

    // MARK: Text

    @Test func textToolRequestsEntryInsideSelection() {
        let session = makeSession()
        var requests: [(CGDirectDisplayID, CGPoint)] = []
        session.onRequestTextEntry = { requests.append(($0, $1)) }
        session.toggleTool(.text)

        session.mouseDown(on: 1, at: CGPoint(x: 50, y: 60))
        session.mouseDown(on: 1, at: CGPoint(x: 190, y: 140))  // outside

        #expect(requests.count == 1)
        #expect(requests.first?.0 == 1)
        #expect(requests.first?.1 == CGPoint(x: 50, y: 60))
    }

    @Test func addTextTrimsAndIgnoresEmpty() {
        let session = makeSession()
        session.addText("  hello \n", at: CGPoint(x: 50, y: 60), on: 1)
        session.addText("   ", at: CGPoint(x: 50, y: 60), on: 1)
        session.addText("other display", at: .zero, on: 2)
        #expect(session.document.annotations.map(\.kind) == [.text("hello", origin: CGPoint(x: 50, y: 60))])
    }

    // MARK: Selecting & moving annotations

    @Test func clickingAnAnnotationWithoutToolSelectsIt() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)  // off

        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 50))
        session.mouseUp(on: 1, at: CGPoint(x: 40, y: 50))

        #expect(session.selectedAnnotation?.id == session.document.annotations.first?.id)
        #expect(session.activeSelection == selection)
    }

    @Test func draggingAnAnnotationMovesItNotTheSelection() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)

        TestSessions.drag(session, on: 1, from: CGPoint(x: 40, y: 50), to: CGPoint(x: 60, y: 70))

        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 60, y: 60, width: 30, height: 20)))
        #expect(session.activeSelection == selection)
        #expect(session.document.undoManager.undoActionName == "Move Rectangle")
    }

    @Test func moveIsPreviewedThenCommittedOnce() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)

        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 50))
        session.mouseDragged(on: 1, to: CGPoint(x: 50, y: 50))
        #expect(session.visibleAnnotations.first?.kind == .rectangle(CGRect(x: 50, y: 40, width: 30, height: 20)))
        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 40, y: 40, width: 30, height: 20)))
        session.mouseUp(on: 1, at: CGPoint(x: 50, y: 50))

        session.undo()
        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 40, y: 40, width: 30, height: 20)))
    }

    // MARK: Resizing annotations

    private func selectFirstAnnotation(_ session: CaptureSession, at point: CGPoint) {
        session.mouseDown(on: 1, at: point)
        session.mouseUp(on: 1, at: point)
    }

    @Test func draggingAHandleOfTheSelectedAnnotationResizesIt() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)
        selectFirstAnnotation(session, at: CGPoint(x: 40, y: 50))

        session.mouseDown(on: 1, at: CGPoint(x: 70, y: 60))
        session.mouseDragged(on: 1, to: CGPoint(x: 90, y: 80))
        #expect(session.visibleAnnotations.first?.kind == .rectangle(CGRect(x: 40, y: 40, width: 50, height: 40)))
        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 40, y: 40, width: 30, height: 20)))
        session.mouseUp(on: 1, at: CGPoint(x: 100, y: 90))

        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 40, y: 40, width: 60, height: 50)))
        #expect(session.document.undoManager.undoActionName == "Resize Rectangle")
        #expect(session.activeSelection == selection)
    }

    @Test func resizeIsOneUndoStep() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)
        selectFirstAnnotation(session, at: CGPoint(x: 40, y: 50))

        TestSessions.drag(
            session, on: 1, from: CGPoint(x: 70, y: 60), through: [CGPoint(x: 80, y: 70), CGPoint(x: 90, y: 75)], to: CGPoint(x: 100, y: 90)
        )
        session.undo()

        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 40, y: 40, width: 30, height: 20)))
    }

    @Test func annotationHandleWinsOverTheSelectionHandle() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 100, y: 80, width: 40, height: 40))  // bottom-right corner on the selection's
        session.toggleTool(.rectangle)
        selectFirstAnnotation(session, at: CGPoint(x: 100, y: 100))

        TestSessions.drag(session, on: 1, from: CGPoint(x: 140, y: 120), to: CGPoint(x: 120, y: 110))

        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 100, y: 80, width: 20, height: 30)))
        #expect(session.activeSelection == selection)
    }

    @Test func aCollapsingResizeKeepsTheLastValidShape() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)
        selectFirstAnnotation(session, at: CGPoint(x: 40, y: 50))

        TestSessions.drag(session, on: 1, from: CGPoint(x: 70, y: 60), through: [CGPoint(x: 80, y: 70)], to: CGPoint(x: 41, y: 41))

        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 40, y: 40, width: 40, height: 30)))
    }

    @Test func handlesOnlyResizeWithoutATool() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)
        selectFirstAnnotation(session, at: CGPoint(x: 40, y: 50))
        #expect(session.annotationHandle(on: 1, at: CGPoint(x: 70, y: 60)) == .frame(.bottomRight))
        #expect(session.annotationHandle(on: 2, at: CGPoint(x: 70, y: 60)) == nil)

        session.toggleTool(.line)
        #expect(session.annotationHandle(on: 1, at: CGPoint(x: 70, y: 60)) == nil)
    }

    @Test func handleShowsAResizeCursor() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)
        selectFirstAnnotation(session, at: CGPoint(x: 40, y: 50))
        #expect(session.cursor(on: 1, at: CGPoint(x: 70, y: 60)) == .resize(.bottomRight))
    }

    @Test func choosingAToolClearsAnnotationSelection() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)
        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 50))
        session.mouseUp(on: 1, at: CGPoint(x: 40, y: 50))

        session.toggleTool(.arrow)
        #expect(session.selectedAnnotation == nil)
    }

    @Test func styleChangesApplyToSelectedAnnotation() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)
        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 50))
        session.mouseUp(on: 1, at: CGPoint(x: 40, y: 50))

        session.setColor(.green)
        session.setWidth(.thin)

        #expect(session.document.annotations.first?.style == AnnotationStyle(color: .green, width: .thin))
        session.undo()
        #expect(session.document.annotations.first?.style == AnnotationStyle(color: .green, width: .medium))
    }

    @Test func deleteRemovesSelectedAnnotation() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)
        #expect(!session.deleteSelectedAnnotation())

        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 50))
        session.mouseUp(on: 1, at: CGPoint(x: 40, y: 50))
        #expect(session.deleteSelectedAnnotation())
        #expect(session.document.annotations.isEmpty)
        #expect(session.selectedAnnotation == nil)
    }

    @Test func undoingTheSelectedAnnotationClearsSelection() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)
        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 50))
        session.mouseUp(on: 1, at: CGPoint(x: 40, y: 50))

        session.undo()
        #expect(session.selectedAnnotation == nil)
    }

    // MARK: Protecting annotations

    @Test func clickOutsideKeepsAnnotatedSelection() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)

        TestSessions.drag(session, on: 1, from: CGPoint(x: 160, y: 130), to: CGPoint(x: 190, y: 145))
        TestSessions.drag(session, on: 2, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 50))

        #expect(session.activeDisplayID == 1)
        #expect(session.activeSelection == selection)
        #expect(session.document.annotations.count == 1)
    }

    @Test func clickOutsideWithoutAnnotationsStartsNewSelection() {
        let session = makeSession()
        TestSessions.drag(session, on: 1, from: CGPoint(x: 150, y: 125), to: CGPoint(x: 190, y: 145))
        #expect(session.activeSelection == CGRect(x: 150, y: 125, width: 40, height: 20))
    }

    @Test func movingTheSelectionKeepsAnnotationsInPlace() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.toggleTool(.rectangle)

        TestSessions.drag(session, on: 1, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 110, y: 105))

        #expect(session.activeSelection == selection.offsetBy(dx: 10, dy: 5))
        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 40, y: 40, width: 30, height: 20)))
    }

    // MARK: Output

    @Test func renderedImageIncludesAnnotations() throws {
        let session = makeSession()
        let plain = try #require(session.renderedImage())
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        let annotated = try #require(session.renderedImage())

        #expect(plain.width == annotated.width)
        #expect(TestImages.pixel(annotated, x: 40, y: 50).isClose(to: .red))  // left edge at 40pt → (40-20)*2
        #expect(!TestImages.pixel(plain, x: 40, y: 50).isClose(to: .red))
    }

    @Test func everyInteractionNotifies() {
        let session = makeSession()
        var changes = 0
        session.onChange = { changes += 1 }
        session.toggleTool(.rectangle)
        session.setColor(.blue)
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.undo()
        #expect(changes >= 6)
    }
}
