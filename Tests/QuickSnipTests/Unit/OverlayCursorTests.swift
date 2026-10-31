import AppKit
import Testing

@testable import QuickSnip

struct OverlayCursorTests {
    private func resolve(
        hit: SelectionHit = .outside,
        annotationHandle: AnnotationHandle? = nil,
        tool: AnnotationTool? = nil,
        inside: Bool = false,
        overAnnotation: Bool = false,
        hasAnnotations: Bool = false,
        moving: Bool = false
    ) -> OverlayCursor {
        OverlayCursor.resolve(
            hit: hit, annotationHandle: annotationHandle, tool: tool, insideSelection: inside, overAnnotation: overAnnotation,
            hasAnnotations: hasAnnotations, isMoving: moving
        )
    }

    @Test func noSelectionShowsCrosshair() {
        #expect(resolve() == .crosshair)
    }

    @Test func handlesShowResizeCursorsEvenWithATool() {
        #expect(resolve(hit: .handle(.topLeft)) == .resize(.topLeft))
        #expect(resolve(hit: .handle(.right), tool: .pen) == .resize(.right))
    }

    @Test func annotationHandlesShowResizeOrCrosshair() {
        #expect(resolve(hit: .inside, annotationHandle: .frame(.left), inside: true) == .resize(.left))
        #expect(resolve(hit: .handle(.top), annotationHandle: .end, inside: true) == .crosshair)
    }

    @Test func insideWithoutToolShowsOpenHand() {
        #expect(resolve(hit: .inside, inside: true) == .openHand)
        #expect(resolve(hit: .inside, inside: true, overAnnotation: true) == .openHand)
    }

    @Test func movingShowsClosedHand() {
        #expect(resolve(hit: .inside, inside: true, moving: true) == .closedHand)
    }

    @Test func drawingToolsShowCrosshairInsideAndArrowOutside() {
        #expect(resolve(hit: .inside, tool: .shape, inside: true) == .crosshair)
        #expect(resolve(tool: .shape) == .arrow)
    }

    @Test func textToolShowsIBeamInside() {
        #expect(resolve(hit: .inside, tool: .text, inside: true) == .iBeam)
    }

    @Test func outsideAnnotatedSelectionShowsArrow() {
        // Clicking there won't start a new selection, so don't promise one.
        #expect(resolve(hasAnnotations: true) == .arrow)
    }

    @Test func everyCursorMapsToAnNSCursor() {
        let cursors: [OverlayCursor] =
            [.crosshair, .arrow, .iBeam, .openHand, .closedHand]
            + SelectionHandle.allCases.map { .resize($0) }
        for cursor in cursors {
            _ = cursor.nsCursor
        }
        #expect(OverlayCursor.resize(.left).nsCursor !== OverlayCursor.resize(.top).nsCursor)
    }
}

@MainActor
struct CaptureSessionCursorTests {
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 200, height: 150), scale: 1)

    @Test func cursorFollowsSessionState() {
        let session = CaptureSession(displays: [display])
        #expect(session.cursor(on: 1, at: CGPoint(x: 50, y: 50)) == .crosshair)

        TestSessions.select(session, on: 1, CGRect(x: 20, y: 20, width: 100, height: 80))
        #expect(session.cursor(on: 1, at: CGPoint(x: 70, y: 60)) == .openHand)
        #expect(session.cursor(on: 1, at: CGPoint(x: 20, y: 20)) == .resize(.topLeft))

        session.toggleTool(.text)
        #expect(session.cursor(on: 1, at: CGPoint(x: 70, y: 60)) == .iBeam)
    }

    @Test func movingSelectionShowsClosedHand() {
        let session = CaptureSession(displays: [display])
        TestSessions.select(session, on: 1, CGRect(x: 20, y: 20, width: 100, height: 80))
        session.mouseDown(on: 1, at: CGPoint(x: 70, y: 60))
        session.mouseDragged(on: 1, to: CGPoint(x: 75, y: 60))
        #expect(session.cursor(on: 1, at: CGPoint(x: 75, y: 60)) == .closedHand)
    }

    @Test func outputScaleFollowsActiveDisplay() {
        let retina = TestImages.display(id: 2, frame: CGRect(x: 200, y: 0, width: 100, height: 100), scale: 2)
        let session = CaptureSession(displays: [display, retina])
        #expect(session.outputScale == 1)
        TestSessions.select(session, on: 2, CGRect(x: 10, y: 10, width: 20, height: 20))
        #expect(session.outputScale == 2)
    }
}
