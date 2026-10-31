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

    @Test func hoveredWindowIsUndimmed() throws {
        let image = TestImages.solidImage(width: 100, height: 80, color: white)
        let window = CGRect(x: 40, y: 30, width: 50, height: 40)
        let snap = SnapWindow(id: 1, frame: window, visibleFrame: window)
        let display = CapturedDisplay(displayID: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), image: image, windows: [snap])
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(display: display, session: session) { _ in }

        session.mouseMoved(on: 1, to: CGPoint(x: 60, y: 50))

        let rendered = try render(view)
        let scale = rendered.width / 100
        #expect(TestImages.pixel(rendered, x: 65 * scale, y: 50 * scale) == white)
        #expect(TestImages.pixel(rendered, x: 10 * scale, y: 10 * scale).r < 200)
        #expect(TestImages.pixel(rendered, x: 40 * scale + 1, y: 50 * scale) != white)  // the outline
    }

    @Test func mouseMovesReachTheSession() throws {
        let image = TestImages.solidImage(width: 100, height: 80, color: white)
        let window = CGRect(x: 40, y: 30, width: 50, height: 40)
        let snap = SnapWindow(id: 1, frame: window, visibleFrame: window)
        let display = CapturedDisplay(displayID: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), image: image, windows: [snap])
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(display: display, session: session) { _ in }
        // y 40 is the vertical middle, so it's the same point flipped or not.
        let event = try #require(
            NSEvent.mouseEvent(
                with: .mouseMoved, location: CGPoint(x: 60, y: 40), modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
                eventNumber: 0, clickCount: 0, pressure: 0))

        view.mouseMoved(with: event)

        #expect(session.hoveredWindow(on: 1) == window)
    }

    @Test func drawsTheWindowBroughtToFront() throws {
        let (view, session) = makeView()
        let window = SnapWindow(
            id: 1, frame: CGRect(x: 20, y: 20, width: 60, height: 40), visibleFrame: CGRect(x: 20, y: 20, width: 60, height: 40))
        TestSessions.select(session, on: 1, CGRect(x: 10, y: 10, width: 80, height: 60))
        let red = RGBA(r: 255, g: 0, b: 0, a: 255)

        session.bringToFront(window, image: TestImages.solidImage(width: 60, height: 40, color: red), on: 1)

        let rendered = try render(view)
        let scale = rendered.width / 100
        let pixel = TestImages.pixel(rendered, x: 70 * scale, y: 50 * scale)
        #expect(pixel.r > 200 && pixel.g < 60, "drawn through color management, so only roughly red")
        #expect(view.display.image === session.display(1)?.image)
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
    /// Wide enough for the one-row toolbar (480 pt) and its margins.
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 640, height: 300), scale: 1)

    private func makeView() -> (SelectionOverlayView, CaptureSession) {
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(display: display, session: session) { _ in }
        session.onChange = { view.sessionDidChange() }
        session.onRequestTextEntry = { _, request in view.beginTextEntry(request) }
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
        #expect(toolbar.toolButtons[.rectangle]?.state == .off)  // off once the shape is drawn
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
        TestSessions.drag(session, on: 1, from: CGPoint(x: 80, y: 90), to: CGPoint(x: 80, y: 90))  // a click

        let editor = try #require(view.textEditor)
        #expect(editor.frame.minX == 80)
        editor.string = "Note"
        view.commitTextEntry()

        #expect(view.textEditor == nil)
        #expect(editor.superview == nil)
        #expect(session.document.annotations.map(\.kind) == [.text("Note", origin: CGPoint(x: 80, y: 90))])
    }

    @Test func emptyTextEntryAddsNothing() throws {
        let (view, session) = makeView()
        TestSessions.select(session, on: 1, CGRect(x: 50, y: 50, width: 200, height: 100))
        session.toggleTool(.text)
        TestSessions.drag(session, on: 1, from: CGPoint(x: 80, y: 90), to: CGPoint(x: 80, y: 90))  // a click

        view.commitTextEntry()

        #expect(view.textEditor == nil)
        #expect(session.document.annotations.isEmpty)
    }

    @Test func startingNewTextEntryCommitsThePrevious() throws {
        let (view, session) = makeView()
        TestSessions.select(session, on: 1, CGRect(x: 50, y: 50, width: 200, height: 100))
        view.beginTextEntry(.new(at: .line(at: CGPoint(x: 80, y: 90)), style: .default))
        try #require(view.textEditor).string = "One"
        view.beginTextEntry(.new(at: .line(at: CGPoint(x: 80, y: 120)), style: .default))

        #expect(session.document.annotations.count == 1)
        #expect(view.textEditor != nil)
    }

    @Test func shortcutsGoToTheTextWhileTyping() throws {
        var received: [OverlayCommand] = []
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(display: display, session: session) { received.append($0) }
        TestSessions.select(session, on: 1, CGRect(x: 50, y: 50, width: 200, height: 100))
        view.beginTextEntry(.new(at: .line(at: CGPoint(x: 80, y: 90)), style: .default))

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
        let scale = image.width / 640
        // On the left edge, clear of the selected shape's handles.
        #expect(TestImages.pixel(image, x: 100 * scale, y: 85 * scale).isClose(to: .red, tolerance: 60))
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

@MainActor
struct SelectionOverlayViewCheatsheetTests {
    private let display = CapturedDisplay(
        displayID: 1,
        frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
        image: TestImages.solidImage(width: 1200, height: 800, color: RGBA(r: 255, g: 255, b: 255, a: 255))
    )

    private func render(_ view: NSView) throws -> CGImage {
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        return try #require(rep.cgImage)
    }

    /// Brightness of a pixel inside the panel, clear of its text and rounded corners.
    private func brightnessInsidePanel(of view: NSView) throws -> Int {
        let image = try render(view)
        let scale = image.width / Int(view.bounds.width)
        let frame = CheatsheetPanel(cheatsheet: .overlay).frame(in: view.bounds)
        let pixel = TestImages.pixel(image, x: (Int(frame.minX) + 8) * scale, y: (Int(frame.midY)) * scale)
        return Int(pixel.r)
    }

    @Test func cheatsheetIsDrawnWhenShown() throws {
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(display: display, session: session) { _ in }
        let dimmed = try brightnessInsidePanel(of: view)

        session.toggleCheatsheet()

        #expect(try brightnessInsidePanel(of: view) < dimmed / 2)
    }

    @Test func toolbarHidesWhileCheatsheetIsShown() throws {
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(display: display, session: session) { _ in }
        session.onChange = { view.sessionDidChange() }
        TestSessions.select(session, on: 1, CGRect(x: 100, y: 100, width: 300, height: 200))

        session.toggleCheatsheet()
        #expect(try #require(view.toolbar).isHidden)

        session.toggleCheatsheet()
        #expect(try #require(view.toolbar).isHidden == false)
    }

    @Test func questionMarkKeySendsToggle() throws {
        let session = CaptureSession(displays: [display])
        var commands: [OverlayCommand] = []
        let view = SelectionOverlayView(display: display, session: session) { commands.append($0) }
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: .shift, timestamp: 0, windowNumber: 0,
                context: nil, characters: "?", charactersIgnoringModifiers: "?", isARepeat: false, keyCode: 44
            ))

        view.keyDown(with: event)

        #expect(commands == [.toggleCheatsheet])
    }
}
