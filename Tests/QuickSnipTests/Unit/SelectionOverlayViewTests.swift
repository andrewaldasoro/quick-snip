import AppKit
import Testing
@testable import QuickSnip

@MainActor
struct SelectionOverlayViewTests {
    private let white = RGBA(r: 255, g: 255, b: 255, a: 255)

    private func makeView(onCommand: @escaping @MainActor (OverlayCommand) -> Void = { _ in })
        -> (SelectionOverlayView, CaptureSession) {
        let image = TestImages.solidImage(width: 100, height: 80, color: white)
        let display = CapturedDisplay(displayID: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), image: image)
        let session = CaptureSession(displays: [display])
        return (SelectionOverlayView(display: display, session: session, onCommand: onCommand), session)
    }

    private func render(_ view: NSView) throws -> CGImage {
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        return try #require(rep.cgImage)
    }

    @Test func viewIsFlippedAndSizedToDisplay() {
        let (view, _) = makeView()
        #expect(view.isFlipped)
        #expect(view.frame == CGRect(x: 0, y: 0, width: 100, height: 80))
        #expect(view.acceptsFirstResponder)
    }

    @Test func everythingDimmedWithoutSelection() throws {
        let (view, _) = makeView()
        let image = try render(view)
        let center = TestImages.pixel(image, x: image.width / 2, y: image.height / 2)
        #expect(center.r < 200)
    }

    @Test func selectionIsUndimmedAndOutsideIsDimmed() throws {
        let (view, session) = makeView()
        session.mouseDown(on: 1, at: CGPoint(x: 20, y: 20))
        session.mouseUp(on: 1, at: CGPoint(x: 80, y: 60))

        let image = try render(view)
        let scale = image.width / 100
        // Bottom-right of the selection, clear of the size label (drawn inside near the top-left).
        let inside = TestImages.pixel(image, x: 75 * scale, y: 55 * scale)
        let outside = TestImages.pixel(image, x: 5 * scale, y: 5 * scale)

        #expect(inside == white)
        #expect(outside.r < 200)
    }

    @Test func selectionIsDrawnTopDown() throws {
        // Selection in the bottom half (flipped coordinates) must render in the bottom half.
        // If y were inverted it would cover y 5…40 instead.
        let (view, session) = makeView()
        session.mouseDown(on: 1, at: CGPoint(x: 20, y: 40))
        session.mouseUp(on: 1, at: CGPoint(x: 80, y: 75))

        let image = try render(view)
        let scale = image.width / 100
        #expect(TestImages.pixel(image, x: 70 * scale, y: 70 * scale) == white)
        #expect(TestImages.pixel(image, x: 70 * scale, y: 8 * scale).r < 200)
    }

    @Test func keyDownSendsCommand() throws {
        var received: [OverlayCommand] = []
        let (view, _) = makeView { received.append($0) }
        let escape = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53
        ))
        view.keyDown(with: escape)
        #expect(received == [.cancel])
    }

    @Test func keyEquivalentSendsCommandAndIsConsumed() throws {
        var received: [OverlayCommand] = []
        let (view, _) = makeView { received.append($0) }
        let copy = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: 0,
            context: nil, characters: "c", charactersIgnoringModifiers: "c", isARepeat: false, keyCode: 8
        ))
        #expect(view.performKeyEquivalent(with: copy))
        #expect(received == [.copy])
    }

    @Test func unrelatedKeyEquivalentIsNotConsumed() throws {
        var received: [OverlayCommand] = []
        let (view, _) = makeView { received.append($0) }
        let other = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: 0,
            context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0
        ))
        #expect(!view.performKeyEquivalent(with: other))
        #expect(received.isEmpty)
    }
}
