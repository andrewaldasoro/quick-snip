import AppKit

/// Full-screen view for one display: frozen image, dimming outside the selection, annotations,
/// border, handles, size label, the annotation toolbar and style panel, an open dropdown list,
/// and inline text entry.
/// Flipped, so local points match `CaptureSession`.
final class SelectionOverlayView: NSView {
    static let dimColor = NSColor.black.withAlphaComponent(0.45)
    static let borderColor = NSColor.white
    static let handleSize: CGFloat = 7
    static let annotationHandleSize: CGFloat = 7
    static let hoveredWindowBorderWidth: CGFloat = 3

    private let session: CaptureSession
    private let onCommand: @MainActor (OverlayCommand) -> Void
    /// The display as first captured; the session's copy replaces it once a window is brought to the front.
    private let capturedDisplay: CapturedDisplay
    private var frozenImage: NSImage
    private var frozenSource: CGImage

    private(set) var toolbar: AnnotationToolbar?
    private(set) var textEntry: TextEntry?
    var textField: NSTextField? { textEntry?.field }
    private let fontFamilies: FontFamilyProviding
    private(set) var stylePanel: StylePanel?
    /// The open style dropdown, if any.
    private(set) var dropdown: (list: StyleList, panel: DropdownListPanel)?

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

    /// Cursor for a point in this view; the toolbar, style panel and dropdown get an arrow.
    func cursor(at point: CGPoint) -> OverlayCursor {
        let controls: [NSView?] = [toolbar, stylePanel, dropdown?.panel]
        if controls.contains(where: { $0.map { !$0.isHidden && $0.frame.contains(point) } ?? false }) { return .arrow }
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

    /// Redraws and shows, hides, or repositions the toolbar and style panel.
    func sessionDidChange() {
        needsDisplay = true

        guard isActiveDisplay, let selection = session.selection(on: display.displayID), !session.isEditingSelection,
            !session.isShowingCheatsheet
        else {
            toolbar?.isHidden = true
            stylePanel?.isHidden = true
            closeDropdown()
            return
        }
        let toolbar = self.toolbar ?? makeToolbar()
        toolbar.update(
            tool: session.tool,
            canUndo: session.document.canUndo,
            canRedo: session.document.canRedo
        )
        toolbar.frame = ToolbarLayout.frame(size: toolbar.fittingSize, selection: selection, bounds: bounds)
        toolbar.isHidden = false
        updateStylePanel(toolbar: toolbar.frame, selection: selection)
    }

    private func updateStylePanel(toolbar: CGRect, selection: CGRect) {
        guard let options = session.styleOptions else {
            stylePanel?.isHidden = true
            closeDropdown()
            return
        }
        if let dropdown, StyleChoices.current(for: dropdown.list, options: options) == nil { closeDropdown() }
        let panel = stylePanel ?? makeStylePanel()
        panel.update(options: options, color: session.styleColor, openList: dropdown?.list)
        panel.frame = StylePanelLayout.frame(size: panel.fittingSize, toolbar: toolbar, selection: selection, bounds: bounds)
        panel.isHidden = false
        if let dropdown, let button = panel.buttons[dropdown.list] {
            // The buttons only have frames after a layout pass; the list hangs off one.
            panel.layoutSubtreeIfNeeded()
            dropdown.panel.frame = dropdownFrame(size: dropdown.panel.frame.size, below: button)
        }
    }

    private func makeStylePanel() -> StylePanel {
        let panel = StylePanel(
            actions: .init(
                openList: { [weak self] list in self?.toggleDropdown(list) },
                selectColor: { [weak self] color in
                    self?.session.setColor(color)
                    self?.restoreFocus()
                },
                selectAlignment: { [weak self] alignment in
                    self?.session.setAlignment(alignment)
                    self?.restoreFocus()
                }
            ))
        addSubview(panel)
        stylePanel = panel
        return panel
    }

    private func makeToolbar() -> AnnotationToolbar {
        let toolbar = AnnotationToolbar(
            actions: .init(
                selectTool: { [weak self] tool in
                    self?.session.toggleTool(tool)
                    self?.restoreFocus()
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

    /// Typing goes to a text field (annotation text, font search), not to shortcuts.
    private var isTyping: Bool {
        textField != nil || window?.firstResponder is NSText
    }

    // MARK: Dropdowns

    /// Opens a style dropdown's list under its button; the open one closes instead.
    func toggleDropdown(_ list: StyleList) {
        let wasOpen = dropdown?.list == list
        closeDropdown()
        if !wasOpen { openDropdown(list) }
    }

    private func openDropdown(_ list: StyleList) {
        guard let options = session.styleOptions else { return }
        let families = StyleChoices.isSearchable(list) ? FontCatalog(provider: fontFamilies).families : []
        let panel = DropdownListPanel(
            values: StyleChoices.values(for: list, options: options, fontFamilies: families),
            current: StyleChoices.current(for: list, options: options),
            isSearchable: StyleChoices.isSearchable(list),
            onPick: { [weak self] value in self?.apply(value) },
            onClose: { [weak self] in self?.closeDropdown() }
        )
        addSubview(panel)
        dropdown = (list, panel)
        sessionDidChange()
        window?.makeFirstResponder(panel.initialFirstResponder)
    }

    private func apply(_ value: StyleValue) {
        closeDropdown()
        switch value {
        case .lineWidth(let width): session.setLineWidth(width)
        case .font(let font): session.setFont(font)
        case .fontSize(let size): session.setFontSize(size)
        }
    }

    func closeDropdown() {
        guard let open = dropdown else { return }
        dropdown = nil
        open.panel.removeFromSuperview()
        stylePanel?.markOpen(nil)
        restoreFocus()
    }

    /// Under its button, left-aligned like a pop-up menu; above it when there's no room below.
    private func dropdownFrame(size: CGSize, below button: NSView) -> CGRect {
        let anchor = convert(button.bounds, from: button)
        let margin = ToolbarLayout.margin
        let x = min(max(anchor.minX, bounds.minX + margin), bounds.maxX - margin - size.width)
        let below = anchor.maxY + StylePanelLayout.gap
        let y =
            below + size.height <= bounds.maxY - margin
            ? below : max(bounds.minY + margin, anchor.minY - StylePanelLayout.gap - size.height)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
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
        if let box = session.textBoxPreview {
            drawTextBoxPreview(box)
        }
    }

    /// The text box being dragged out: an accent outline, one line tall until text fills it.
    private func drawTextBoxPreview(_ box: CGRect) {
        let outline = NSBezierPath(rect: box.insetBy(dx: 0.5, dy: 0.5))
        outline.lineWidth = 1
        outline.setLineDash([4, 3], count: 2, phase: 0)
        NSColor.controlAccentColor.setStroke()
        outline.stroke()
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

    func beginTextEntry(at placement: TextPlacement) {
        commitTextEntry()
        let entry = TextEntry(
            placement: placement, style: session.style,
            onCommit: { [weak self] text in self?.finishTextEntry(placing: text) },
            onCancel: { [weak self] in self?.finishTextEntry(placing: nil) }
        )
        addSubview(entry.field)
        textEntry = entry
        window?.makeFirstResponder(entry.field)
    }

    func commitTextEntry() {
        textEntry?.commit()
    }

    func cancelTextEntry() {
        textEntry?.cancel()
    }

    private func finishTextEntry(placing text: String?) {
        guard let entry = textEntry else { return }
        textEntry = nil
        entry.field.removeFromSuperview()
        window?.makeFirstResponder(self)
        if let text {
            session.addText(text, at: entry.placement, on: display.displayID)
        }
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        if textField != nil {
            commitTextEntry()
            return
        }
        // A click outside an open dropdown only closes it, like a menu.
        if dropdown != nil {
            closeDropdown()
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

    /// Esc closes an open dropdown before it cancels the capture.
    private func perform(_ command: OverlayCommand) {
        if command == .cancel, dropdown != nil {
            closeDropdown()
            return
        }
        onCommand(command)
    }
}
