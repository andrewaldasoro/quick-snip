import AppKit
import Testing

@testable import QuickSnip

struct KeyBindingTests {
    @Test func codeKeysNeedTheExactModifiers() {
        let binding = KeyBinding(.code(53, name: "Esc"), .cancel)
        #expect(binding.matches(keyCode: 53, modifiers: [], characters: "\u{1b}"))
        #expect(!binding.matches(keyCode: 53, modifiers: .command, characters: "\u{1b}"))
        #expect(!binding.matches(keyCode: 36, modifiers: [], characters: "\r"))
    }

    @Test func charactersMatchEitherCase() {
        let binding = KeyBinding(.character("z"), [.command, .shift], .redo)
        #expect(binding.matches(keyCode: 6, modifiers: [.command, .shift], characters: "Z"))
        #expect(binding.matches(keyCode: 6, modifiers: [.command, .shift], characters: "z"))
        #expect(!binding.matches(keyCode: 6, modifiers: .command, characters: "z"))
    }

    @Test func symbolsIgnoreShiftOnly() {
        let binding = KeyBinding(.symbol("?"), .toggleCheatsheet)
        #expect(binding.matches(keyCode: 44, modifiers: .shift, characters: "?"))
        #expect(binding.matches(keyCode: 27, modifiers: [], characters: "?"))
        #expect(!binding.matches(keyCode: 44, modifiers: [.shift, .option], characters: "?"))
    }

    @Test(
        arguments: [
            (KeyBinding(.character("z"), [.command, .shift], .redo), "⇧⌘Z"),
            (KeyBinding(.character("r"), .selectTool(.shape)), "R"),
            (KeyBinding(.code(53, name: "Esc"), .cancel), "Esc"),
            (KeyBinding(.symbol("?"), .toggleCheatsheet), "?"),
            (KeyBinding(.character("c"), [.command, .option, .control], .copy), "⌃⌥⌘C"),
        ])
    func displayTextListsModifiersInMenuOrder(binding: KeyBinding, text: String) {
        #expect(binding.displayText == text)
    }
}
