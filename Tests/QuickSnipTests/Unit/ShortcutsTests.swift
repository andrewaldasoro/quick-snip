import KeyboardShortcuts
import Testing
@testable import QuickSnip

struct ShortcutsTests {
    @Test func captureAreaDefaultIsCommandShift2() {
        let shortcut = KeyboardShortcuts.Name.captureArea.defaultShortcut
        #expect(shortcut == .init(.two, modifiers: [.command, .shift]))
    }

    @Test(arguments: [KeyboardShortcuts.Key.three, .four, .five, .six])
    func captureAreaDefaultAvoidsSystemScreenshotShortcuts(systemKey: KeyboardShortcuts.Key) {
        let systemShortcut = KeyboardShortcuts.Shortcut(systemKey, modifiers: [.command, .shift])
        #expect(KeyboardShortcuts.Name.captureArea.defaultShortcut != systemShortcut)
    }
}
