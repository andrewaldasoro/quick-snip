import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct TextLayoutTests {
    private func style(_ alignment: TextAlignment) -> AnnotationStyle {
        AnnotationStyle(alignment: alignment)
    }

    /// Click text's box starts at its origin whatever the alignment; alignment only lines the
    /// lines up inside it.
    @Test(arguments: TextAlignment.allCases)
    func clickTextStartsAtItsOrigin(alignment: TextAlignment) {
        let frame = TextLayout.frame("Hello\nlonger line", origin: CGPoint(x: 200, y: 50), boxWidth: nil, style: style(alignment))
        let left = TextLayout.frame("Hello\nlonger line", origin: CGPoint(x: 200, y: 50), boxWidth: nil, style: style(.left))
        #expect(frame == left)
        #expect(frame.origin == CGPoint(x: 200, y: 50))
    }

    @Test func boxedTextKeepsTheBoxWidthAndWraps() {
        let oneLine = TextLayout.frame("Hi", origin: CGPoint(x: 10, y: 10), boxWidth: 100, style: .default)
        let wrapped = TextLayout.frame(
            "A sentence long enough to wrap twice or more", origin: CGPoint(x: 10, y: 10), boxWidth: 100, style: .default)
        #expect(oneLine == CGRect(x: 10, y: 10, width: 100, height: oneLine.height))
        #expect(wrapped.width == 100)
        #expect(wrapped.height > oneLine.height * 2)
    }

    @Test func lineBreaksInABoxEachGetALine() {
        let one = TextLayout.frame("One", origin: .zero, boxWidth: 200, style: .default)
        let three = TextLayout.frame("One\nTwo\nThree", origin: .zero, boxWidth: 200, style: .default)
        #expect(three.height >= one.height * 3 - 1)
    }

    @Test func anEmptyBoxIsStillOneLineTall() {
        let frame = TextLayout.frame("", origin: .zero, boxWidth: 100, style: .default)
        #expect(frame.height == TextLayout.lineHeight(.default))
    }

    @Test func attributedTextCarriesTheAlignment() {
        let text = TextLayout.attributed("Hi", style: style(.right))
        let paragraph = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(paragraph?.alignment == .right)
    }

    @Test(arguments: TextAlignment.allCases)
    func everyAlignmentHasARealSymbolAndName(alignment: TextAlignment) {
        #expect(NSImage(systemSymbolName: alignment.symbol, accessibilityDescription: nil) != nil)
        #expect(alignment.displayName.hasPrefix("Align"))
        #expect(alignment.nsAlignment.rawValue >= 0)
    }
}

struct TextPlacementTests {
    @Test func aShortDragIsAClickAtItsStart() {
        #expect(
            TextPlacement.from(drag: CGPoint(x: 50, y: 60), to: CGPoint(x: 60, y: 90), minimumBoxWidth: 24)
                == .line(at: CGPoint(x: 50, y: 60)))
    }

    @Test func aWideDragIsABoxFromItsLeftEdgeEitherWay() {
        let rightward = TextPlacement.from(drag: CGPoint(x: 50, y: 60), to: CGPoint(x: 150, y: 70), minimumBoxWidth: 24)
        let leftward = TextPlacement.from(drag: CGPoint(x: 150, y: 70), to: CGPoint(x: 50, y: 60), minimumBoxWidth: 24)
        #expect(rightward == TextPlacement(origin: CGPoint(x: 50, y: 60), boxWidth: 100))
        #expect(leftward == rightward)
    }
}
