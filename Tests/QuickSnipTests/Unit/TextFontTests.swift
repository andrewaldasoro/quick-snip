import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct TextFontTests {
    @Test(arguments: TextFont.curated + [.family("Avenir Next"), .family("Font: With Colons")])
    func storageValueRoundTrips(font: TextFont) {
        #expect(TextFont(storageValue: font.storageValue) == font)
    }

    @Test(arguments: ["", "comic", "family:"])
    func unknownStorageValuesAreRejected(value: String) {
        #expect(TextFont(storageValue: value) == nil)
    }

    @Test func curatedFontsHaveDistinctNames() {
        #expect(Set(TextFont.curated.map(\.displayName)).count == TextFont.curated.count)
        #expect(TextFont.family("Avenir Next").displayName == "Avenir Next")
    }

    @Test func fontHasTheRequestedSize() {
        for font in TextFont.curated {
            #expect(font.font(size: 31).pointSize == 31)
        }
    }

    @Test func systemFontIsSemibold() {
        let font = TextFont.system.font(size: 20)
        #expect(font == NSFont.systemFont(ofSize: 20, weight: .semibold))
    }

    @Test func monospacedFontHasFixedAdvances() {
        #expect(TextFont.monospaced.font(size: 20).isFixedPitch)
    }

    @Test func installedFamilyIsUsed() {
        #expect(TextFont.family("Helvetica").font(size: 20).familyName == "Helvetica")
    }

    @Test func handwritingUsesItsFamily() {
        #expect(TextFont.handwriting.font(size: 20).familyName == TextFont.handwritingFamily)
    }

    @Test func missingFamilyFallsBackToTheSystemFont() {
        let font = TextFont.family("No Such Font 1234").font(size: 20)
        #expect(font == TextFont.system.font(size: 20))
    }
}
