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
        harness.session.toggleTool(.shape)
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
        #expect(list.frame.minY == anchor.maxY + DropdownLayout.gap)
    }

    @Test func dropdownOpensAboveItsButtonWithoutRoomBelow() throws {
        let harness = make(selection: CGRect(x: 100, y: 100, width: 800, height: 300))
        harness.session.toggleTool(.text)
        harness.view.toggleDropdown(.fontSize)
        let list = try #require(harness.view.dropdown?.panel)
        let button = try #require(harness.view.stylePanel?.buttons[.fontSize])

        #expect(list.frame.maxY == harness.view.convert(button.bounds, from: button).minY - DropdownLayout.gap)
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
        harness.session.toggleTool(.shape)
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

    // MARK: Colors and alignment

    @Test func colorDropdownColorsWhatsSelected() throws {
        let harness = make()
        harness.session.toggleTool(.shape)
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 200, y: 150), to: CGPoint(x: 300, y: 250))
        let panel = try #require(harness.view.stylePanel)

        harness.view.toggleDropdown(.color)
        let list = try #require(harness.view.dropdown?.panel)
        #expect(list.values == AnnotationColor.allCases.map(StyleValue.color))
        #expect(list.table.selectedRow == AnnotationColor.allCases.firstIndex(of: .red))
        list.moveSelection(by: 3)  // red → green
        list.pickSelected()

        #expect(harness.session.document.annotations.first?.style.color == .green)
        #expect(panel.buttons[.color]?.leadingImage?.accessibilityDescription == "Green")
    }

    @Test func alignmentButtonsAlignText() throws {
        let harness = make()
        harness.session.toggleTool(.text)
        let panel = try #require(harness.view.stylePanel)

        panel.alignmentButtons[.center]?.performClick(nil)

        #expect(harness.session.style.alignment == .center)
        #expect(panel.alignmentButtons[.center]?.state == .on)
    }

    @Test func aTextBoxIsOutlinedWhileDragged() throws {
        let harness = make()
        harness.session.toggleTool(.text)
        harness.session.mouseDown(on: 1, at: CGPoint(x: 200, y: 150))
        harness.session.mouseDragged(on: 1, to: CGPoint(x: 400, y: 180))
        harness.view.toolbar?.isHidden = true
        harness.view.stylePanel?.isHidden = true

        let rep = try #require(harness.view.bitmapImageRepForCachingDisplay(in: harness.view.bounds))
        harness.view.cacheDisplay(in: harness.view.bounds, to: rep)
        let image = try #require(rep.cgImage)
        let scale = image.width / 1000
        let edge = TestImages.pixel(image, x: 300 * scale, y: 150 * scale)
        let inside = TestImages.pixel(image, x: 300 * scale, y: 165 * scale)
        #expect(edge != inside)
    }

    @Test func aDraggedBoxOpensAWrappingField() throws {
        let harness = make()
        harness.session.onRequestTextEntry = { [view = harness.view] _, request in view.beginTextEntry(request) }
        harness.session.toggleTool(.text)
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 200, y: 150), to: CGPoint(x: 400, y: 160))

        let editor = try #require(harness.view.textEditor)
        #expect(harness.view.textEntry?.isBox == true)
        editor.string = "Boxed"
        harness.view.commitTextEntry()

        #expect(harness.session.document.annotations.first?.kind == .text("Boxed", origin: CGPoint(x: 200, y: 150), boxWidth: 200))
    }

    /// Regression: after placing text the Text button stayed lit, because the toolbar redrew
    /// before the tool turned off.
    @Test func placingTextTurnsTheTextButtonOff() throws {
        let harness = make()
        harness.session.toggleTool(.text)
        harness.view.beginTextEntry(.new(at: .line(at: CGPoint(x: 200, y: 150)), style: harness.session.style))
        try #require(harness.view.textEditor).string = "Done"

        harness.view.commitTextEntry()

        #expect(harness.view.toolbar?.toolButtons[.text]?.state == .off)
    }

    /// Regression: panels placed at fractional points rendered blurry.
    @Test func panelsSitOnWholePixels() throws {
        let harness = make(selection: CGRect(x: 100.3, y: 100.6, width: 640.4, height: 200.2))
        harness.session.toggleTool(.text)
        harness.view.toggleDropdown(.fontSize)
        let frames = [harness.view.toolbar?.frame, harness.view.stylePanel?.frame, harness.view.dropdown?.panel.frame].compactMap { $0 }
        #expect(frames.count == 3)
        let scale = harness.window.backingScaleFactor
        for frame in frames {
            let pixels = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)
            #expect(pixels == pixels.integral, "\(frame) at \(scale)×")
        }
    }

    /// Regression: after undoing the last change, Undo stayed enabled (and Redo disabled after
    /// undoing): the toolbar refreshed while the undo was still running.
    @Test func undoAndRedoButtonsFollowWhatsLeft() throws {
        let harness = make()
        harness.session.toggleTool(.shape)
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 200, y: 150), to: CGPoint(x: 300, y: 250))
        let toolbar = try #require(harness.view.toolbar)
        #expect(toolbar.commandButtons[.undo]?.isEnabled == true)
        #expect(toolbar.commandButtons[.redo]?.isEnabled == false)

        harness.session.undo()
        #expect(toolbar.commandButtons[.undo]?.isEnabled == false)
        #expect(toolbar.commandButtons[.redo]?.isEnabled == true)

        harness.session.redo()
        #expect(toolbar.commandButtons[.undo]?.isEnabled == true)
        #expect(toolbar.commandButtons[.redo]?.isEnabled == false)
    }

    /// Clicks a point in the overlay the way AppKit does: the deepest view there gets it, and
    /// a view that doesn't handle it (a disabled button) passes it up the responder chain.
    private func click(_ harness: Harness, at point: CGPoint) throws {
        let inWindow = harness.view.convert(point, to: nil)
        let down = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: inWindow, modifierFlags: [], timestamp: 0, windowNumber: harness.window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        let target = try #require(harness.view.hitTest(harness.view.convert(point, to: harness.view.superview)))
        target.mouseDown(with: down)
    }

    /// Regression: clicking the disabled Undo button reached the capture behind the toolbar,
    /// which started moving the selection: the toolbar vanished and the cursor became a fist.
    @Test func clicksOnADisabledButtonStayInTheToolbar() throws {
        let harness = make()
        let selection = harness.session.activeSelection
        let toolbar = try #require(harness.view.toolbar)
        let undo = try #require(toolbar.commandButtons[.undo])
        #expect(undo.isEnabled == false)

        try click(harness, at: harness.view.convert(CGPoint(x: undo.bounds.midX, y: undo.bounds.midY), from: undo))

        #expect(!harness.session.isEditingSelection)
        #expect(harness.session.activeSelection == selection)
        #expect(!toolbar.isHidden)
    }

    @Test(arguments: [true, false])
    func clicksOnPanelPaddingStayInThePanel(onToolbar: Bool) throws {
        let harness = make()
        harness.session.toggleTool(.arrow)
        let selection = harness.session.activeSelection
        let panel: NSView = try #require(onToolbar ? harness.view.toolbar : harness.view.stylePanel)

        try click(harness, at: CGPoint(x: panel.frame.minX + 3, y: panel.frame.midY))  // the rounded padding

        #expect(!harness.session.isEditingSelection)
        #expect(harness.session.activeSelection == selection)
        #expect(harness.session.tool == .arrow)
    }

    // MARK: Text entry

    @Test func textEntryUsesTheChosenFontAndSize() throws {
        let harness = make()
        harness.session.toggleTool(.text)
        harness.session.setFont(.monospaced)
        harness.session.setFontSize(40)

        harness.session.onRequestTextEntry = { [view = harness.view] _, request in view.beginTextEntry(request) }
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 150, y: 150), to: CGPoint(x: 150, y: 150))

        #expect(try #require(harness.view.textEditor?.font) == TextFont.monospaced.font(size: 40))
    }

    /// The whole loop the user goes through: place text, type two lines, finish, double-click
    /// it, change it, finish again.
    @Test func doubleClickReopensTextToEditInPlace() throws {
        let harness = make()
        harness.session.onRequestTextEntry = { [view = harness.view] _, request in view.beginTextEntry(request) }
        harness.session.toggleTool(.text)
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 200, y: 150), to: CGPoint(x: 200, y: 150))
        let editor = try #require(harness.view.textEditor as? TextEditorView)
        editor.insertText("Line one", replacementRange: editor.selectedRange())
        editor.insertNewline(nil)
        editor.insertText("Line two", replacementRange: editor.selectedRange())
        editor.cancelOperation(nil)  // Esc keeps it
        #expect(harness.view.textEditor == nil)
        #expect(harness.session.document.annotations.first?.kind == .text("Line one\nLine two", origin: CGPoint(x: 200, y: 150)))
        #expect(harness.window.firstResponder === harness.view)

        harness.session.mouseDown(on: 1, at: CGPoint(x: 210, y: 160), clickCount: 2)
        harness.session.mouseUp(on: 1, at: CGPoint(x: 210, y: 160))
        let reopened = try #require(harness.view.textEditor)
        #expect(reopened.string == "Line one\nLine two")
        #expect(reopened.selectedRange() == NSRange(location: 17, length: 0))  // caret at the end
        #expect(harness.session.visibleAnnotations.isEmpty)

        reopened.insertText("!", replacementRange: reopened.selectedRange())
        harness.view.commitTextEntry()

        #expect(harness.session.document.annotations.count == 1)
        #expect(harness.session.document.annotations.first?.kind == .text("Line one\nLine two!", origin: CGPoint(x: 200, y: 150)))
        #expect(harness.session.document.undoManager.undoActionName == "Edit Text")
    }

    /// Regression: while typing new text, picking an alignment only showed once typing ended.
    @Test func alignmentChangesTheTextBeingTyped() throws {
        let harness = make()
        harness.session.onRequestTextEntry = { [view = harness.view] _, request in view.beginTextEntry(request) }
        harness.session.toggleTool(.text)
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 300, y: 150), to: CGPoint(x: 300, y: 150))
        let editor = try #require(harness.view.textEditor)
        editor.insertText("Typing", replacementRange: editor.selectedRange())
        let panel = try #require(harness.view.stylePanel)

        panel.alignmentButtons[.right]?.performClick(nil)

        #expect(harness.view.textEditor === editor)  // still typing
        #expect(editor.alignment == .right)
        #expect(panel.alignmentButtons[.right]?.state == .on)
    }

    /// Regression: right alignment slid text being typed to the left. Click text is a box
    /// anchored on its left edge: it only grows right and down, alignment lines the lines up
    /// inside it, and the box it has when typing ends is the placed text's bounds.
    @Test(arguments: TextAlignment.allCases)
    func clickTextKeepsItsLeftEdgeWhateverTheAlignment(alignment: TextAlignment) throws {
        let harness = make()
        harness.session.onRequestTextEntry = { [view = harness.view] _, request in view.beginTextEntry(request) }
        harness.session.toggleTool(.text)
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 300, y: 150), to: CGPoint(x: 300, y: 150))
        let editor = try #require(harness.view.textEditor)
        editor.insertText("Typing", replacementRange: editor.selectedRange())

        try #require(harness.view.stylePanel).alignmentButtons[alignment]?.performClick(nil)
        #expect(editor.frame.minX == 300)  // realigning doesn't move it
        editor.insertText(" a longer line", replacementRange: editor.selectedRange())
        editor.insertNewline(nil)
        editor.insertText("short", replacementRange: editor.selectedRange())
        #expect(editor.frame.minX == 300)  // growing doesn't either
        let typed = editor.frame

        harness.view.commitTextEntry()
        let placed = try #require(harness.session.document.annotations.first)
        #expect(placed.bounds.minX == 300)
        #expect(placed.bounds.minY == typed.minY)
        #expect(abs(placed.bounds.width - (typed.width - TextEntry.caretRoom)) < 0.5)  // the same box
        #expect(placed.style.alignment == alignment)
    }

    /// Regression: re-editing text with a double-click hid the style panel, since the text
    /// being edited is hidden from the canvas meanwhile.
    @Test func reEditedTextKeepsItsStylePanel() throws {
        let harness = make()
        harness.session.onRequestTextEntry = { [view = harness.view] _, request in view.beginTextEntry(request) }
        harness.session.setColor(.green)
        harness.session.addText("Placed", at: .line(at: CGPoint(x: 300, y: 150)), on: 1)
        let placed = try #require(harness.session.document.annotations.first)
        harness.session.setColor(.red)  // restyles the selected text; set it back to green below

        harness.session.mouseDown(on: 1, at: CGPoint(x: placed.bounds.midX, y: placed.bounds.midY), clickCount: 2)
        harness.session.mouseUp(on: 1, at: CGPoint(x: placed.bounds.midX, y: placed.bounds.midY))
        let panel = try #require(harness.view.stylePanel)
        let editor = try #require(harness.view.textEditor)

        #expect(!panel.isHidden)
        #expect(Set(panel.buttons.keys) == [.color, .font, .fontSize])
        #expect(harness.session.styleColor == .red)

        panel.alignmentButtons[.center]?.performClick(nil)
        harness.session.setColor(.green)

        #expect(harness.view.textEditor === editor)
        #expect(editor.alignment == .center)
        #expect(editor.textColor == AnnotationColor.green.nsColor)
        #expect(harness.session.document.annotations.first?.style.alignment == .center)
        #expect(harness.session.document.annotations.first?.style.color == .green)

        harness.view.commitTextEntry()
        #expect(harness.session.document.annotations.first?.bounds == placed.bounds)  // realigned in place
    }

    /// Choosing a font while typing ends the typing, then styles the text just placed; focus
    /// stays on the font list's search field.
    @Test func openingAStyleListWhileTypingPlacesTheTextFirst() async throws {
        let harness = make()
        harness.session.onRequestTextEntry = { [view = harness.view] _, request in view.beginTextEntry(request) }
        harness.session.toggleTool(.text)
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 200, y: 150), to: CGPoint(x: 200, y: 150))
        let editor = try #require(harness.view.textEditor)
        editor.insertText("Styled", replacementRange: editor.selectedRange())

        harness.view.toggleDropdown(.font)
        try await Task.sleep(for: .zero)

        #expect(harness.view.textEditor == nil)
        #expect(harness.session.document.annotations.count == 1)
        let list = try #require(harness.view.dropdown?.panel)
        #expect(harness.window.firstResponder === list.searchField?.currentEditor())
        list.search("serif")
        list.pickSelected()
        #expect(harness.session.document.annotations.first?.style.font == .serif)
    }

    // MARK: Shapes, arrowheads and modifiers

    /// A mouse event at a display-local point (the view is flipped; the window isn't).
    private func mouse(_ type: NSEvent.EventType, _ point: CGPoint, _ flags: NSEvent.ModifierFlags = [], in harness: Harness) throws
        -> NSEvent
    {
        try #require(
            NSEvent.mouseEvent(
                with: type, location: CGPoint(x: point.x, y: harness.view.bounds.height - point.y), modifierFlags: flags, timestamp: 0,
                windowNumber: harness.window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }

    @Test func ovalButtonTurnsTheSelectedShapeIntoAnOval() throws {
        let harness = make()
        harness.session.toggleTool(.shape)
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 200, y: 200), to: CGPoint(x: 300, y: 260))
        let panel = try #require(harness.view.stylePanel)

        panel.shapeButtons[.oval]?.performClick(nil)

        #expect(harness.session.document.annotations.first?.style.shape == .oval)
        #expect(panel.shapeButtons[.oval]?.state == .on)
        #expect((harness.view.toolbar?.toolButtons[.shape] as? ToolbarButton)?.symbol == ShapeKind.oval.symbol)
    }

    @Test func arrowheadButtonsChangeTheSelectedArrow() throws {
        let harness = make()
        harness.session.toggleTool(.arrow)
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 200, y: 200), to: CGPoint(x: 300, y: 260))
        let panel = try #require(harness.view.stylePanel)

        panel.arrowHeadButtons[.both]?.performClick(nil)

        #expect(harness.session.document.annotations.first?.style.arrowHeads == .both)
    }

    @Test func shiftDragOnTheOverlayDrawsASquareAndReleasingShiftFreesIt() throws {
        let harness = make()
        harness.session.toggleTool(.shape)
        harness.view.mouseDown(with: try mouse(.leftMouseDown, CGPoint(x: 200, y: 200), in: harness))
        harness.view.mouseDragged(with: try mouse(.leftMouseDragged, CGPoint(x: 300, y: 250), .shift, in: harness))
        #expect(harness.session.visibleAnnotations.first?.kind == .shape(CGRect(x: 200, y: 200, width: 100, height: 100)))

        let release = try #require(
            NSEvent.keyEvent(
                with: .flagsChanged, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 56))
        harness.view.flagsChanged(with: release)
        #expect(harness.session.visibleAnnotations.first?.kind == .shape(CGRect(x: 200, y: 200, width: 100, height: 50)))

        harness.view.mouseUp(with: try mouse(.leftMouseUp, CGPoint(x: 300, y: 250), in: harness))
        #expect(harness.session.document.annotations.first?.kind == .shape(CGRect(x: 200, y: 200, width: 100, height: 50)))
    }
}
