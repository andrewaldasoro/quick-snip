import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct TextEntryTests {
    private final class Recorder {
        var committed: [String] = []
        var cancelled = 0
    }

    private func make(_ placement: TextPlacement, alignment: TextAlignment = .left) -> (TextEntry, Recorder) {
        let recorder = Recorder()
        let entry = TextEntry(
            placement: placement, style: AnnotationStyle(alignment: alignment),
            onCommit: { recorder.committed.append($0) }, onCancel: { recorder.cancelled += 1 })
        return (entry, recorder)
    }

    private func command(_ entry: TextEntry, _ selector: Selector) -> Bool {
        entry.control(entry.field, textView: NSTextView(), doCommandBy: selector)
    }

    @Test func aLineStartsAtTheClickAndGrowsRightWhenLeftAligned() {
        let (entry, _) = make(.line(at: CGPoint(x: 100, y: 50)))
        #expect(entry.field.frame.minX == 100 - TextEntry.fieldInset)
        let narrow = entry.field.frame.width
        entry.field.stringValue = "A much longer line of text"
        entry.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        #expect(entry.field.frame.width > narrow)
        #expect(entry.field.frame.minX == 100 - TextEntry.fieldInset)
        #expect(!entry.isBox)
    }

    @Test func aRightAlignedLineEndsAtTheClick() {
        let (entry, _) = make(.line(at: CGPoint(x: 300, y: 50)), alignment: .right)
        entry.field.stringValue = "Ends here"
        entry.layout()
        #expect(abs(entry.field.frame.maxX - TextEntry.fieldInset - 300) < 0.001)
        #expect(entry.field.alignment == .right)
    }

    @Test func aBoxKeepsItsWidthAndGrowsDown() {
        let (entry, _) = make(TextPlacement(origin: CGPoint(x: 40, y: 30), boxWidth: 120))
        let oneLine = entry.field.frame
        #expect(oneLine.width == 120 + TextEntry.fieldInset * 2)
        entry.field.stringValue = "Enough words here to wrap onto several lines inside the box"
        entry.layout()
        #expect(entry.field.frame.width == oneLine.width)
        #expect(entry.field.frame.height > oneLine.height)
        #expect(entry.isBox)
        #expect(entry.field.cell?.wraps == true)
    }

    @Test func returnInABoxStartsANewLine() {
        let (entry, recorder) = make(TextPlacement(origin: .zero, boxWidth: 120))
        let textView = NSTextView()
        textView.string = "One"
        #expect(entry.control(entry.field, textView: textView, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        #expect(recorder.committed.isEmpty)
    }

    @Test func returnOnALineIsLeftToTheFieldToCommit() {
        let (entry, recorder) = make(.line(at: .zero))
        #expect(!command(entry, #selector(NSResponder.insertNewline(_:))))
        entry.field.stringValue = "Done"
        _ = entry.field.sendAction(entry.field.action, to: entry.field.target)
        #expect(recorder.committed == ["Done"])
    }

    @Test func escapeCancelsOnce() {
        let (entry, recorder) = make(.line(at: .zero))
        #expect(command(entry, #selector(NSResponder.cancelOperation(_:))))
        entry.cancel()
        entry.commit()
        #expect(recorder.cancelled == 1)
        #expect(recorder.committed.isEmpty)
    }

    @Test func endingTheEditCommitsOnce() {
        let (entry, recorder) = make(.line(at: .zero))
        entry.field.stringValue = "Hi"
        entry.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification))
        entry.commit()
        #expect(recorder.committed == ["Hi"])
    }

    @Test func otherCommandsAreLeftToTheField() {
        let (entry, _) = make(.line(at: .zero))
        #expect(!command(entry, #selector(NSResponder.moveLeft(_:))))
    }
}
