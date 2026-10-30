import AppKit
import Testing

@testable import QuickSnip

/// The overlay's text styling: the field's font, the font list, and keyboard focus.
@MainActor
struct SelectionOverlayViewFontTests {
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 800, height: 600), scale: 1)

    private struct Harness {
        let view: SelectionOverlayView
        let session: CaptureSession
        let window: NSWindow
    }

    private func make(onCommand: @escaping @MainActor (OverlayCommand) -> Void = { _ in }) -> Harness {
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(
            display: display, session: session, fontFamilies: FakeFontFamilies(availableFamilies: ["Helvetica", "Menlo"]),
            onCommand: onCommand)
        session.onChange = { view.sessionDidChange() }
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: true)
        window.contentView = view
        TestSessions.select(session, on: 1, CGRect(x: 100, y: 100, width: 300, height: 200))
        session.toggleTool(.text)
        return Harness(view: view, session: session, window: window)
    }

    private func key(_ characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0,
                context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode
            ))
    }

    @Test func textEntryUsesTheChosenFontAndSize() throws {
        let harness = make()
        harness.session.setFont(.monospaced)
        harness.session.setFontSize(40)

        harness.view.beginTextEntry(at: CGPoint(x: 150, y: 150))

        let font = try #require(harness.view.textField?.font)
        #expect(font == TextFont.monospaced.font(size: 40))
    }

    @Test func toolbarShowsTextControlsForTheTextTool() throws {
        let harness = make()
        let toolbar = try #require(harness.view.toolbar)
        #expect(!toolbar.textRow.isHidden)
        harness.session.toggleTool(.text)
        #expect(toolbar.textRow.isHidden)
    }

    @Test func moreFontsOpensTheListNextToTheToolbar() throws {
        let harness = make()
        harness.view.toggleFontList()

        let list = try #require(harness.view.fontList)
        #expect(list.families == ["Helvetica", "Menlo"])
        #expect(list.superview === harness.view)
        #expect(harness.view.bounds.contains(list.frame))
        #expect(harness.view.toolbar?.moreFontsButton?.state == .on)
        #expect(harness.view.cursor(at: CGPoint(x: list.frame.midX, y: list.frame.midY)) == .arrow)
    }

    @Test func pickingAFamilySetsItAndCloses() throws {
        let harness = make()
        harness.view.toggleFontList()
        let list = try #require(harness.view.fontList)

        list.search("men")
        list.pickSelected()

        #expect(harness.session.style.font == .family("Menlo"))
        #expect(harness.view.fontList == nil)
    }

    @Test func moreFontsAgainCloses() {
        let harness = make()
        harness.view.toggleFontList()
        harness.view.toggleFontList()
        #expect(harness.view.fontList == nil)
    }

    @Test func escapeClosesTheListBeforeCancelling() throws {
        var received: [OverlayCommand] = []
        let harness = make { received.append($0) }
        harness.view.toggleFontList()
        harness.window.makeFirstResponder(harness.view)

        harness.view.keyDown(with: try key("\u{1B}", keyCode: 53))
        #expect(harness.view.fontList == nil)
        #expect(received.isEmpty)

        harness.view.keyDown(with: try key("\u{1B}", keyCode: 53))
        #expect(received == [.cancel])
    }

    @Test func clickOutsideOnlyClosesTheList() throws {
        let harness = make()
        harness.view.toggleFontList()
        let click = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: CGPoint(x: 150, y: 450), modifierFlags: [], timestamp: 0,
                windowNumber: harness.window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))

        harness.view.mouseDown(with: click)

        #expect(harness.view.fontList == nil)
        #expect(harness.view.textField == nil)
    }

    @Test func listClosesWhenTextIsNoLongerStyled() {
        let harness = make()
        harness.view.toggleFontList()
        harness.session.toggleTool(.rectangle)
        #expect(harness.view.fontList == nil)
    }

    @Test func shortcutsAreIgnoredWhileTypingASize() throws {
        var received: [OverlayCommand] = []
        let harness = make { received.append($0) }
        let field = try #require(harness.view.toolbar?.fontSizeControl?.field)
        #expect(harness.window.makeFirstResponder(field))

        _ = harness.view.performKeyEquivalent(with: try key("z", keyCode: 6, modifiers: .command))

        #expect(received.isEmpty)
    }

    @Test func toolbarTextActionsReachTheSession() throws {
        let harness = make()
        let toolbar = try #require(harness.view.toolbar)
        toolbar.fontButtons[.serif]?.performClick(nil)
        let stepper = try #require(toolbar.fontSizeControl?.stepper)
        stepper.doubleValue = 30
        _ = stepper.sendAction(stepper.action, to: stepper.target)

        #expect(harness.session.style.font == .serif)
        #expect(harness.session.style.fontSize == 30)
        #expect(harness.window.firstResponder === harness.view)
    }
}
