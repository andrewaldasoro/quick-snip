import Testing

@testable import QuickSnip

struct ShortcutCheatsheetTests {
    private func entry(_ action: String, in cheatsheet: ShortcutCheatsheet) -> ShortcutCheatsheet.Entry? {
        cheatsheet.sections.flatMap(\.entries).first { $0.action == action }
    }

    @Test func listsSectionsInOrder() {
        let titles = ShortcutCheatsheet(captureShortcut: "⇧⌘2").sections.map(\.title)
        #expect(titles == ["Anywhere", "While capturing", "Tools", "Colors", "Drawing", "Text"])
    }

    @Test func showsTheCurrentCaptureHotkey() {
        let cheatsheet = ShortcutCheatsheet(captureShortcut: "⌃⌥S")
        #expect(entry("Capture area", in: cheatsheet)?.keys == ["⌃⌥S"])
    }

    @Test func showsWhenNoCaptureHotkeyIsSet() {
        let cheatsheet = ShortcutCheatsheet(captureShortcut: nil)
        #expect(entry("Capture area", in: cheatsheet)?.keys == [ShortcutCheatsheet.notSet])
    }

    @Test func overlayLeavesOutTheGlobalHotkey() {
        #expect(ShortcutCheatsheet.overlay.sections.map(\.title) == ["While capturing", "Tools", "Colors", "Drawing", "Text"])
    }

    /// The cheatsheet can't drift from the real key handling.
    @Test(arguments: OverlayKeyMap.bindings.map { ($0.command, $0.displayText) })
    func everyOverlayBindingIsListed(command: OverlayCommand, key: String) {
        let listed = entry(ShortcutCheatsheet.action(for: command), in: .overlay)
        #expect(listed?.keys.contains(key) == true)
    }

    @Test func drawingModifiersAreListed() {
        #expect(entry("Square, circle, 45° line", in: .overlay)?.keys == ["⇧ Drag"])
        #expect(entry("Shape from its center", in: .overlay)?.keys == ["⌥ Drag"])
        #expect(entry("Resize in proportion", in: .overlay)?.keys == ["⇧ Corner"])
    }

    @Test func toolsAndColorsFollowToolbarOrder() {
        let sections = ShortcutCheatsheet.overlay.sections
        #expect(sections[1].entries.map(\.action) == AnnotationTool.allCases.map(\.displayName))
        #expect(sections[2].entries.map(\.keys) == (1...8).map { [String($0)] })
    }

    @Test func actionsAreUnique() {
        let actions = ShortcutCheatsheet(captureShortcut: nil).sections.flatMap(\.entries).map(\.action)
        #expect(Set(actions).count == actions.count)
    }

    /// Regression: the cheatsheet still said Return places text and Esc discards it.
    @Test func textKeysMatchTheEditor() throws {
        let text = try #require(ShortcutCheatsheet.overlay.sections.first { $0.title == "Text" })
        #expect(text.entries.first { $0.action == "Start a new line" }?.keys == ["Return"])
        #expect(text.entries.first { $0.action == "Finish typing" }?.keys == ["Esc", "⌘Return"])
        #expect(text.entries.contains { $0.action == "Edit placed text" })
        #expect(TextEditorView.isFinishKey(keyCode: 36, modifiers: .command))
        #expect(!TextEditorView.isFinishKey(keyCode: 36, modifiers: []))
    }
}
