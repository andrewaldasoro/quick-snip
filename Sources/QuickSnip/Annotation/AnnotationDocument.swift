import Foundation

/// The annotations of one capture, with snapshot-based undo/redo.
@MainActor
final class AnnotationDocument {
    let undoManager = UndoManager()
    private(set) var annotations: [Annotation] = []
    var onChange: (@MainActor () -> Void)?

    init() {
        undoManager.groupsByEvent = false
    }

    var canUndo: Bool { undoManager.canUndo }
    var canRedo: Bool { undoManager.canRedo }

    func annotation(_ id: UUID) -> Annotation? {
        annotations.first { $0.id == id }
    }

    /// Topmost (last drawn) annotation under `point`.
    func topmost(at point: CGPoint) -> Annotation? {
        annotations.last { $0.hitTest(point) }
    }

    func add(_ annotation: Annotation) {
        replaceAll(annotations + [annotation], actionName: "Add \(annotation.name)")
    }

    func update(_ annotation: Annotation, actionName: String) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }),
              annotations[index] != annotation else { return }
        var updated = annotations
        updated[index] = annotation
        replaceAll(updated, actionName: actionName)
    }

    func remove(_ id: UUID) {
        guard let annotation = annotation(id) else { return }
        replaceAll(annotations.filter { $0.id != id }, actionName: "Delete \(annotation.name)")
    }

    func undo() {
        guard canUndo else { return }
        undoManager.undo()
    }

    func redo() {
        guard canRedo else { return }
        undoManager.redo()
    }

    private func replaceAll(_ new: [Annotation], actionName: String) {
        let old = annotations
        annotations = new
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.replaceAll(old, actionName: actionName)
            }
        }
        undoManager.setActionName(actionName)
        undoManager.endUndoGrouping()
        onChange?()
    }
}
