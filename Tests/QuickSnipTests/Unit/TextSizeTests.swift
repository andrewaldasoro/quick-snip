import CoreGraphics
import Testing

@testable import QuickSnip

struct TextSizeTests {
    @Test(arguments: [(CGFloat(2), CGFloat(8)), (36, 36), (36.4, 36), (36.6, 37), (999, 200)])
    func clampRoundsIntoTheRange(input: CGFloat, expected: CGFloat) {
        #expect(TextSize.clamp(input) == expected)
    }

    @Test func presetsAndDefaultAreInRangeAndSorted() {
        #expect(TextSize.presets.allSatisfy { TextSize.range.contains($0) })
        #expect(TextSize.presets == TextSize.presets.sorted())
        #expect(TextSize.presets.contains(TextSize.default))
    }

    @Test func choicesAreThePresetsForAPresetSize() {
        #expect(TextSize.choices(including: 22) == TextSize.presets)
    }

    /// A corner drag can make any size; the menu still shows it, in order.
    @Test func choicesIncludeAnOddCurrentSize() {
        let choices = TextSize.choices(including: 41)
        #expect(choices.contains(41))
        #expect(choices == choices.sorted())
        #expect(choices.count == TextSize.presets.count + 1)
    }
}
