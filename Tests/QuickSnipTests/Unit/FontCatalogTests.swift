import Testing

@testable import QuickSnip

@MainActor
struct FontCatalogTests {
    @Test func familiesAreSortedNaturallyWithoutHiddenOrDuplicates() {
        let catalog = FontCatalog(
            provider: FakeFontFamilies(availableFamilies: ["Zapfino", ".SF NS", "avenir", "Font 10", "Font 9", "Zapfino", ""]))
        #expect(catalog.families == ["avenir", "Font 9", "Font 10", "Zapfino"])
    }

    @Test func emptyQueryMatchesEverything() {
        let catalog = FontCatalog(families: ["Avenir", "Helvetica"])
        #expect(catalog.matching("  ") == ["Avenir", "Helvetica"])
    }

    @Test func queryIgnoresCaseAndAccents() {
        let catalog = FontCatalog(families: ["Avenir", "Hélvetica Neue", "Menlo"])
        #expect(catalog.matching("HELVE") == ["Hélvetica Neue"])
        #expect(catalog.matching("e") == ["Avenir", "Hélvetica Neue", "Menlo"])
        #expect(catalog.matching("xyz").isEmpty)
    }

    @Test func systemProviderListsInstalledFamilies() {
        #expect(SystemFontFamilies().availableFamilies.contains("Helvetica"))
    }
}
