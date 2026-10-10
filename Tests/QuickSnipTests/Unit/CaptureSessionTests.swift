import CoreGraphics
import Testing

@testable import QuickSnip

@MainActor
struct CaptureSessionTests {
    private let retina = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)
    private let external = TestImages.display(id: 2, frame: CGRect(x: 100, y: 0, width: 120, height: 90), scale: 1)

    private func select(_ session: CaptureSession, on id: CGDirectDisplayID, _ rect: CGRect) {
        session.mouseDown(on: id, at: rect.origin)
        session.mouseDragged(on: id, to: CGPoint(x: rect.maxX, y: rect.maxY))
        session.mouseUp(on: id, at: CGPoint(x: rect.maxX, y: rect.maxY))
    }

    @Test func startsWithoutSelection() {
        let session = CaptureSession(displays: [retina, external])
        #expect(!session.hasSelection)
        #expect(session.activeDisplayID == nil)
        #expect(session.renderedImage() == nil)
    }

    @Test func selectingOnADisplayMakesItActive() {
        let session = CaptureSession(displays: [retina, external])
        select(session, on: 2, CGRect(x: 10, y: 10, width: 20, height: 20))
        #expect(session.activeDisplayID == 2)
        #expect(session.selection(on: 2) == CGRect(x: 10, y: 10, width: 20, height: 20))
        #expect(session.hasSelection)
    }

    @Test func selectingOnAnotherDisplayClearsThePrevious() {
        let session = CaptureSession(displays: [retina, external])
        select(session, on: 1, CGRect(x: 10, y: 10, width: 20, height: 20))
        select(session, on: 2, CGRect(x: 5, y: 5, width: 10, height: 10))
        #expect(session.selection(on: 1) == nil)
        #expect(session.activeDisplayID == 2)
    }

    @Test func dragEventsOnInactiveDisplayAreIgnored() {
        let session = CaptureSession(displays: [retina, external])
        select(session, on: 1, CGRect(x: 10, y: 10, width: 20, height: 20))
        session.mouseDragged(on: 2, to: CGPoint(x: 50, y: 50))
        session.mouseUp(on: 2, at: CGPoint(x: 50, y: 50))
        #expect(session.selection(on: 2) == nil)
        #expect(session.selection(on: 1) == CGRect(x: 10, y: 10, width: 20, height: 20))
    }

    @Test func unknownDisplayIsIgnored() {
        let session = CaptureSession(displays: [retina])
        session.mouseDown(on: 99, at: .zero)
        #expect(session.activeDisplayID == nil)
        #expect(session.hitTest(on: 99, at: .zero) == .outside)
    }

    @Test func notifiesOnEveryChange() {
        let session = CaptureSession(displays: [retina])
        var changes = 0
        session.onChange = { changes += 1 }
        select(session, on: 1, CGRect(x: 10, y: 10, width: 20, height: 20))
        #expect(changes == 3)
    }

    @Test func pixelSizeReflectsDisplayScale() {
        let session = CaptureSession(displays: [retina, external])
        select(session, on: 1, CGRect(x: 10, y: 10, width: 20, height: 15))
        #expect(session.selectionPixelSize(on: 1) == CGSize(width: 40, height: 30))
        select(session, on: 2, CGRect(x: 10, y: 10, width: 20, height: 15))
        #expect(session.selectionPixelSize(on: 2) == CGSize(width: 20, height: 15))
    }

    @Test func renderedImageComesFromActiveDisplay() throws {
        let session = CaptureSession(displays: [retina, external])
        select(session, on: 2, CGRect(x: 7, y: 9, width: 20, height: 15))
        let image = try #require(session.renderedImage())
        #expect(image.width == 20)
        #expect(TestImages.pixel(image, x: 0, y: 0) == RGBA(r: 7, g: 9, b: 0, a: 255))
    }

    @Test func hitTestDelegatesToDisplayEditor() {
        let session = CaptureSession(displays: [retina])
        select(session, on: 1, CGRect(x: 10, y: 10, width: 40, height: 40))
        #expect(session.hitTest(on: 1, at: CGPoint(x: 30, y: 30)) == .inside)
        #expect(session.hitTest(on: 1, at: CGPoint(x: 10, y: 10)) == .handle(.topLeft))
    }
}
