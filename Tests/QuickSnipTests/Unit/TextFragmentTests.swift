import CoreGraphics
import Testing

@testable import QuickSnip

struct TextFragmentTests {
    /// Vision's space: normalized, bottom-left origin, so a higher `y` is further up.
    private func fragment(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat = 0.2, height: CGFloat = 0.05) -> TextFragment {
        TextFragment(text: text, bounds: CGRect(x: x, y: y, width: width, height: height))
    }

    @Test func linesReadTopToBottom() {
        let text = TextFragment.readingOrder([fragment("second", x: 0.1, y: 0.4), fragment("first", x: 0.1, y: 0.8)])
        #expect(text == "first\nsecond")
    }

    @Test func fragmentsOnOneLineReadLeftToRight() {
        let text = TextFragment.readingOrder([fragment("Total", x: 0.6, y: 0.5), fragment("Name", x: 0.1, y: 0.51)])
        #expect(text == "Name Total")
    }

    @Test func slightlyOffsetLineStaysSeparate() {
        let text = TextFragment.readingOrder([fragment("a", x: 0.1, y: 0.5), fragment("b", x: 0.5, y: 0.44)])
        #expect(text == "a\nb")
    }

    @Test func nothingRecognizedIsEmpty() {
        #expect(TextFragment.readingOrder([]) == "")
    }
}
