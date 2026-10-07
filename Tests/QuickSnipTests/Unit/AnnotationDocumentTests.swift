import CoreGraphics
import Foundation
import Testing
@testable import QuickSnip

@MainActor
struct AnnotationDocumentTests {
    private func rect(_ x: CGFloat) -> Annotation {
        Annotation(kind: .rectangle(CGRect(x: x, y: 0, width: 10, height: 10)), style: .default)
    }

    @Test func addAppendsInOrder() {
        let doc = AnnotationDocument()
        let a = rect(0), b = rect(20)
        doc.add(a)
        doc.add(b)
        #expect(doc.annotations == [a, b])
    }

    @Test func undoAndRedoAdd() {
        let doc = AnnotationDocument()
        let a = rect(0)
        doc.add(a)

        doc.undo()
        #expect(doc.annotations.isEmpty)
        #expect(doc.canRedo)

        doc.redo()
        #expect(doc.annotations == [a])
    }

    @Test func multipleUndoStepsAreSeparate() {
        let doc = AnnotationDocument()
        let a = rect(0), b = rect(20)
        doc.add(a)
        doc.add(b)
        doc.undo()
        #expect(doc.annotations == [a])
        doc.undo()
        #expect(doc.annotations.isEmpty)
        #expect(!doc.canUndo)
    }

    @Test func newChangeClearsRedo() {
        let doc = AnnotationDocument()
        doc.add(rect(0))
        doc.undo()
        doc.add(rect(20))
        #expect(!doc.canRedo)
    }

    @Test func updateReplacesInPlaceAndIsUndoable() {
        let doc = AnnotationDocument()
        let a = rect(0)
        doc.add(a)
        let moved = a.offsetBy(dx: 5, dy: 5)
        doc.update(moved, actionName: "Move")
        #expect(doc.annotations == [moved])
        #expect(doc.undoManager.undoActionName == "Move")
        doc.undo()
        #expect(doc.annotations == [a])
    }

    @Test func unchangedUpdateRegistersNothing() {
        let doc = AnnotationDocument()
        let a = rect(0)
        doc.add(a)
        doc.update(a, actionName: "Move")
        doc.undo()
        #expect(doc.annotations.isEmpty)
    }

    @Test func removeIsUndoable() {
        let doc = AnnotationDocument()
        let a = rect(0), b = rect(20)
        doc.add(a)
        doc.add(b)
        doc.remove(a.id)
        #expect(doc.annotations == [b])
        doc.undo()
        #expect(doc.annotations == [a, b])
    }

    @Test func removingUnknownIDDoesNothing() {
        let doc = AnnotationDocument()
        doc.remove(UUID())
        #expect(!doc.canUndo)
    }

    @Test func undoWithEmptyStackIsSafe() {
        let doc = AnnotationDocument()
        doc.undo()
        doc.redo()
        #expect(doc.annotations.isEmpty)
    }

    @Test func topmostPrefersLastDrawn() {
        let doc = AnnotationDocument()
        let below = Annotation(kind: .pixelate(CGRect(x: 0, y: 0, width: 50, height: 50)), style: .default)
        let above = Annotation(kind: .pixelate(CGRect(x: 10, y: 10, width: 50, height: 50)), style: .default)
        doc.add(below)
        doc.add(above)
        #expect(doc.topmost(at: CGPoint(x: 20, y: 20))?.id == above.id)
        #expect(doc.topmost(at: CGPoint(x: 2, y: 2))?.id == below.id)   // outside `above`'s 6pt tolerance
        #expect(doc.topmost(at: CGPoint(x: 100, y: 100)) == nil)
    }

    @Test func notifiesOnEveryChangeIncludingUndo() {
        let doc = AnnotationDocument()
        var changes = 0
        doc.onChange = { changes += 1 }
        doc.add(rect(0))
        doc.undo()
        doc.redo()
        #expect(changes == 3)
    }

    @Test func actionNamesDescribeTheChange() {
        let doc = AnnotationDocument()
        let a = Annotation(kind: .arrow(from: .zero, to: CGPoint(x: 10, y: 0)), style: .default)
        doc.add(a)
        #expect(doc.undoManager.undoActionName == "Add Arrow")
        doc.remove(a.id)
        #expect(doc.undoManager.undoActionName == "Delete Arrow")
    }
}
