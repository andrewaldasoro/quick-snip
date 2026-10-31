import AppKit
import Testing

@testable import QuickSnip

struct ArrowHeadsTests {
    @Test(
        arguments: [
            (ArrowHeads.none, false, false, "Line"),
            (.end, false, true, "Arrow"),
            (.both, true, true, "Double Arrow"),
        ] as [(ArrowHeads, Bool, Bool, String)])
    func headsAndName(heads: ArrowHeads, start: Bool, end: Bool, name: String) {
        #expect(heads.hasStartHead == start)
        #expect(heads.hasEndHead == end)
        #expect(heads.annotationName == name)
    }

    @Test(arguments: ArrowHeads.allCases)
    func symbolExists(heads: ArrowHeads) {
        #expect(NSImage(systemSymbolName: heads.symbol, accessibilityDescription: nil) != nil)
    }
}
