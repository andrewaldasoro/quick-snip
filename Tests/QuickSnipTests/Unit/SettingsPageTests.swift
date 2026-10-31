import AppKit
import Testing

@testable import QuickSnip

struct SettingsPageTests {
    @Test func pagesAreInSidebarOrder() {
        #expect(SettingsPage.allCases == [.general, .shortcuts, .whatsNew, .about])
    }

    @Test func everyPageHasATitleAndARealSymbol() {
        #expect(Set(SettingsPage.allCases.map(\.title)).count == SettingsPage.allCases.count)
        for page in SettingsPage.allCases {
            #expect(NSImage(systemSymbolName: page.symbol, accessibilityDescription: nil) != nil)
            #expect(page.id == page)
        }
    }
}
