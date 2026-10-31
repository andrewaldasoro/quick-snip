import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct TextEntryTests {
    private final class Recorder {
        var finished: [String] = []
    }

    private func make(_ placement: TextPlacement, alignment: TextAlignment = .left, text: String = "") -> (TextEntry, Recorder) {
        let recorder = Recorder()
        let request = TextEditRequest(placement: placement, style: AnnotationStyle(alignment: alignment), text: text, annotationID: nil)
        let entry = TextEntry(request: request) { recorder.finished.append($0) }
        return (entry, recorder)
    }

    @Test func clickTextStartsAtTheClickAndGrowsRightWhenLeftAligned() {
        let (entry, _) = make(.line(at: CGPoint(x: 100, y: 50)))
        #expect(entry.editor.frame.minX == 100)
        #expect(entry.editor.frame.minY == 50)
        let narrow = entry.editor.frame.width
        entry.editor.string = "A much longer line of text"
        entry.layout()
        #expect(entry.editor.frame.width > narrow)
        #expect(entry.editor.frame.minX == 100)
        #expect(!entry.isBox)
    }

    /// Click text is a box anchored on its left edge, whatever the alignment.
    @Test func rightAlignedClickTextStillStartsAtTheClick() {
        let (entry, _) = make(.line(at: CGPoint(x: 300, y: 50)), alignment: .right)
        entry.editor.string = "Short\nA longer line"
        entry.layout()
        #expect(entry.editor.frame.minX == 300)
        #expect(entry.editor.alignment == .right)
        let longest = ceil(TextLayout.attributed("A longer line", style: AnnotationStyle(alignment: .right)).size().width)
        #expect(entry.editor.textContainer?.containerSize.width == longest)  // lines align within the text's own width
    }

    @Test func clickTextIsAsWideAsItsLongestLine() {
        let (entry, _) = make(.line(at: .zero), text: "Short\nA much longer second line")
        let longest = TextLayout.attributed("A much longer second line", style: AnnotationStyle()).size().width
        #expect(entry.editor.frame.width == ceil(longest) + TextEntry.caretRoom)
        #expect(entry.editor.frame.height >= TextLayout.lineHeight(AnnotationStyle()) * 2)
    }

    @Test func aBoxKeepsItsWidthAndGrowsDown() {
        let (entry, _) = make(TextPlacement(origin: CGPoint(x: 40, y: 30), boxWidth: 120))
        let oneLine = entry.editor.frame
        #expect(oneLine == CGRect(x: 40, y: 30, width: 120, height: TextLayout.lineHeight(AnnotationStyle())))
        entry.editor.string = "Enough words here to wrap onto several lines inside the box"
        entry.layout()
        #expect(entry.editor.frame.width == 120)
        #expect(entry.editor.frame.height > oneLine.height * 2)
        #expect(entry.isBox)
    }

    @Test func existingTextOpensWithItsText() {
        let (entry, _) = make(.line(at: .zero), text: "Hello")
        #expect(entry.text == "Hello")
    }

    @Test func finishesOnceWithTheText() {
        let (entry, recorder) = make(.line(at: .zero))
        entry.editor.string = "Done"
        entry.finish()
        entry.finish()
        #expect(recorder.finished == ["Done"])
    }

    /// Esc keeps the text, as in Markup and Figma: it ends typing, it doesn't discard.
    @Test func escapeFinishesAndKeepsTheText() {
        let (entry, recorder) = make(.line(at: .zero))
        entry.editor.string = "Kept"
        entry.editor.cancelOperation(nil)
        #expect(recorder.finished == ["Kept"])
    }

    @Test func onlyCommandReturnFinishes() {
        #expect(TextEditorView.isFinishKey(keyCode: 36, modifiers: .command))
        #expect(TextEditorView.isFinishKey(keyCode: 76, modifiers: [.command, .shift]))  // keypad Enter
        #expect(!TextEditorView.isFinishKey(keyCode: 36, modifiers: []))  // plain Return: a new line
        #expect(!TextEditorView.isFinishKey(keyCode: 0, modifiers: .command))
    }
}

/// Typing through the text view in a real window, as the user does.
@MainActor
struct TextEntryEditingTests {
    private final class Recorder {
        var finished: [String] = []
    }

    private func editing(_ placement: TextPlacement) throws -> (TextEntry, NSWindow, Recorder) {
        let recorder = Recorder()
        let entry = TextEntry(request: .new(at: placement, style: AnnotationStyle())) { recorder.finished.append($0) }
        let host = FlippedView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: true)
        window.contentView = host
        host.addSubview(entry.editor)
        #expect(window.makeFirstResponder(entry.editor))
        return (entry, window, recorder)
    }

    private func type(_ text: String, into entry: TextEntry) {
        entry.editor.insertText(text, replacementRange: entry.editor.selectedRange())
    }

    private func pressReturn(in entry: TextEntry) {
        entry.editor.insertNewline(nil)
    }

    /// Regression: Return finished click text, so there was no way to write several lines.
    @Test func returnStartsANewLineInClickText() throws {
        let (entry, _, recorder) = try editing(.line(at: CGPoint(x: 50, y: 40)))
        type("One", into: entry)
        let oneLine = entry.editor.frame

        pressReturn(in: entry)
        type("Two", into: entry)

        #expect(recorder.finished.isEmpty)
        #expect(entry.text == "One\nTwo")
        #expect(entry.editor.frame.minY == oneLine.minY)  // grows down; the first line stays
        #expect(entry.editor.frame.height >= oneLine.height * 2 - 1)
    }

    /// Regression: in a box, the field stayed a line short after Return and scrolled the first
    /// line away, cutting the text off.
    @Test func returnGrowsABoxALineWithoutMovingTheFirstLine() throws {
        let (entry, _, _) = try editing(TextPlacement(origin: CGPoint(x: 20, y: 20), boxWidth: 200))
        type("One", into: entry)
        let oneLine = entry.editor.frame.height

        pressReturn(in: entry)
        #expect(entry.editor.frame.height >= oneLine * 2 - 1)  // the empty new line has room

        type("Two", into: entry)
        pressReturn(in: entry)
        type("Three", into: entry)
        #expect(entry.editor.frame.minY == 20)
        #expect(entry.editor.frame.height >= oneLine * 3 - 1)
        // Every laid-out line fits inside the editor: nothing is cut off.
        let layout = try #require(entry.editor.layoutManager)
        let container = try #require(entry.editor.textContainer)
        #expect(layout.usedRect(for: container).maxY <= entry.editor.frame.height)
        #expect(entry.text == "One\nTwo\nThree")
    }

    @Test func losingFocusFinishes() async throws {
        let (entry, window, recorder) = try editing(.line(at: .zero))
        type("Hi", into: entry)
        window.makeFirstResponder(nil)
        await Task.yield()
        try await Task.sleep(for: .zero)
        #expect(recorder.finished == ["Hi"])
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
