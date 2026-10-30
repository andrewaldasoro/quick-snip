import AppKit

/// Full-screen view for one display: frozen image, dimming outside the selection, annotations,
/// border, handles, size label, the annotation toolbar, the font list, and inline text entry.
/// Flipped, so local points match `CaptureSession`.
final class SelectionOverlayView: NSView, NSTextFieldDelegate {
    static let dimColor = NSColor.black.withAlphaComponent(0.45)
    static let borderColor = NSColor.white
    static let handleSize: CGFloat = 7
    static let annotationHandleSize: CGFloat = 7
    static let hoveredWindowBorderWidth: CGFloat = 3
    /// Horizontal padding NSTextField adds before its text (line fragment padding).
    static let textFieldInset: CGFloat = 2

    private let session: CaptureSession
    private let onCommand: @MainActor (OverlayCommand) -> Void
    /// The display as first captured; the session's copy replaces it once a window is brought to the front.
    private let capturedDisplay: CapturedDisplay
    private var frozenImage: NSImage
    private var frozenSource: CGImage

    private(set) var toolbar: AnnotationToolbar?
    private(set) var textField: NSTextField?
    private var textOrigin: CGPoint = .zero
    private let fontFamilies: FontFamilyProviding
    private(set) var fontList: FontListPanel?

    init(
        display: CapturedDisplay, session: CaptureSession, fontFamilies: FontFamilyProviding = SystemFontFamilies(),
        onCommand: @escaping @MainActor (OverlayCommand) -> Void
    ) {
        capturedDisplay = display
        self.session = session
        self.fontFamilies = fontFamilies
        self.onCommand = onCommand
        frozenImage = NSImage(cgImage: display.image, size: display.frame.size)
        frozenSource = display.image
        super.init(frame: display.localBounds)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Screenshot area selection")
        setAccessibilityHelp(
            "Drag to select an area, or click a window. Return copies, Command-S saves, Escape cancels, question mark lists all shortcuts.")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var display: CapturedDisplay { session.display(capturedDisplay.displayID) ?? capturedDisplay }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Cursor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect],
                owner: self
            ))
    }

    /// Cursor for a point in this view; the toolbar and font list always get an arrow.
    func cursor(at point: CGPoint) -> OverlayCursor {
        if let toolbar, !toolbar.isHidden, toolbar.frame.contains(point) { return .arrow }
        if let fontList, fontList.frame.contains(point) { return .arrow }
        return session.cursor(on: display.displayID, at: point)
    }

    private func updateCursor(for event: NSEvent) {
        cursor(at: localPoint(of: event)).nsCursor.set()
    }

    /// Sets the cursor for wherever the mouse is right now. Tracking areas only react to
    /// movement, so a freshly shown overlay would keep the previous app's cursor until
    /// the mouse moved.
    func refreshCursor() {
        guard let window else { return }
        cursor(at: convert(window.mouseLocationOutsideOfEventStream, from: nil)).nsCursor.set()
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor(for: event)
    }

    override func mouseMoved(with event: NSEvent) {
        session.mouseMoved(on: display.displayID, to: localPoint(of: event))
        updateCursor(for: event)
    }

    private var isActiveDisplay: Bool { session.activeDisplayID == display.displayID }

    // MARK: Session updates

    /// Redraws and shows, hides, or repositions the toolbar.
    func sessionDidChange() {
        needsDisplay = true

        guard isActiveDisplay, let selection = session.selection(on: display.displayID), !session.isEditingSelection,
            !session.isShowingCheatsheet
        else {
            toolbar?.isHidden = true
            closeFontList()
            return
        }
        if !session.showsTextStyle { closeFontList() }
        let toolbar = self.toolbar ?? makeToolbar()
        toolbar.update(
            tool: session.tool,
            style: session.style,
            textStyle: session.showsTextStyle ? session.textStyle : nil,
            isShowingFontList: fontList != nil,
            canUndo: session.document.canUndo,
            canRedo: session.document.canRedo
        )
        toolbar.frame = ToolbarLayout.frame(size: toolbar.fittingSize, selection: selection, bounds: bounds)
        toolbar.isHidden = false
        // Placed against the toolbar the way the toolbar is placed against the selection.
        fontList?.frame = ToolbarLayout.frame(size: FontListPanel.size, selection: toolbar.frame, bounds: bounds)
    }

    private func makeToolbar() -> AnnotationToolbar {
        let toolbar = AnnotationToolbar(
            actions: .init(
                selectTool: { [weak self] tool in
                    self?.session.toggleTool(tool)
                    self?.restoreFocus()
                },
                selectColor: { [weak self] color in
                    self?.session.setColor(color)
                    self?.restoreFocus()
                },
                selectWidth: { [weak self] width in
                    self?.session.setWidth(width)
                    self?.restoreFocus()
                },
                selectFont: { [weak self] font in
                    self?.session.setFont(font)
                    self?.restoreFocus()
                },
                selectFontSize: { [weak self] size in
                    self?.session.setFontSize(size)
                    self?.restoreFocus()
                },
                toggleFontList: { [weak self] in
                    self?.toggleFontList()
                },
                command: { [weak self] command in
                    self?.onCommand(command)
                    self?.restoreFocus()
                }
            ))
        addSubview(toolbar)
        self.toolbar = toolbar
        return toolbar
    }

    /// Keeps keyboard shortcuts working after clicking a toolbar control.
    private func restoreFocus() {
        if textField == nil { window?.makeFirstResponder(self) }
    }

    /// Typing goes to a text field (annotation text, size, font search), not to shortcuts.
    private var isTyping: Bool {
        textField != nil || window?.firstResponder is NSText
    }

    // MARK: Font list

    func toggleFontList() {
        if fontList != nil {
            closeFontList()
        } else {
            openFontList()
        }
    }

    private func openFontList() {
        let panel = FontListPanel(
            catalog: FontCatalog(provider: fontFamilies),
            current: session.textStyle.font,
            onPick: { [weak self] family in
                self?.session.setFont(.family(family))
                self?.closeFontList()
            },
            onClose: { [weak self] in self?.closeFontList() }
        )
        addSubview(panel)
        fontList = panel
        sessionDidChange()
        window?.makeFirstResponder(panel.searchField)
    }

    func closeFontList() {
        guard let panel = fontList else { return }
        fontList = nil
        panel.removeFromSuperview()
        restoreFocus()
        sessionDidChange()
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        drawCapture()
        // On every display, so it's in front of the user wherever they're looking.
        if session.isShowingCheatsheet {
            CheatsheetPanel(cheatsheet: .overlay).draw(in: bounds)
        }
    }

    private func drawCapture() {
        if frozenSource !== display.image {
            frozenSource = display.image
            frozenImage = NSImage(cgImage: display.image, size: display.frame.size)
        }
        frozenImage.draw(
            in: bounds,
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.none.rawValue]
        )

        let selection = session.selection(on: display.displayID)
        let hoveredWindow = session.hoveredWindow(on: display.displayID)

        let dim = NSBezierPath(rect: bounds)
        if let hole = selection.flatMap({ $0.isEmpty ? nil : $0 }) ?? hoveredWindow {
            dim.append(NSBezierPath(rect: hole))
            dim.windingRule = .evenOdd
        }
        Self.dimColor.setFill()
        dim.fill()

        if let hoveredWindow, selection == nil {
            drawHoveredWindow(hoveredWindow)
        }
        guard let selection, !selection.isEmpty else { return }
        if isActiveDisplay {
            drawAnnotations(clippedTo: selection)
        }
        drawBorder(selection)
        drawHandles(selection)
        drawSizeLabel(selection)
        if isActiveDisplay, let notice = session.notice {
            drawNotice(notice, over: selection)
        }
    }

    private func drawNotice(_ notice: String, over selection: CGRect) {
        let text = NSAttributedString(
            string: notice,
            attributes: [.font: NSFont.systemFont(ofSize: NoticeLabel.fontSize, weight: .medium), .foregroundColor: NSColor.white]
        )
        let frame = NoticeLabel.frame(textSize: text.size(), selection: selection, bounds: bounds)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: frame, xRadius: NoticeLabel.cornerRadius, yRadius: NoticeLabel.cornerRadius).fill()
        text.draw(at: CGPoint(x: frame.minX + NoticeLabel.padding.width, y: frame.minY + NoticeLabel.padding.height))
    }

    private func drawAnnotations(clippedTo selection: CGRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.clip(to: selection)
        AnnotationRenderer.draw(session.visibleAnnotations, in: context, display: display, cache: session.pixelateCache)
        context.restoreGState()

        if let selected = session.selectedAnnotation {
            let outline = NSBezierPath(rect: selected.bounds.insetBy(dx: -4, dy: -4))
            outline.lineWidth = 1
            outline.setLineDash([4, 3], count: 2, phase: 0)
            NSColor.white.setStroke()
            outline.stroke()
            drawAnnotationHandles(of: selected)
        }
    }

    /// Square handles on frame corners and edges, round ones on line ends.
    private func drawAnnotationHandles(of annotation: Annotation) {
        guard session.tool == nil else { return }
        let size = Self.annotationHandleSize
        for (handle, center) in AnnotationResizer.handles(for: annotation) {
            let rect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
            let path = handle == .start || handle == .end ? NSBezierPath(ovalIn: rect) : NSBezierPath(rect: rect)
            Self.borderColor.setFill()
            path.fill()
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    /// What a click would select: the window, outlined in the accent color.
    private func drawHoveredWindow(_ frame: CGRect) {
        let inset = Self.hoveredWindowBorderWidth / 2
        let border = NSBezierPath(rect: frame.insetBy(dx: inset, dy: inset))
        border.lineWidth = Self.hoveredWindowBorderWidth
        NSColor.controlAccentColor.setStroke()
        border.stroke()
    }

    private func drawBorder(_ selection: CGRect) {
        let border = NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        Self.borderColor.setStroke()
        border.stroke()
    }

    private func drawHandles(_ selection: CGRect) {
        let size = Self.handleSize
        for handle in SelectionHandle.allCases {
            let center = handle.point(in: selection)
            let rect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
            let path = NSBezierPath(rect: rect)
            Self.borderColor.setFill()
            path.fill()
            NSColor.darkGray.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func drawSizeLabel(_ selection: CGRect) {
        guard let pixelSize = session.selectionPixelSize(on: display.displayID) else { return }
        let text = NSAttributedString(
            string: SizeLabel.text(for: pixelSize),
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white,
            ]
        )
        let padding = CGSize(width: 6, height: 3)
        let textSize = text.size()
        let labelSize = CGSize(width: textSize.width + padding.width * 2, height: textSize.height + padding.height * 2)
        let origin = SizeLabel.origin(labelSize: labelSize, selection: selection, bounds: bounds)

        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: CGRect(origin: origin, size: labelSize), xRadius: 4, yRadius: 4).fill()
        text.draw(at: CGPoint(x: origin.x + padding.width, y: origin.y + padding.height))
    }

    // MARK: Text entry

    func beginTextEntry(at point: CGPoint) {
        commitTextEntry()

        let font = session.style.font.font(size: session.style.fontSize)
        let field = NSTextField(string: "")
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = font
        field.textColor = session.style.color.nsColor
        field.delegate = self
        field.target = self
        field.action = #selector(textFieldAction(_:))
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.frame = CGRect(
            x: point.x - Self.textFieldInset,
            y: point.y,
            width: 40,
            height: ceil(font.ascender - font.descender + font.leading) + 2
        )
        field.setAccessibilityLabel("Annotation text")

        addSubview(field)
        textField = field
        textOrigin = point
        window?.makeFirstResponder(field)
    }

    func commitTextEntry() {
        guard let field = textField else { return }
        textField = nil
        let text = field.stringValue
        field.removeFromSuperview()
        window?.makeFirstResponder(self)
        session.addText(text, at: textOrigin, on: display.displayID)
    }

    func cancelTextEntry() {
        guard let field = textField else { return }
        textField = nil
        field.removeFromSuperview()
        window?.makeFirstResponder(self)
    }

    @objc private func textFieldAction(_ sender: NSTextField) {
        commitTextEntry()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = textField else { return }
        let width = (field.attributedStringValue.size().width + Self.textFieldInset * 2 + 8).rounded(.up)
        field.setFrameSize(NSSize(width: max(40, width), height: field.frame.height))
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        commitTextEntry()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelTextEntry()
            return true
        }
        return false
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        if textField != nil {
            commitTextEntry()
            return
        }
        // A click outside the font list only closes it, like the cheatsheet.
        if fontList != nil {
            closeFontList()
            return
        }
        session.mouseDown(on: display.displayID, at: localPoint(of: event))
        updateCursor(for: event)
    }

    override func mouseDragged(with event: NSEvent) {
        session.mouseDragged(on: display.displayID, to: localPoint(of: event))
        updateCursor(for: event)
    }

    override func mouseUp(with event: NSEvent) {
        session.mouseUp(on: display.displayID, at: localPoint(of: event))
        updateCursor(for: event)
    }

    private func localPoint(of event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if let command = OverlayKeyMap.command(for: event) {
            perform(command)
        } else {
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // While typing, ⌘C/⌘Z etc. belong to the text field.
        guard !isTyping else { return super.performKeyEquivalent(with: event) }
        if let command = OverlayKeyMap.command(for: event) {
            perform(command)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Esc closes the font list before it cancels the capture.
    private func perform(_ command: OverlayCommand) {
        if command == .cancel, fontList != nil {
            closeFontList()
            return
        }
        onCommand(command)
    }
}
