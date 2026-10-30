import AppKit
import Testing

@testable import QuickSnip

/// The overlay's style panel and its dropdowns: placement, picking, closing, keyboard focus.
@MainActor
struct SelectionOverlayViewStyleTests {
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 1000, height: 700), scale: 1)

    private struct Harness {
        let view: SelectionOverlayView
        let session: CaptureSession
        let window: NSWindow
    }

    private func make(
        selection: CGRect = CGRect(x: 100, y: 100, width: 800, height: 300),
        onCommand: @escaping @MainActor (OverlayCommand) -> Void = { _ in }
    ) -> Harness {
        let session = CaptureSession(displays: [display])
        let view = SelectionOverlayView(
            display: display, session: session, fontFamilies: FakeFontFamilies(availableFamilies: ["Helvetica", "Menlo"]),
            onCommand: onCommand)
        session.onChange = { view.sessionDidChange() }
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: true)
        window.contentView = view
        TestSessions.select(session, on: 1, selection)
        return Harness(view: view, session: session, window: window)
    }

    private func key(_ characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0,
                context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode
            ))
    }

    // MARK: Panel

    @Test func noPanelWithoutAToolOrSelectedAnnotation() {
        let harness = make()
        #expect(harness.view.stylePanel?.isHidden ?? true)
        harness.session.toggleTool(.pixelate)
        #expect(harness.view.stylePanel?.isHidden ?? true)
    }

    @Test func panelSitsBesideTheToolbarOnAWideSelection() throws {
        let harness = make()
        harness.session.toggleTool(.arrow)

        let panel = try #require(harness.view.stylePanel)
        let toolbar = try #require(harness.view.toolbar)
        #expect(!panel.isHidden)
        #expect(panel.frame.maxX <= toolbar.frame.minX)
        #expect(panel.frame.minY == toolbar.frame.minY)
        #expect(harness.view.cursor(at: CGPoint(x: panel.frame.midX, y: panel.frame.midY)) == .arrow)
    }

    @Test func panelStacksUnderTheToolbarOnANarrowSelection() throws {
        let harness = make(selection: CGRect(x: 500, y: 100, width: 200, height: 200))
        harness.session.toggleTool(.arrow)

        let panel = try #require(harness.view.stylePanel)
        let toolbar = try #require(harness.view.toolbar)
        #expect(panel.frame.minY >= toolbar.frame.maxY)
    }

    @Test func panelShowsTheShapeJustDrawn() throws {
        let harness = make()
        harness.session.setLineWidth(12)
        harness.session.toggleTool(.rectangle)
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 200, y: 150), to: CGPoint(x: 300, y: 250))

        let panel = try #require(harness.view.stylePanel)
        #expect(!panel.isHidden)
        #expect(panel.buttons[.lineWidth]?.title == "12 px")
    }

    // MARK: Dropdowns

    @Test func pickingAWidthAppliesItAndCloses() throws {
        let harness = make()
        harness.session.toggleTool(.pen)
        harness.view.toggleDropdown(.lineWidth)
        let list = try #require(harness.view.dropdown?.panel)
        #expect(list.values == LineWidth.presets.map(StyleValue.lineWidth))
        #expect(harness.view.stylePanel?.buttons[.lineWidth]?.isOpen == true)

        list.moveSelection(by: 2)  // 4 → 8 px
        list.pickSelected()

        #expect(harness.session.style.lineWidth == 8)
        #expect(harness.view.dropdown == nil)
        #expect(harness.view.stylePanel?.buttons[.lineWidth]?.isOpen == false)
    }

    @Test func fontDropdownListsCuratedThenInstalledFontsAndSearches() throws {
        let harness = make()
        harness.session.toggleTool(.text)
        harness.view.toggleDropdown(.font)
        let list = try #require(harness.view.dropdown?.panel)
        #expect(list.values == TextFont.curated.map(StyleValue.font) + [.font(.family("Helvetica")), .font(.family("Menlo"))])
        #expect(harness.window.firstResponder === list.searchField?.currentEditor())

        list.search("men")
        list.pickSelected()

        #expect(harness.session.style.font == .family("Menlo"))
    }

    @Test func sizeDropdownSetsTheSize() throws {
        let harness = make()
        harness.session.toggleTool(.text)
        harness.view.toggleDropdown(.fontSize)
        let list = try #require(harness.view.dropdown?.panel)
        #expect(list.searchField == nil)

        list.search("48")
        list.pickSelected()

        #expect(harness.session.style.fontSize == 48)
    }

    @Test func togglingTheOpenDropdownClosesIt() {
        let harness = make()
        harness.session.toggleTool(.text)
        harness.view.toggleDropdown(.font)
        harness.view.toggleDropdown(.font)
        #expect(harness.view.dropdown == nil)
        harness.view.toggleDropdown(.font)
        harness.view.toggleDropdown(.fontSize)
        #expect(harness.view.dropdown?.list == .fontSize)
    }

    @Test func dropdownHangsUnderItsButton() throws {
        let harness = make(selection: CGRect(x: 100, y: 50, width: 800, height: 150))
        harness.session.toggleTool(.text)
        harness.view.toggleDropdown(.fontSize)
        let list = try #require(harness.view.dropdown?.panel)
        let button = try #require(harness.view.stylePanel?.buttons[.fontSize])
        let anchor = harness.view.convert(button.bounds, from: button)

        #expect(list.frame.minX == anchor.minX)
        #expect(list.frame.minY == anchor.maxY + StylePanelLayout.gap)
    }

    @Test func dropdownOpensAboveItsButtonWithoutRoomBelow() throws {
        let harness = make(selection: CGRect(x: 100, y: 100, width: 800, height: 300))
        harness.session.toggleTool(.text)
        harness.view.toggleDropdown(.fontSize)
        let list = try #require(harness.view.dropdown?.panel)
        let button = try #require(harness.view.stylePanel?.buttons[.fontSize])

        #expect(list.frame.maxY == harness.view.convert(button.bounds, from: button).minY - StylePanelLayout.gap)
        #expect(harness.view.bounds.contains(list.frame))
    }

    @Test func escapeClosesTheDropdownBeforeCancelling() throws {
        var received: [OverlayCommand] = []
        let harness = make { received.append($0) }
        harness.session.toggleTool(.arrow)
        harness.view.toggleDropdown(.lineWidth)
        harness.window.makeFirstResponder(harness.view)

        harness.view.keyDown(with: try key("\u{1B}", keyCode: 53))
        #expect(harness.view.dropdown == nil)
        #expect(received.isEmpty)

        harness.view.keyDown(with: try key("\u{1B}", keyCode: 53))
        #expect(received == [.cancel])
    }

    @Test func clickOutsideOnlyClosesTheDropdown() throws {
        let harness = make()
        harness.session.toggleTool(.rectangle)
        harness.view.toggleDropdown(.lineWidth)
        let click = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: CGPoint(x: 300, y: 300), modifierFlags: [], timestamp: 0,
                windowNumber: harness.window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))

        harness.view.mouseDown(with: click)

        #expect(harness.view.dropdown == nil)
        #expect(harness.session.document.annotations.isEmpty)
    }

    @Test func dropdownClosesWhenItsOptionsGoAway() {
        let harness = make()
        harness.session.toggleTool(.text)
        harness.view.toggleDropdown(.font)
        harness.session.toggleTool(.arrow)
        #expect(harness.view.dropdown == nil)
    }

    @Test func shortcutsAreIgnoredWhileSearchingFonts() throws {
        var received: [OverlayCommand] = []
        let harness = make { received.append($0) }
        harness.session.toggleTool(.text)
        harness.view.toggleDropdown(.font)

        _ = harness.view.performKeyEquivalent(with: try key("z", keyCode: 6, modifiers: .command))

        #expect(received.isEmpty)
    }

    // MARK: Text entry

    @Test func textEntryUsesTheChosenFontAndSize() throws {
        let harness = make()
        harness.session.toggleTool(.text)
        harness.session.setFont(.monospaced)
        harness.session.setFontSize(40)

        harness.view.beginTextEntry(at: CGPoint(x: 150, y: 150))

        #expect(try #require(harness.view.textField?.font) == TextFont.monospaced.font(size: 40))
    }
}
