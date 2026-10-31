import AppKit
import Testing

@testable import QuickSnip

struct ShapeKindTests {
    @Test func namesReadAsShapes() {
        #expect(ShapeKind.allCases.map(\.displayName) == ["Rectangle", "Oval"])
    }

    @Test(arguments: ShapeKind.allCases)
    func symbolExists(shape: ShapeKind) {
        #expect(NSImage(systemSymbolName: shape.symbol, accessibilityDescription: nil) != nil)
    }
}
