import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct TextLayoutTests {
    private func style(_ alignment: TextAlignment) -> AnnotationStyle {
        AnnotationStyle(alignment: alignment)
    }

    @Test(arguments: [(TextAlignment.left, CGFloat(0)), (.center, 0.5), (.right, 1)])
    func oneLineSitsAroundItsOriginByAlignment(alignment: TextAlignment, fraction: CGFloat) {
        let frame = TextLayout.frame("Hello", origin: CGPoint(x: 200, y: 50), boxWidth: nil, style: style(alignment))
        #expect(abs(frame.minX - (200 - frame.width * fraction)) < 0.001)
        #expect(frame.minY == 50)
        #expect(frame.width > 0)
    }

    @Test func originForALineFrameIsItsAnchor() {
        let frame = CGRect(x: 100, y: 20, width: 80, height: 30)
        #expect(TextLayout.origin(forLineFrame: frame, alignment: .left) == CGPoint(x: 100, y: 20))
        #expect(TextLayout.origin(forLineFrame: frame, alignment: .center) == CGPoint(x: 140, y: 20))
        #expect(TextLayout.origin(forLineFrame: frame, alignment: .right) == CGPoint(x: 180, y: 20))
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
