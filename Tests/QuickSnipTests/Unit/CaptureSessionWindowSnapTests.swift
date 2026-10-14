import CoreGraphics
import Testing

@testable import QuickSnip

@MainActor
struct CaptureSessionWindowSnapTests {
    private let front = SnapWindow(
        id: 1, frame: CGRect(x: 20, y: 20, width: 30, height: 30), visibleFrame: CGRect(x: 20, y: 20, width: 30, height: 30))
    private let back = SnapWindow(
        id: 2, frame: CGRect(x: 10, y: 10, width: 80, height: 60), visibleFrame: CGRect(x: 10, y: 10, width: 80, height: 60))
    private let red = RGBA(r: 255, g: 0, b: 0, a: 255)

    private func makeSession() -> CaptureSession {
        let builtIn = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)
        let windowed = CapturedDisplay(displayID: 1, frame: builtIn.frame, image: builtIn.image, windows: [front, back])
        let external = TestImages.display(id: 2, frame: CGRect(x: 100, y: 0, width: 120, height: 90), scale: 1)
        return CaptureSession(displays: [windowed, external])
    }

    private func click(_ session: CaptureSession, on id: CGDirectDisplayID = 1, at point: CGPoint) {
        session.mouseDown(on: id, at: point)
        session.mouseUp(on: id, at: point)
    }

    @Test func hoveringHighlightsTheFrontmostWindow() {
        let session = makeSession()
        session.mouseMoved(on: 1, to: CGPoint(x: 25, y: 25))
        #expect(session.hoveredWindow(on: 1) == front.visibleFrame)
        #expect(session.hoveredWindow(on: 2) == nil)
    }

    @Test func hoveringOutsideAnyWindowHighlightsNothing() {
        let session = makeSession()
        session.mouseMoved(on: 1, to: CGPoint(x: 25, y: 25))
        session.mouseMoved(on: 1, to: CGPoint(x: 95, y: 75))
        #expect(session.hoveredWindow(on: 1) == nil)
    }

    @Test func movingWithinTheSameWindowDoesntRedraw() {
        let session = makeSession()
        var changes = 0
        session.onChange = { changes += 1 }
        session.mouseMoved(on: 1, to: CGPoint(x: 25, y: 25))
        session.mouseMoved(on: 1, to: CGPoint(x: 26, y: 27))
        #expect(changes == 1)
    }

    @Test func clickingAWindowSelectsIt() {
        let session = makeSession()
        click(session, at: CGPoint(x: 25, y: 25))
        #expect(session.activeSelection == front.visibleFrame)
        #expect(session.activeDisplayID == 1)
        #expect(session.hoveredWindow(on: 1) == nil)
    }

    @Test func clickingAnUncoveredWindowNeedsNoCapture() {
        let session = makeSession()
        var requested: [SnapWindow] = []
        session.onSnapToCoveredWindow = { _, window in requested.append(window) }
        click(session, at: CGPoint(x: 25, y: 25))
        #expect(requested.isEmpty)
    }

    /// Regression: a covered window's selection showed (and copied) the windows in front of it.
    @Test func clickingACoveredWindowAsksForItsOwnCapture() {
        let session = makeSession()
        var requested: [(CGDirectDisplayID, SnapWindow)] = []
        session.onSnapToCoveredWindow = { id, window in requested.append((id, window)) }
        click(session, at: CGPoint(x: 15, y: 15))
        #expect(session.activeSelection == back.visibleFrame)
        #expect(requested.map(\.0) == [1])
        #expect(requested.map(\.1) == [back])
    }

    @Test func bringingAWindowToFrontShowsItInTheSelection() throws {
        let session = makeSession()
        click(session, at: CGPoint(x: 15, y: 15))
        var changes = 0
        session.onChange = { changes += 1 }

        session.bringToFront(back, image: TestImages.solidImage(width: 160, height: 120, color: red), on: 1)

        let output = try #require(session.renderedImage())
        // Where `front` covered it, too.
        #expect(TestImages.pixel(output, x: 30, y: 30) == red)
        #expect(session.display(1)?.windows.first == back)
        #expect(changes == 1)
    }

    @Test func bringingToFrontOnAnUnknownDisplayChangesNothing() {
        let session = makeSession()
        let before = session.display(1)?.image
        session.bringToFront(back, image: TestImages.solidImage(width: 4, height: 4, color: red), on: 99)
        #expect(session.display(1)?.image === before)
    }

    @Test func clickingOutsideAnyWindowSelectsNothing() {
        let session = makeSession()
        click(session, at: CGPoint(x: 95, y: 75))
        #expect(!session.hasSelection)
    }

    @Test func draggingStillSelectsTheDraggedArea() {
        let session = makeSession()
        TestSessions.select(session, on: 1, CGRect(x: 22, y: 22, width: 10, height: 10))
        #expect(session.activeSelection == CGRect(x: 22, y: 22, width: 10, height: 10))
    }

    @Test func withASelectionHoveringHighlightsNothing() {
        let session = makeSession()
        TestSessions.select(session, on: 1, CGRect(x: 60, y: 60, width: 10, height: 10))
        session.mouseMoved(on: 1, to: CGPoint(x: 25, y: 25))
        #expect(session.hoveredWindow(on: 1) == nil)
    }

    /// With a selection, clicking outside it clears it rather than jumping to a window.
    @Test func withASelectionClickingOutsideClearsIt() {
        let session = makeSession()
        TestSessions.select(session, on: 1, CGRect(x: 60, y: 60, width: 10, height: 10))
        click(session, at: CGPoint(x: 25, y: 25))
        #expect(!session.hasSelection)
    }

    @Test func withTheCheatsheetShownHoveringHighlightsNothing() {
        let session = makeSession()
        session.toggleCheatsheet()
        session.mouseMoved(on: 1, to: CGPoint(x: 25, y: 25))
        #expect(session.hoveredWindow(on: 1) == nil)
    }

    @Test func hoveringAnotherDisplayMovesTheHighlight() {
        let session = makeSession()
        session.mouseMoved(on: 1, to: CGPoint(x: 25, y: 25))
        session.mouseMoved(on: 2, to: CGPoint(x: 25, y: 25))
        #expect(session.hoveredWindow(on: 1) == nil)
    }
}
