import Testing

@testable import QuickSnip

struct StyleChoicesTests {
    private let stroke = StyleOptions.stroke(lineWidth: 4)
    private let text = StyleOptions.text(font: .serif, size: 22, alignment: .left)

    @Test func widthListHasEveryPresetAndOpensOnTheCurrentOne() {
        #expect(StyleChoices.values(for: .lineWidth, options: stroke, fontFamilies: []) == LineWidth.presets.map(StyleValue.lineWidth))
        #expect(StyleChoices.current(for: .lineWidth, options: stroke, color: .red) == .lineWidth(4))
    }

    @Test func fontListHasTheCuratedFontsThenInstalledFamilies() {
        let values = StyleChoices.values(for: .font, options: text, fontFamilies: ["Avenir", "Menlo"])
        #expect(values == TextFont.curated.map(StyleValue.font) + [.font(.family("Avenir")), .font(.family("Menlo"))])
        #expect(StyleChoices.current(for: .font, options: text, color: .red) == .font(.serif))
    }

    @Test func sizeListIncludesAnOddCurrentSize() {
        let values = StyleChoices.values(for: .fontSize, options: .text(font: .system, size: 41, alignment: .left), fontFamilies: [])
        #expect(values.contains(.fontSize(41)))
        #expect(
            StyleChoices.current(for: .fontSize, options: .text(font: .system, size: 41, alignment: .left), color: .red) == .fontSize(41))
    }

    @Test(arguments: [StyleList.font, .fontSize])
    func textListsAreEmptyForShapes(list: StyleList) {
        #expect(StyleChoices.values(for: list, options: stroke, fontFamilies: ["Avenir"]).isEmpty)
        #expect(StyleChoices.current(for: list, options: stroke, color: .red) == nil)
    }

    @Test func widthListIsEmptyForText() {
        #expect(StyleChoices.values(for: .lineWidth, options: text, fontFamilies: []).isEmpty)
        #expect(StyleChoices.current(for: .lineWidth, options: text, color: .red) == nil)
    }

    @Test func colorListHasEveryColorForShapesAndText() {
        #expect(StyleChoices.values(for: .color, options: stroke, fontFamilies: []) == AnnotationColor.allCases.map(StyleValue.color))
        #expect(StyleChoices.values(for: .color, options: text, fontFamilies: []).count == AnnotationColor.allCases.count)
        #expect(StyleChoices.current(for: .color, options: text, color: .blue) == .color(.blue))
        #expect(!StyleChoices.isSearchable(.color))
    }

    @Test func onlyTheFontListIsSearchable() {
        #expect(StyleChoices.isSearchable(.font))
        #expect(!StyleChoices.isSearchable(.fontSize))
        #expect(!StyleChoices.isSearchable(.lineWidth))
    }

    @Test(arguments: [
        (StyleValue.color(.purple), "Purple"), (.lineWidth(4), "4 px"), (.fontSize(22), "22 px"), (.font(.serif), "Serif"),
        (.font(.family("Avenir")), "Avenir"),
    ])
    func titles(value: StyleValue, title: String) {
        #expect(value.title == title)
    }
}
