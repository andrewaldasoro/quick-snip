import AppKit
import Testing

@testable import QuickSnip

struct DrawModifiersTests {
    @Test(
        arguments: [
            (NSEvent.ModifierFlags(), DrawModifiers.none),
            (NSEvent.ModifierFlags.shift, DrawModifiers(isConstrained: true)),
            (NSEvent.ModifierFlags.option, DrawModifiers(isFromCenter: true)),
            (NSEvent.ModifierFlags([.shift, .option, .command]), DrawModifiers(isConstrained: true, isFromCenter: true)),
        ] as [(NSEvent.ModifierFlags, DrawModifiers)])
    func shiftConstrainsAndOptionDrawsFromCenter(flags: NSEvent.ModifierFlags, expected: DrawModifiers) {
        #expect(DrawModifiers(flags) == expected)
    }
}
