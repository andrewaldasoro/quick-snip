import CoreGraphics
import Foundation

/// One capture in progress: the frozen displays, the single active selection, and its
/// annotations. Starting a selection on another display clears the previous one.
///
/// Mouse routing:
/// - Selection handles always resize the selection.
/// - With a tool, dragging inside the selection draws (text: click for a line, drag for a box;
///   a click on existing text edits it).
/// - Without a tool, a double-click on text edits it in place.
/// - Without a tool, the selected annotation's handles resize it, dragging an annotation moves
///   it; otherwise the drag moves/creates the selection. Annotation handles win over the
///   selection's, since the user just picked that annotation.
///   Once there are annotations, clicking outside no longer starts a new selection.
/// - Before there's a selection, hovering highlights the window under the cursor and a click
///   (no drag) selects it.
@MainActor
final class CaptureSession {
    /// A display's image changes when a covered window is brought to the front.
    private(set) var displays: [CapturedDisplay]
    let document = AnnotationDocument()
    let pixelateCache = PixelateCache()
    private(set) var activeDisplayID: CGDirectDisplayID?
    private var editors: [CGDirectDisplayID: SelectionEditor]

    private(set) var tool: AnnotationTool?
    private(set) var style: AnnotationStyle
    private(set) var selectedAnnotationID: UUID?
    /// The shortcut cheatsheet (**?**) is drawn over the overlay.
    private(set) var isShowingCheatsheet = false
    /// A short status message drawn over the selection ("No text found").
    private(set) var notice: String?
    /// The window a click would select, while there's no selection yet.
    private(set) var hoveredWindow: (displayID: CGDirectDisplayID, window: SnapWindow)?
    /// The window under the mouse-down; a click that doesn't become a drag selects it.
    private var snapTarget: SnapWindow?

    private var builder: AnnotationBuilder?
    private var move: (original: Annotation, start: CGPoint)?
    private var resize: (original: Annotation, handle: AnnotationHandle)?
    /// Text being typed in place, new or reopened; nil when not typing.
    private(set) var textBeingTyped: TextEditRequest?

    /// The text annotation being edited in place; it's hidden meanwhile, so it isn't drawn twice.
    var editingTextID: UUID? { textBeingTyped?.annotationID }

    /// The style and placement of the text being typed, kept current as the style panel changes
    /// it, so the open editor can follow.
    var typing: (style: AnnotationStyle, placement: TextPlacement)? {
        guard let request = textBeingTyped else { return nil }
        guard let id = request.annotationID else { return (style, request.placement) }
        guard let annotation = document.annotation(id), case .text(_, let origin, let boxWidth) = annotation.kind else { return nil }
        return (annotation.style, TextPlacement(origin: origin, boxWidth: boxWidth))
    }
    /// A drag with the text tool, which becomes a text box (or a click's single line).
    private var textBoxDrag: (start: CGPoint, end: CGPoint)?
    /// In-progress drawing, or the moved or resized copy of an annotation while dragging.
    private var draft: Annotation?

    /// Called after any change so every overlay can redraw.
    var onChange: (@MainActor () -> Void)?
    /// A click selected a window that others cover: its own content has to be captured.
    var onSnapToCoveredWindow: (@MainActor (_ displayID: CGDirectDisplayID, _ window: SnapWindow) -> Void)?
    /// The text font or size changed, so it can be remembered for the next capture.
    var onTextStyleChange: (@MainActor (_ font: TextFont, _ size: CGFloat) -> Void)?
    /// Asks the overlay of a display to start text entry at a display-local point.
    var onRequestTextEntry: (@MainActor (_ displayID: CGDirectDisplayID, _ request: TextEditRequest) -> Void)?

    init(displays: [CapturedDisplay], style: AnnotationStyle = .default) {
        self.displays = displays
        self.style = style
        editors = Dictionary(
            displays.map { ($0.displayID, SelectionEditor(bounds: $0.localBounds)) },
            uniquingKeysWith: { first, _ in first }
        )
        document.onChange = { [weak self] in self?.documentDidChange() }
    }

    // MARK: Queries

    func display(_ id: CGDirectDisplayID) -> CapturedDisplay? {
        displays.first { $0.displayID == id }
    }

    func selection(on id: CGDirectDisplayID) -> CGRect? {
        editors[id]?.selection
    }

    func hitTest(on id: CGDirectDisplayID, at point: CGPoint) -> SelectionHit {
        editors[id]?.hitTest(point) ?? .outside
    }

    /// Selection size in captured pixels, for the size label.
    func selectionPixelSize(on id: CGDirectDisplayID) -> CGSize? {
        guard let rect = selection(on: id), let display = display(id) else { return nil }
        return CropMath.pixelRect(for: rect, in: display)?.size
    }

    var activeSelection: CGRect? {
        activeDisplayID.flatMap { selection(on: $0) }
    }

    var hasSelection: Bool { activeSelection != nil }

    /// The selection itself is being created, moved, or resized.
    var isEditingSelection: Bool {
        activeDisplayID.flatMap { editors[$0]?.isDragging } ?? false
    }

    var isDrawing: Bool { builder != nil }

    /// Committed annotations plus any in-progress draft, in drawing order.
    var visibleAnnotations: [Annotation] {
        var result = document.annotations.filter { $0.id != editingTextID }
        if let draft {
            if let index = result.firstIndex(where: { $0.id == draft.id }) {
                result[index] = draft
            } else {
                result.append(draft)
            }
        }
        return result
    }

    var selectedAnnotation: Annotation? {
        selectedAnnotationID.flatMap { id in visibleAnnotations.first { $0.id == id } }
    }

    /// The box being dragged out with the text tool, once it's wide enough to be one.
    var textBoxPreview: CGRect? {
        guard let drag = textBoxDrag else { return nil }
        let box = Geometry.rect(from: drag.start, to: drag.end)
        return box.width >= TextLayout.minimumBoxWidth ? box : nil
    }

    /// The color the style panel shows: the selected annotation's, otherwise what's next drawn.
    var styleColor: AnnotationColor {
        typing?.style.color ?? selectedAnnotation?.style.color ?? style.color
    }

    /// The handle of the selected annotation under `point`, while no tool is active.
    func annotationHandle(on id: CGDirectDisplayID, at point: CGPoint) -> AnnotationHandle? {
        guard tool == nil, id == activeDisplayID, let selected = selectedAnnotation else { return nil }
        return AnnotationResizer.hitTest(point, on: selected)
    }

    /// What the style panel shows: the selected annotation's style, otherwise what the active
    /// tool will draw with. Nil when there's neither, or for pixelate, which has no style.
    var styleOptions: StyleOptions? {
        // The text being typed is hidden from the canvas, but its style is still what's shown.
        if let typing {
            return Self.options(for: .text("", origin: .zero), style: typing.style)
        }
        if let selected = selectedAnnotation {
            return Self.options(for: selected.kind, style: selected.style)
        }
        switch tool {
        case nil, .pixelate: return nil
        case .text: return .text(font: style.font, size: style.fontSize, alignment: style.alignment)
        default: return .stroke(lineWidth: style.lineWidth)
        }
    }

    private static func options(for kind: AnnotationKind, style: AnnotationStyle) -> StyleOptions? {
        switch kind {
        case .pixelate: nil
        case .text: .text(font: style.font, size: style.fontSize, alignment: style.alignment)
        case .rectangle, .line, .arrow, .pen, .marker: .stroke(lineWidth: style.lineWidth)
        }
    }

    /// Looked up in the document, not among the visible annotations: text being edited is
    /// hidden but still selected, and still restyled by the panel.
    private var selectedTextStyle: AnnotationStyle? {
        guard let id = selectedAnnotationID, let selected = document.annotation(id), case .text = selected.kind else { return nil }
        return selected.style
    }

    func hoveredWindow(on id: CGDirectDisplayID) -> CGRect? {
        hoveredWindow?.displayID == id ? hoveredWindow?.window.visibleFrame : nil
    }

    // MARK: Mouse

    func mouseMoved(on id: CGDirectDisplayID, to point: CGPoint) {
        let window = hasSelection || isShowingCheatsheet ? nil : display(id)?.window(at: point)
        let hovered = window.map { (displayID: id, window: $0) }
        guard hovered?.displayID != hoveredWindow?.displayID || hovered?.window != hoveredWindow?.window else { return }
        hoveredWindow = hovered
        notify()
    }

    /// `clickCount` is 2 on the second click of a double-click.
    func mouseDown(on id: CGDirectDisplayID, at point: CGPoint, clickCount: Int = 1) {
        guard editors[id] != nil else { return }
        notice = nil
        hoveredWindow = nil
        snapTarget = nil
        // The cheatsheet covers the selection, so a click only closes it.
        if isShowingCheatsheet {
            hideCheatsheet()
            return
        }
        let onActive = id == activeDisplayID
        let selection = onActive ? editors[id]?.selection : nil
        let hit = onActive ? hitTest(on: id, at: point) : .outside

        if let handle = annotationHandle(on: id, at: point), let selected = selectedAnnotation {
            resize = (selected, handle)
            notify()
            return
        }

        if case .handle = hit {
            editors[id]?.mouseDown(at: point)
            notify()
            return
        }

        if let tool {
            guard let selection, selection.contains(point) else { return }
            selectedAnnotationID = nil
            if tool == .text, let text = topmostText(at: point) {
                editText(text, on: id)
                return
            }
            if tool == .text {
                textBoxDrag = (point, point)
            } else {
                builder = AnnotationBuilder(tool: tool, style: style, start: point)
                draft = builder?.annotation
            }
            notify()
            return
        }

        if clickCount >= 2, selection?.contains(point) == true, let text = topmostText(at: point) {
            editText(text, on: id)
            return
        }

        if let selection, selection.contains(point), let annotation = document.topmost(at: point) {
            selectedAnnotationID = annotation.id
            move = (annotation, point)
            notify()
            return
        }
        selectedAnnotationID = nil

        if !document.annotations.isEmpty, hit == .outside {
            notify()
            return
        }

        // Only from a fresh start: with a selection, a click outside clears it, as before.
        snapTarget = hasSelection ? nil : display(id)?.window(at: point)
        if let active = activeDisplayID, active != id {
            editors[active]?.clear()
        }
        activeDisplayID = id
        editors[id]?.mouseDown(at: point)
        notify()
    }

    func mouseDragged(on id: CGDirectDisplayID, to point: CGPoint) {
        guard id == activeDisplayID else { return }
        if var builder {
            builder.add(clampToSelection(point))
            self.builder = builder
            draft = builder.annotation
        } else if let drag = textBoxDrag {
            textBoxDrag = (drag.start, clampToSelection(point))
        } else if let move {
            draft = move.original.offsetBy(dx: point.x - move.start.x, dy: point.y - move.start.y)
        } else if let resize {
            draft = AnnotationResizer.resized(resize.original, dragging: resize.handle, to: point) ?? draft
        } else {
            editors[id]?.mouseDragged(to: point)
        }
        notify()
    }

    func mouseUp(on id: CGDirectDisplayID, at point: CGPoint) {
        guard id == activeDisplayID else { return }
        if var builder {
            builder.add(clampToSelection(point))
            self.builder = nil
            draft = nil
            if let annotation = builder.finish() {
                document.add(annotation)
                selectJustAdded(annotation)
            }
        } else if let drag = textBoxDrag {
            textBoxDrag = nil
            let end = clampToSelection(point)
            let placement = TextPlacement.from(drag: drag.start, to: end, minimumBoxWidth: TextLayout.minimumBoxWidth)
            let request = TextEditRequest.new(at: placement, style: style)
            textBeingTyped = request
            onRequestTextEntry?(id, request)
        } else if let move {
            self.move = nil
            draft = nil
            let moved = move.original.offsetBy(dx: point.x - move.start.x, dy: point.y - move.start.y)
            document.update(moved, actionName: "Move \(moved.name)")
        } else if let resize {
            self.resize = nil
            let resized = AnnotationResizer.resized(resize.original, dragging: resize.handle, to: point) ?? draft
            draft = nil
            if let resized {
                document.update(resized, actionName: "Resize \(resized.name)")
            }
        } else {
            editors[id]?.mouseUp(at: point)
            // Too small to be a drag: a click, which selects the window under it.
            if let snapTarget, editors[id]?.selection == nil {
                snap(to: snapTarget, on: id)
            }
        }
        snapTarget = nil
        notify()
    }

    private func snap(to window: SnapWindow, on id: CGDirectDisplayID) {
        editors[id]?.select(window.visibleFrame)
        if display(id)?.isCovered(window) == true {
            onSnapToCoveredWindow?(id, window)
        }
    }

    /// Paints a window's own capture over the frozen display, so the selection shows (and
    /// exports) all of it rather than the windows that covered it.
    func bringToFront(_ window: SnapWindow, image: CGImage, on id: CGDirectDisplayID) {
        guard let index = displays.firstIndex(where: { $0.displayID == id }),
            let composed = displays[index].bringingToFront(window, image: image)
        else { return }
        displays[index] = composed
        pixelateCache.removeAll()
        notify()
    }

    private func clampToSelection(_ point: CGPoint) -> CGPoint {
        guard let rect = activeSelection else { return point }
        return CGPoint(x: min(max(point.x, rect.minX), rect.maxX), y: min(max(point.y, rect.minY), rect.maxY))
    }

    // MARK: Editing

    /// Selecting the active tool again turns it off (back to select/move).
    func toggleTool(_ tool: AnnotationTool) {
        self.tool = self.tool == tool ? nil : tool
        if self.tool != nil { selectedAnnotationID = nil }
        notify()
    }

    /// Applies to new annotations and to the selected one.
    func setColor(_ color: AnnotationColor) {
        style.color = color
        restyleSelectedAnnotation { $0.color = color }
        notify()
    }

    /// Applies to new shapes and to the selected one (not text or pixelate, which have no line).
    func setLineWidth(_ width: CGFloat) {
        style.lineWidth = width
        if case .stroke = styleOptions {
            restyleSelectedAnnotation { $0.lineWidth = width }
        }
        notify()
    }

    /// Applies to new text and to the selected text annotation.
    func setFont(_ font: TextFont) {
        style.font = font
        restyleSelectedText { $0.font = font }
        onTextStyleChange?(style.font, style.fontSize)
        notify()
    }

    func setFontSize(_ size: CGFloat) {
        style.fontSize = TextSize.clamp(size)
        restyleSelectedText { $0.fontSize = style.fontSize }
        onTextStyleChange?(style.font, style.fontSize)
        notify()
    }

    /// Applies to new text and to the selected text; one-line text keeps its place on screen.
    func setAlignment(_ alignment: TextAlignment) {
        style.alignment = alignment
        if let id = selectedAnnotationID, let selected = document.annotation(id), case .text = selected.kind {
            document.update(selected.aligned(alignment), actionName: "Change Style")
        }
        notify()
    }

    // MARK: Text editing

    private func topmostText(at point: CGPoint) -> Annotation? {
        guard let annotation = document.topmost(at: point), case .text = annotation.kind else { return nil }
        return annotation
    }

    private func editText(_ annotation: Annotation, on id: CGDirectDisplayID) {
        guard let request = TextEditRequest.editing(annotation) else { return }
        move = nil
        textBeingTyped = request
        selectedAnnotationID = annotation.id
        onRequestTextEntry?(id, request)
        notify()
    }

    /// Typing in place ended: new text is added; edited text is updated in one undo step, or
    /// removed when it was emptied. Either way it ends up selected with the tool off.
    func finishText(_ text: String, for request: TextEditRequest, on id: CGDirectDisplayID) {
        if textBeingTyped == request { textBeingTyped = nil }
        guard let annotationID = request.annotationID else {
            addText(text, at: request.placement, on: id)
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            document.remove(annotationID)
        } else if var annotation = document.annotation(annotationID), case .text(_, let origin, let boxWidth) = annotation.kind {
            annotation.kind = .text(trimmed, origin: origin, boxWidth: boxWidth)
            document.update(annotation, actionName: "Edit Text")
            selectedAnnotationID = annotationID
        }
        tool = nil
        notify()
    }

    func addText(_ text: String, at placement: TextPlacement, on id: CGDirectDisplayID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, id == activeDisplayID else { return }
        let kind = AnnotationKind.text(trimmed, origin: placement.origin, boxWidth: placement.boxWidth)
        let annotation = Annotation(kind: kind, style: style)
        document.add(annotation)
        selectJustAdded(annotation)
        // The document's change notice went out before the tool turned off.
        notify()
    }

    /// After drawing, the tool turns off and the new annotation is selected, so its handles
    /// and the style panel work on it right away.
    private func selectJustAdded(_ annotation: Annotation) {
        tool = nil
        selectedAnnotationID = annotation.id
    }

    @discardableResult
    func deleteSelectedAnnotation() -> Bool {
        guard let id = selectedAnnotationID, document.annotation(id) != nil else { return false }
        document.remove(id)
        return true
    }

    func showNotice(_ text: String) {
        notice = text
        notify()
    }

    func clearNotice() {
        guard notice != nil else { return }
        notice = nil
        notify()
    }

    func toggleCheatsheet() {
        isShowingCheatsheet.toggle()
        notify()
    }

    func hideCheatsheet() {
        guard isShowingCheatsheet else { return }
        isShowingCheatsheet = false
        notify()
    }

    func undo() { document.undo() }
    func redo() { document.redo() }

    private func restyleSelectedAnnotation(_ change: (inout AnnotationStyle) -> Void) {
        guard let id = selectedAnnotationID, var annotation = document.annotation(id) else { return }
        change(&annotation.style)
        document.update(annotation, actionName: "Change Style")
    }

    /// Font changes don't show on shapes, so they'd only add invisible undo steps there.
    private func restyleSelectedText(_ change: (inout AnnotationStyle) -> Void) {
        guard selectedTextStyle != nil else { return }
        restyleSelectedAnnotation(change)
    }

    // MARK: Output

    /// Pixels per point of the active display (2 on Retina), for image DPI metadata.
    var outputScale: CGFloat {
        guard let id = activeDisplayID, let display = display(id), display.frame.width > 0 else { return 1 }
        return display.pixelSize.width / display.frame.width
    }

    /// The selected region at full resolution with annotations burned in.
    func renderedImage() -> CGImage? {
        guard let id = activeDisplayID, let rect = selection(on: id), let display = display(id) else { return nil }
        return ExportRenderer.render(display: display, selection: rect, annotations: document.annotations, cache: pixelateCache)
    }

    // MARK: Cursor

    func cursor(on id: CGDirectDisplayID, at point: CGPoint) -> OverlayCursor {
        let onActive = id == activeDisplayID
        let selection = onActive ? self.selection(on: id) : nil
        return OverlayCursor.resolve(
            hit: onActive ? hitTest(on: id, at: point) : .outside,
            annotationHandle: annotationHandle(on: id, at: point),
            tool: tool,
            insideSelection: selection?.contains(point) ?? false,
            overAnnotation: selection?.contains(point) == true && document.topmost(at: point) != nil,
            hasAnnotations: !document.annotations.isEmpty,
            isMoving: move != nil || isEditingSelection && editors[id]?.isMoving == true
        )
    }

    // MARK: Notifications

    private func documentDidChange() {
        if let id = selectedAnnotationID, document.annotation(id) == nil {
            selectedAnnotationID = nil
        }
        notify()
    }

    private func notify() {
        onChange?()
    }
}
