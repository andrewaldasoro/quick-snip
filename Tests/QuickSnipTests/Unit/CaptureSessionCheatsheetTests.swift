import CoreGraphics
import Testing

@testable import QuickSnip

@MainActor
struct CaptureSessionCheatsheetTests {
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)

    @Test func startsHidden() {
        #expect(!CaptureSession(displays: [display]).isShowingCheatsheet)
    }

    @Test func toggleShowsThenHides() {
        let session = CaptureSession(displays: [display])
        session.toggleCheatsheet()
        #expect(session.isShowingCheatsheet)
        session.toggleCheatsheet()
        #expect(!session.isShowingCheatsheet)
    }

    @Test func togglingRedrawsTheOverlay() {
        let session = CaptureSession(displays: [display])
        var changes = 0
        session.onChange = { changes += 1 }
        session.toggleCheatsheet()
        session.hideCheatsheet()
        #expect(changes == 2)
    }

    @Test func hidingWhenHiddenChangesNothing() {
        let session = CaptureSession(displays: [display])
        var changes = 0
        session.onChange = { changes += 1 }
        session.hideCheatsheet()
        #expect(changes == 0)
    }

    @Test func clickClosesCheatsheetWithoutSelecting() {
        let session = CaptureSession(displays: [display])
        session.toggleCheatsheet()

        TestSessions.select(session, on: 1, CGRect(x: 10, y: 10, width: 40, height: 30))

        #expect(!session.isShowingCheatsheet)
        #expect(!session.hasSelection)
    }

    @Test func clickClosesCheatsheetWithoutDrawing() {
        let session = CaptureSession(displays: [display])
        TestSessions.select(session, on: 1, CGRect(x: 10, y: 10, width: 60, height: 50))
        session.toggleTool(.shape)
        session.toggleCheatsheet()

        TestSessions.drag(session, on: 1, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 40, y: 40))

        #expect(session.document.annotations.isEmpty)
    }
}

@MainActor
struct CaptureSessionNoticeTests {
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)

    @Test func showAndClearRedraw() {
        let session = CaptureSession(displays: [display])
        var changes = 0
        session.onChange = { changes += 1 }

        session.showNotice("Hi")
        #expect(session.notice == "Hi")
        session.clearNotice()

        #expect(session.notice == nil)
        #expect(changes == 2)
    }

    @Test func clickClearsTheNotice() {
        let session = CaptureSession(displays: [display])
        session.showNotice("Hi")
        session.mouseDown(on: 1, at: CGPoint(x: 5, y: 5))
        #expect(session.notice == nil)
    }
}
