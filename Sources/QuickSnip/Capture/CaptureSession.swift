import CoreGraphics

/// One capture in progress: the frozen displays and the single active selection.
/// Starting a selection on another display clears the previous one.
@MainActor
final class CaptureSession {
    let displays: [CapturedDisplay]
    private(set) var activeDisplayID: CGDirectDisplayID?
    private var editors: [CGDirectDisplayID: SelectionEditor]

    /// Called after any selection change so every overlay can redraw.
    var onChange: (@MainActor () -> Void)?

    init(displays: [CapturedDisplay]) {
        self.displays = displays
        editors = Dictionary(
            displays.map { ($0.displayID, SelectionEditor(bounds: $0.localBounds)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

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

    func mouseDown(on id: CGDirectDisplayID, at point: CGPoint) {
        guard editors[id] != nil else { return }
        if let active = activeDisplayID, active != id {
            editors[active]?.clear()
        }
        activeDisplayID = id
        editors[id]?.mouseDown(at: point)
        onChange?()
    }

    func mouseDragged(on id: CGDirectDisplayID, to point: CGPoint) {
        guard id == activeDisplayID else { return }
        editors[id]?.mouseDragged(to: point)
        onChange?()
    }

    func mouseUp(on id: CGDirectDisplayID, at point: CGPoint) {
        guard id == activeDisplayID else { return }
        editors[id]?.mouseUp(at: point)
        onChange?()
    }

    var hasSelection: Bool {
        activeDisplayID.flatMap { selection(on: $0) } != nil
    }

    func croppedImage() -> CGImage? {
        guard let id = activeDisplayID, let rect = selection(on: id), let display = display(id) else { return nil }
        return CropMath.crop(display, to: rect)
    }
}
