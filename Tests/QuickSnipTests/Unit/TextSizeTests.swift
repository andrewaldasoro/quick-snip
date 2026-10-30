import CoreGraphics
import Testing

@testable import QuickSnip

struct TextSizeTests {
    @Test(arguments: [(CGFloat(2), CGFloat(8)), (36, 36), (36.4, 36), (36.6, 37), (999, 200)])
    func clampRoundsIntoTheRange(input: CGFloat, expected: CGFloat) {
        #expect(TextSize.clamp(input) == expected)
    }

    @Test(arguments: [("36", CGFloat(36)), (" 48px ", 48), ("12 PX", 12), ("1000", 200), ("3", 8)])
    func parseAcceptsNumbersWithOptionalUnit(text: String, expected: CGFloat) {
        #expect(TextSize.parse(text) == expected)
    }

    @Test(arguments: ["", "abc", "px", "nan", "inf"])
    func parseRejectsAnythingElse(text: String) {
        #expect(TextSize.parse(text) == nil)
    }

    @Test func defaultIsInRange() {
        #expect(TextSize.range.contains(TextSize.default))
    }
}
