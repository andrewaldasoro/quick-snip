import CoreGraphics
import Foundation

/// One capture in progress: the frozen displays, the single active selection, and its
/// annotations. Starting a selection on another display clears the previous one.
///
/// Mouse routing:
/// - Selection handles always resize the selection.
/// - With a tool, dragging inside the selection draws (text: click to type).
/// - Without a tool, dragging an annotation moves it; otherwise it moves/creates the selection.
///   Once there are annotations, clicking outside no longer starts a new selection.
@MainActor
final class CaptureSession {
    let displays: [CapturedDisplay]
    let document = AnnotationDocument()
    let pixelateCache = PixelateCache()
    private(set) var activeDisplayID: CGDirectDisplayID?
    private var editors: [CGDirectDisplayID: SelectionEditor]

    private(set) var tool: AnnotationTool?
    private(set) var style = AnnotationStyle.default
    private(set) var selectedAnnotationID: UUID?
    /// The shortcut cheatsheet (**?**) is drawn over the overlay.
    private(set) var isShowingCheatsheet = false

    private var builder: AnnotationBuilder?
    private var move: (original: Annotation, start: CGPoint)?
    /// In-progress drawing, or the moved copy of an annotation while dragging.
    private var draft: Annotation?

    /// Called after any change so every overlay can redraw.
    var onChange: (@MainActor () -> Void)?
    /// Asks the overlay of a display to start text entry at a display-local point.
    var onRequestTextEntry: (@MainActor (_ displayID: CGDirectDisplayID, _ point: CGPoint) -> Void)?

    init(displays: [CapturedDisplay]) {
        self.displays = displays
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
        var result = document.annotations
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

    // MARK: Mouse

    func mouseDown(on id: CGDirectDisplayID, at point: CGPoint) {
        guard editors[id] != nil else { return }
        // The cheatsheet covers the selection, so a click only closes it.
        if isShowingCheatsheet {
            hideCheatsheet()
            return
        }
        let onActive = id == activeDisplayID
        let selection = onActive ? editors[id]?.selection : nil
        let hit = onActive ? hitTest(on: id, at: point) : .outside

        if case .handle = hit {
            editors[id]?.mouseDown(at: point)
            notify()
            return
        }

        if let tool {
            guard let selection, selection.contains(point) else { return }
            selectedAnnotationID = nil
            if tool == .text {
                onRequestTextEntry?(id, point)
            } else {
                builder = AnnotationBuilder(tool: tool, style: style, start: point)
                draft = builder?.annotation
            }
            notify()
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
        } else if let move {
            draft = move.original.offsetBy(dx: point.x - move.start.x, dy: point.y - move.start.y)
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
            }
        } else if let move {
            self.move = nil
            draft = nil
            let moved = move.original.offsetBy(dx: point.x - move.start.x, dy: point.y - move.start.y)
            document.update(moved, actionName: "Move \(moved.name)")
        } else {
            editors[id]?.mouseUp(at: point)
        }
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

    func setWidth(_ width: StrokeWidth) {
        style.width = width
        restyleSelectedAnnotation { $0.width = width }
        notify()
    }

    func addText(_ text: String, at origin: CGPoint, on id: CGDirectDisplayID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, id == activeDisplayID else { return }
        document.add(Annotation(kind: .text(trimmed, origin: origin), style: style))
    }

    @discardableResult
    func deleteSelectedAnnotation() -> Bool {
        guard let id = selectedAnnotationID, document.annotation(id) != nil else { return false }
        document.remove(id)
        return true
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
