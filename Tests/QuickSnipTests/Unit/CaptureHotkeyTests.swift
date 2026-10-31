import Testing

@testable import QuickSnip

@MainActor
struct CaptureHotkeyTests {
    @Test func readsTheShortcutOnCreation() {
        let hotkey = CaptureHotkey(read: { "⇧⌘2" })
        #expect(hotkey.displayText == "⇧⌘2")
    }

    @Test func refreshPicksUpANewShortcut() {
        let source = FakeHotkeySource("⇧⌘2")
        let hotkey = source.makeHotkey()

        source.text = "⌃⌥S"
        hotkey.refresh()

        #expect(hotkey.displayText == "⌃⌥S")
    }

    @Test func cheatsheetShowsTheCurrentShortcut() {
        let source = FakeHotkeySource(nil)
        let hotkey = source.makeHotkey()
        #expect(hotkey.cheatsheet == ShortcutCheatsheet(captureShortcut: nil))

        source.text = "⌃⌥S"
        hotkey.refresh()

        #expect(hotkey.cheatsheet == ShortcutCheatsheet(captureShortcut: "⌃⌥S"))
    }

    @Test func resetIsOfferedOnlyAwayFromTheDefault() {
        let source = FakeHotkeySource("⇧⌘2")
        let hotkey = CaptureHotkey(read: { source.text }, restoreDefault: {}, defaultText: "⇧⌘2")
        #expect(!hotkey.canReset)

        source.text = "⌃⌥S"
        hotkey.refresh()
        #expect(hotkey.canReset)

        source.text = nil
        hotkey.refresh()
        #expect(hotkey.canReset)
    }

    @Test func resetRestoresTheDefaultAndRefreshes() {
        let source = FakeHotkeySource("⌃⌥S")
        let hotkey = CaptureHotkey(read: { source.text }, restoreDefault: { source.text = "⇧⌘2" }, defaultText: "⇧⌘2")

        hotkey.reset()

        #expect(hotkey.displayText == "⇧⌘2")
        #expect(!hotkey.canReset)
    }
}
