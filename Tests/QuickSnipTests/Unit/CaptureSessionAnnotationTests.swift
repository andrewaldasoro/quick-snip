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

    @Test func drawingTurnsTheToolOffAndSelectsTheNewShape() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))

        #expect(session.tool == nil)
        #expect(session.selectedAnnotation?.id == session.document.annotations.first?.id)
        #expect(session.annotationHandle(on: 1, at: CGPoint(x: 70, y: 60)) == .frame(.bottomRight))
    }

    @Test func aStrayClickWithAToolKeepsTheTool() {
        let session = makeSession()
        session.toggleTool(.arrow)
        TestSessions.drag(session, on: 1, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 51, y: 50))  // too short to draw

        #expect(session.tool == .arrow)
        #expect(session.selectedAnnotation == nil)
    }

    @Test func placingTextTurnsTheToolOffAndSelectsIt() {
        let session = makeSession()
        session.toggleTool(.text)
        session.addText("Hi", at: .line(at: CGPoint(x: 50, y: 60)), on: 1)

        #expect(session.tool == nil)
        #expect(session.selectedAnnotation?.kind == .text("Hi", origin: CGPoint(x: 50, y: 60)))
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
        session.setLineWidth(8)
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        #expect(session.document.annotations.first?.style == AnnotationStyle(color: .blue, lineWidth: 8))
    }

    // MARK: Text

    @Test func textToolClickRequestsOneLineInsideSelection() {
        let session = makeSession()
        var requests: [(CGDirectDisplayID, TextPlacement)] = []
        session.onRequestTextEntry = { requests.append(($0, $1)) }
        session.toggleTool(.text)

        TestSessions.drag(session, on: 1, from: CGPoint(x: 50, y: 60), to: CGPoint(x: 52, y: 61))
        TestSessions.drag(session, on: 1, from: CGPoint(x: 190, y: 140), to: CGPoint(x: 190, y: 140))  // outside

        #expect(requests.count == 1)
        #expect(requests.first?.0 == 1)
        #expect(requests.first?.1 == .line(at: CGPoint(x: 50, y: 60)))
    }

    @Test func textToolDragRequestsABoxClampedToTheSelection() {
        let session = makeSession()
        var requests: [TextPlacement] = []
        session.onRequestTextEntry = { requests.append($1) }
        session.toggleTool(.text)

        session.mouseDown(on: 1, at: CGPoint(x: 100, y: 60))
        session.mouseDragged(on: 1, to: CGPoint(x: 40, y: 80))
        #expect(session.textBoxPreview == CGRect(x: 40, y: 60, width: 60, height: 20))
        session.mouseUp(on: 1, at: CGPoint(x: 500, y: 80))  // past the selection's right edge

        #expect(requests == [TextPlacement(origin: CGPoint(x: 100, y: 60), boxWidth: 40)])
        #expect(session.textBoxPreview == nil)
    }

    @Test func aShortTextDragHasNoBoxPreview() {
        let session = makeSession()
        session.toggleTool(.text)
        session.mouseDown(on: 1, at: CGPoint(x: 50, y: 60))
        session.mouseDragged(on: 1, to: CGPoint(x: 60, y: 70))
        #expect(session.textBoxPreview == nil)
    }

    @Test func boxedTextKeepsItsWidth() {
        let session = makeSession()
        session.addText("Hello", at: TextPlacement(origin: CGPoint(x: 30, y: 40), boxWidth: 80), on: 1)
        #expect(session.document.annotations.first?.kind == .text("Hello", origin: CGPoint(x: 30, y: 40), boxWidth: 80))
    }

    @Test func alignmentAppliesToNewAndSelectedTextAsOneUndoStep() {
        let session = makeSession()
        session.addText("Hello", at: .line(at: CGPoint(x: 50, y: 60)), on: 1)
        let before = session.document.annotations.first?.bounds

        session.setAlignment(.right)

        #expect(session.style.alignment == .right)
        #expect(session.document.annotations.first?.style.alignment == .right)
        #expect(session.document.annotations.first?.bounds == before)  // stays where it was
        #expect(session.styleOptions == .text(font: .system, size: TextSize.default, alignment: .right))
        session.undo()
        #expect(session.document.annotations.first?.style.alignment == .left)
    }

    @Test func alignmentLeavesSelectedShapesAlone() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.setAlignment(.center)
        #expect(session.document.annotations.first?.style.alignment == .left)
        #expect(session.document.undoManager.undoActionName == "Add Rectangle")
    }

    @Test func styleColorIsTheSelectedAnnotationsOwn() {
        let session = makeSession()
        session.setColor(.blue)
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        selectFirstAnnotation(session, at: CGPoint(x: 100, y: 100))  // deselect
        session.setColor(.green)  // only for what's drawn next
        #expect(session.styleColor == .green)

        selectFirstAnnotation(session, at: CGPoint(x: 47, y: 40))
        #expect(session.styleColor == .blue)
    }

    @Test func addTextTrimsAndIgnoresEmpty() {
        let session = makeSession()
        session.addText("  hello \n", at: .line(at: CGPoint(x: 50, y: 60)), on: 1)
        session.addText("   ", at: .line(at: CGPoint(x: 50, y: 60)), on: 1)
        session.addText("other display", at: .line(at: .zero), on: 2)
        #expect(session.document.annotations.map(\.kind) == [.text("hello", origin: CGPoint(x: 50, y: 60))])
    }

    // MARK: Text style

    /// Placed text is selected right away.
    private func addAndSelectText(_ session: CaptureSession) {
        session.addText("Hello", at: .line(at: CGPoint(x: 50, y: 60)), on: 1)
    }

    @Test func newTextUsesTheChosenFontAndSize() {
        let session = makeSession()
        session.setFont(.serif)
        session.setFontSize(40)
        session.addText("Hi", at: .line(at: CGPoint(x: 50, y: 60)), on: 1)

        #expect(session.document.annotations.first?.style.font == .serif)
        #expect(session.document.annotations.first?.style.fontSize == 40)
    }

    @Test func fontSizeIsClamped() {
        let session = makeSession()
        session.setFontSize(1)
        #expect(session.style.fontSize == TextSize.range.lowerBound)
    }

    @Test func sessionStartsWithTheGivenStyle() {
        let session = CaptureSession(displays: [builtIn], style: AnnotationStyle(font: .rounded, fontSize: 30))
        #expect(session.style.font == .rounded)
        session.toggleTool(.text)
        #expect(session.styleOptions == .text(font: .rounded, size: 30, alignment: .left))
    }

    @Test func fontAndSizeApplyToTheSelectedTextAsOneUndoStepEach() {
        let session = makeSession()
        addAndSelectText(session)

        session.setFont(.monospaced)
        session.setFontSize(50)

        #expect(session.document.annotations.first?.style.font == .monospaced)
        #expect(session.document.annotations.first?.style.fontSize == 50)
        session.undo()
        #expect(session.document.annotations.first?.style.fontSize == TextSize.default)
        #expect(session.document.annotations.first?.style.font == .monospaced)
    }

    @Test func fontChangesLeaveSelectedShapesAlone() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        selectFirstAnnotation(session, at: CGPoint(x: 40, y: 50))

        session.setFontSize(80)

        #expect(session.document.annotations.first?.style.fontSize == TextSize.default)
        #expect(session.document.undoManager.undoActionName == "Add Rectangle")
        #expect(session.style.fontSize == 80)
    }

    @Test func styleOptionsFollowTheToolWhenNothingIsSelected() {
        let session = makeSession()
        #expect(session.styleOptions == nil)
        session.toggleTool(.arrow)
        #expect(session.styleOptions == .stroke(lineWidth: LineWidth.default))
        session.toggleTool(.text)
        #expect(session.styleOptions == .text(font: .system, size: TextSize.default, alignment: .left))
        session.toggleTool(.pixelate)
        #expect(session.styleOptions == nil)
    }

    @Test func styleOptionsShowTheSelectedAnnotationsOwnStyle() {
        let session = makeSession()
        session.setLineWidth(12)
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.setLineWidth(2)  // applies to the selected rectangle too

        #expect(session.styleOptions == .stroke(lineWidth: 2))
        #expect(session.document.annotations.first?.style.lineWidth == 2)
    }

    @Test func lineWidthLeavesSelectedTextAlone() {
        let session = makeSession()
        addAndSelectText(session)

        session.setLineWidth(16)

        #expect(session.document.annotations.first?.style.lineWidth == LineWidth.default)
        #expect(session.style.lineWidth == 16)
    }

    @Test func textSizeShownIsTheSelectedTextsOwn() {
        let session = makeSession()
        session.addText("Hello", at: .line(at: CGPoint(x: 50, y: 60)), on: 1)
        session.addText("World", at: .line(at: CGPoint(x: 50, y: 100)), on: 1)
        session.setFontSize(70)  // the just-added "World" is selected

        selectFirstAnnotation(session, at: CGPoint(x: 52, y: 62))

        #expect(session.styleOptions == .text(font: .system, size: TextSize.default, alignment: .left))
    }

    @Test func textStyleChangesAreReported() {
        let session = makeSession()
        var reported: [(TextFont, CGFloat)] = []
        session.onTextStyleChange = { reported.append(($0, $1)) }

        session.setFont(.handwriting)
        session.setFontSize(30)

        #expect(reported.map(\.0) == [.handwriting, .handwriting])
        #expect(reported.map(\.1) == [TextSize.default, 30])
    }

    // MARK: Selecting & moving annotations

    @Test func clickingAnAnnotationWithoutToolSelectsIt() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))

        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 50))
        session.mouseUp(on: 1, at: CGPoint(x: 40, y: 50))

        #expect(session.selectedAnnotation?.id == session.document.annotations.first?.id)
        #expect(session.activeSelection == selection)
    }

    @Test func draggingAnAnnotationMovesItNotTheSelection() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))

        // Grab the top edge between handles; at a handle the drag would resize instead.
        TestSessions.drag(session, on: 1, from: CGPoint(x: 47, y: 40), to: CGPoint(x: 67, y: 60))

        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 60, y: 60, width: 30, height: 20)))
        #expect(session.activeSelection == selection)
        #expect(session.document.undoManager.undoActionName == "Move Rectangle")
    }

    @Test func moveIsPreviewedThenCommittedOnce() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))

        session.mouseDown(on: 1, at: CGPoint(x: 47, y: 40))
        session.mouseDragged(on: 1, to: CGPoint(x: 57, y: 40))
        #expect(session.visibleAnnotations.first?.kind == .rectangle(CGRect(x: 50, y: 40, width: 30, height: 20)))
        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 40, y: 40, width: 30, height: 20)))
        session.mouseUp(on: 1, at: CGPoint(x: 57, y: 40))

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
        selectFirstAnnotation(session, at: CGPoint(x: 100, y: 100))

        TestSessions.drag(session, on: 1, from: CGPoint(x: 140, y: 120), to: CGPoint(x: 120, y: 110))

        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 100, y: 80, width: 20, height: 30)))
        #expect(session.activeSelection == selection)
    }

    @Test func aCollapsingResizeKeepsTheLastValidShape() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        selectFirstAnnotation(session, at: CGPoint(x: 40, y: 50))

        TestSessions.drag(session, on: 1, from: CGPoint(x: 70, y: 60), through: [CGPoint(x: 80, y: 70)], to: CGPoint(x: 41, y: 41))

        #expect(session.document.annotations.first?.kind == .rectangle(CGRect(x: 40, y: 40, width: 40, height: 30)))
    }

    @Test func handlesOnlyResizeWithoutATool() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        selectFirstAnnotation(session, at: CGPoint(x: 40, y: 50))
        #expect(session.annotationHandle(on: 1, at: CGPoint(x: 70, y: 60)) == .frame(.bottomRight))
        #expect(session.annotationHandle(on: 2, at: CGPoint(x: 70, y: 60)) == nil)

        session.toggleTool(.line)
        #expect(session.annotationHandle(on: 1, at: CGPoint(x: 70, y: 60)) == nil)
    }

    @Test func draggingATextCornerResizesItsFont() throws {
        let session = makeSession()
        addAndSelectText(session)
        let box = try #require(session.selectedAnnotation).bounds

        TestSessions.drag(session, on: 1, from: CGPoint(x: box.maxX, y: box.maxY), to: CGPoint(x: box.maxX, y: box.minY + box.height * 2))

        #expect(session.document.annotations.first?.style.fontSize == TextSize.default * 2)
        #expect(session.document.undoManager.undoActionName == "Resize Text")
    }

    @Test func handleShowsAResizeCursor() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        selectFirstAnnotation(session, at: CGPoint(x: 40, y: 50))
        #expect(session.cursor(on: 1, at: CGPoint(x: 70, y: 60)) == .resize(.bottomRight))
    }

    @Test func choosingAToolClearsAnnotationSelection() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 50))
        session.mouseUp(on: 1, at: CGPoint(x: 40, y: 50))

        session.toggleTool(.arrow)
        #expect(session.selectedAnnotation == nil)
    }

    @Test func styleChangesApplyToSelectedAnnotation() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 50))
        session.mouseUp(on: 1, at: CGPoint(x: 40, y: 50))

        session.setColor(.green)
        session.setLineWidth(2)

        #expect(session.document.annotations.first?.style == AnnotationStyle(color: .green, lineWidth: 2))
        session.undo()
        #expect(session.document.annotations.first?.style == AnnotationStyle(color: .green, lineWidth: 4))
    }

    @Test func deleteRemovesSelectedAnnotation() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        selectFirstAnnotation(session, at: CGPoint(x: 100, y: 100))  // empty: deselects
        #expect(!session.deleteSelectedAnnotation())

        selectFirstAnnotation(session, at: CGPoint(x: 47, y: 40))
        #expect(session.deleteSelectedAnnotation())
        #expect(session.document.annotations.isEmpty)
        #expect(session.selectedAnnotation == nil)
    }

    @Test func undoingTheSelectedAnnotationClearsSelection() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))
        session.mouseDown(on: 1, at: CGPoint(x: 40, y: 50))
        session.mouseUp(on: 1, at: CGPoint(x: 40, y: 50))

        session.undo()
        #expect(session.selectedAnnotation == nil)
    }

    // MARK: Protecting annotations

    @Test func clickOutsideKeepsAnnotatedSelection() {
        let session = makeSession()
        drawRectangle(session, CGRect(x: 40, y: 40, width: 30, height: 20))

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
