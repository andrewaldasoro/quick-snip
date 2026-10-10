import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct SelectionOverlayViewTests {
    private let white = RGBA(r: 255, g: 255, b: 255, a: 255)

    private func makeView(onCommand: @escaping @MainActor (OverlayCommand) -> Void = { _ in })
        -> (SelectionOverlayView, CaptureSession)
    {
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
        let escape = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53
            ))
        view.keyDown(with: escape)
        #expect(received == [.cancel])
    }

    @Test func keyEquivalentSendsCommandAndIsConsumed() throws {
        var received: [OverlayCommand] = []
        let (view, _) = makeView { received.append($0) }
        let copy = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: 0,
                context: nil, characters: "c", charactersIgnoringModifiers: "c", isARepeat: false, keyCode: 8
            ))
        #expect(view.performKeyEquivalent(with: copy))
        #expect(received == [.copy])
    }

    @Test func unrelatedKeyEquivalentIsNotConsumed() throws {
        var received: [OverlayCommand] = []
        let (view, _) = makeView { received.append($0) }
        let other = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: 0,
                context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0
            ))
        #expect(!view.performKeyEquivalent(with: other))
        #expect(received.isEmpty)
    }
}

@MainActor
@Suite(.serialized)
struct SelectionOverlayViewEditingTests {
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 480, height: 300), scale: 1)

    private func makeView() -> (SelectionOverlayView, CaptureSession) {
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(display: display, session: session) { _ in }
        session.onChange = { view.sessionDidChange() }
        session.onRequestTextEntry = { _, point in view.beginTextEntry(at: point) }
        return (view, session)
    }

    @Test func toolbarAppearsBelowSelectionAfterSelecting() throws {
        let (view, session) = makeView()
        #expect(view.toolbar == nil)

        TestSessions.select(session, on: 1, CGRect(x: 50, y: 50, width: 200, height: 100))

        let toolbar = try #require(view.toolbar)
        #expect(!toolbar.isHidden)
        #expect(toolbar.frame.minY >= 150)
        #expect(view.bounds.contains(toolbar.frame))
    }

    @Test func toolbarHidesWhileSelectionIsDragged() throws {
        let (view, session) = makeView()
        TestSessions.select(session, on: 1, CGRect(x: 50, y: 50, width: 200, height: 100))

        session.mouseDown(on: 1, at: CGPoint(x: 250, y: 150))
        session.mouseDragged(on: 1, to: CGPoint(x: 260, y: 160))
        #expect(try #require(view.toolbar).isHidden)

        session.mouseUp(on: 1, at: CGPoint(x: 260, y: 160))
        #expect(try #require(view.toolbar).isHidden == false)
    }

    @Test func toolbarReflectsToolAndUndoState() throws {
        let (view, session) = makeView()
        TestSessions.select(session, on: 1, CGRect(x: 50, y: 50, width: 200, height: 100))
        session.toggleTool(.rectangle)
        TestSessions.drag(session, on: 1, from: CGPoint(x: 60, y: 60), to: CGPoint(x: 100, y: 100))

        let toolbar = try #require(view.toolbar)
        #expect(toolbar.toolButtons[.rectangle]?.state == .on)
        #expect(toolbar.commandButtons[.undo]?.isEnabled == true)
    }

    @Test func toolbarButtonsDriveTheSession() throws {
        let (view, session) = makeView()
        TestSessions.select(session, on: 1, CGRect(x: 50, y: 50, width: 200, height: 100))
        try #require(view.toolbar).toolButtons[.arrow]?.performClick(nil)
        #expect(session.tool == .arrow)
    }

    @Test func textEntryCommitsAnAnnotation() throws {
        let (view, session) = makeView()
        TestSessions.select(session, on: 1, CGRect(x: 50, y: 50, width: 200, height: 100))
        session.toggleTool(.text)
        session.mouseDown(on: 1, at: CGPoint(x: 80, y: 90))

        let field = try #require(view.textField)
        #expect(field.frame.minX == 80 - SelectionOverlayView.textFieldInset)
        field.stringValue = "Note"
        view.commitTextEntry()

        #expect(view.textField == nil)
        #expect(field.superview == nil)
        #expect(session.document.annotations.map(\.kind) == [.text("Note", origin: CGPoint(x: 80, y: 90))])
    }

    @Test func cancelledTextEntryAddsNothing() throws {
        let (view, session) = makeView()
        TestSessions.select(session, on: 1, CGRect(x: 50, y: 50, width: 200, height: 100))
        session.toggleTool(.text)
        session.mouseDown(on: 1, at: CGPoint(x: 80, y: 90))

        try #require(view.textField).stringValue = "Draft"
        view.cancelTextEntry()

        #expect(view.textField == nil)
        #expect(session.document.annotations.isEmpty)
    }

    @Test func startingNewTextEntryCommitsThePrevious() throws {
        let (view, session) = makeView()
        TestSessions.select(session, on: 1, CGRect(x: 50, y: 50, width: 200, height: 100))
        view.beginTextEntry(at: CGPoint(x: 80, y: 90))
        try #require(view.textField).stringValue = "One"
        view.beginTextEntry(at: CGPoint(x: 80, y: 120))

        #expect(session.document.annotations.count == 1)
        #expect(view.textField != nil)
    }

    @Test func shortcutsGoToTheTextFieldWhileTyping() throws {
        var received: [OverlayCommand] = []
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(display: display, session: session) { received.append($0) }
        TestSessions.select(session, on: 1, CGRect(x: 50, y: 50, width: 200, height: 100))
        view.beginTextEntry(at: CGPoint(x: 80, y: 90))

        let copy = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: 0,
                context: nil, characters: "c", charactersIgnoringModifiers: "c", isARepeat: false, keyCode: 8
            ))
        _ = view.performKeyEquivalent(with: copy)
        #expect(received.isEmpty)
    }

    @Test func annotationsAreDrawnOnTheOverlay() throws {
        let (view, session) = makeView()
        TestSessions.select(session, on: 1, CGRect(x: 50, y: 50, width: 200, height: 100))
        session.toggleTool(.rectangle)
        TestSessions.drag(session, on: 1, from: CGPoint(x: 100, y: 70), to: CGPoint(x: 160, y: 130))
        view.toolbar?.isHidden = true

        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = try #require(rep.cgImage)
        let scale = image.width / 480
        #expect(TestImages.pixel(image, x: 100 * scale, y: 100 * scale).isClose(to: .red, tolerance: 60))
    }
}

@MainActor
struct SelectionOverlayViewCursorTests {
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 800, height: 600), scale: 1)

    @Test func toolbarAreaGetsArrowCursor() throws {
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(display: display, session: session) { _ in }
        session.onChange = { view.sessionDidChange() }
        TestSessions.select(session, on: 1, CGRect(x: 100, y: 100, width: 300, height: 200))

        let toolbar = try #require(view.toolbar)
        #expect(view.cursor(at: CGPoint(x: toolbar.frame.midX, y: toolbar.frame.midY)) == .arrow)
        #expect(view.cursor(at: CGPoint(x: 250, y: 200)) == .openHand)
    }

    @Test func overlayIsAccessible() {
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(display: display, session: session) { _ in }
        #expect(view.isAccessibilityElement())
        #expect(view.accessibilityLabel() == "Screenshot area selection")
        #expect(view.accessibilityHelp()?.contains("Escape cancels") == true)
    }

    @Test func tracksMouseMovementForCursorUpdates() {
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(display: display, session: session) { _ in }
        view.updateTrackingAreas()
        #expect(view.trackingAreas.contains { $0.options.contains(.mouseMoved) && $0.options.contains(.cursorUpdate) })
    }
}
