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

    // MARK: Colors and alignment

    @Test func colorDropdownColorsWhatsSelected() throws {
        let harness = make()
        harness.session.toggleTool(.rectangle)
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

    /// Regression: realigning text while typing slid it left (centered on, or ending at, the
    /// click). It stays put, as placed text does, and grows from its new anchor from then on.
    @Test(arguments: [TextAlignment.center, .right])
    func realigningTextBeingTypedKeepsItInPlace(alignment: TextAlignment) throws {
        let harness = make()
        harness.session.onRequestTextEntry = { [view = harness.view] _, request in view.beginTextEntry(request) }
        harness.session.toggleTool(.text)
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 300, y: 150), to: CGPoint(x: 300, y: 150))
        let editor = try #require(harness.view.textEditor)
        editor.insertText("Typing", replacementRange: editor.selectedRange())
        // The text itself: the editor is a caret's width wider, on the side the text grows.
        func textFrame() -> CGRect {
            let caret = TextEntry.caretRoom
            let fraction = harness.session.style.alignment.anchorFraction
            return CGRect(
                x: editor.frame.minX + caret * fraction, y: editor.frame.minY, width: editor.frame.width - caret,
                height: editor.frame.height)
        }
        let before = textFrame()

        try #require(harness.view.stylePanel).alignmentButtons[alignment]?.performClick(nil)

        #expect(textFrame() == before)  // nothing slides
        editor.insertText(" more", replacementRange: editor.selectedRange())
        let anchor = before.minX + before.width * alignment.anchorFraction
        let grown = textFrame()
        #expect(abs(grown.minX + grown.width * alignment.anchorFraction - anchor) < 0.5)  // grows around the new anchor

        harness.view.commitTextEntry()
        let placed = try #require(harness.session.document.annotations.first)
        #expect(abs(placed.bounds.minX - grown.minX) < 0.5)  // lands where it was typed
        #expect(placed.style.alignment == alignment)
    }

    @Test func colorAndSizeChangeTheTextBeingTyped() throws {
        let harness = make()
        harness.session.onRequestTextEntry = { [view = harness.view] _, request in view.beginTextEntry(request) }
        harness.session.toggleTool(.text)
        TestSessions.drag(harness.session, on: 1, from: CGPoint(x: 300, y: 150), to: CGPoint(x: 300, y: 150))
        let editor = try #require(harness.view.textEditor)

        harness.session.setColor(.blue)
        harness.session.setFontSize(48)

        #expect(editor.textColor == AnnotationColor.blue.nsColor)
        #expect(editor.font == TextFont.system.font(size: 48))
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
}
