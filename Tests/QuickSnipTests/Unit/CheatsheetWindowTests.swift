import AppKit
import SwiftUI
import Testing

@testable import QuickSnip

@MainActor
struct AppDelegateCheatsheetTests {
    @Test func menuItemShowsCheatsheet() {
        let delegate = AppDelegate()
        let spy = SpyCheatsheetWindow()
        delegate.cheatsheetWindow = spy
        delegate.showCheatsheet()
        #expect(spy.showCount == 1)
    }
}

@MainActor
struct CheatsheetWindowControllerTests {
    private func openedWindow(by action: () -> Void) throws -> NSWindow {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        action()
        return try #require(NSApp.windows.first { !before.contains(ObjectIdentifier($0)) })
    }

    @Test func showReusesOneTitledWindow() throws {
        let controller = CheatsheetWindowController(hotkey: CaptureHotkey(read: { "⇧⌘2" }), activation: SpyAppActivation())
        let window = try openedWindow {
            controller.show()
            controller.show()
        }
        defer { window.close() }
        #expect(NSApp.windows.filter { $0.title == CheatsheetWindowController.title && $0.isVisible }.count == 1)
        #expect(window.title == "Keyboard Shortcuts")
    }

    @Test func windowIsSizedToItsContent() throws {
        let controller = CheatsheetWindowController(hotkey: CaptureHotkey(read: { "⇧⌘2" }), activation: SpyAppActivation())
        let window = try openedWindow { controller.show() }
        defer { window.close() }
        #expect(window.contentLayoutRect.size == CheatsheetView.size)
    }

    @Test func showingActivatesTheApp() throws {
        let activation = SpyAppActivation()
        let controller = CheatsheetWindowController(hotkey: CaptureHotkey(read: { "⇧⌘2" }), activation: activation)
        let window = try openedWindow { controller.show() }
        defer { window.close() }
        #expect(activation.activateCount == 1)
    }

    @Test func showingRereadsTheHotkey() throws {
        let source = FakeHotkeySource("⇧⌘2")
        let hotkey = source.makeHotkey()
        let controller = CheatsheetWindowController(hotkey: hotkey, activation: SpyAppActivation())
        source.text = "⌃⌥S"

        let window = try openedWindow { controller.show() }
        defer { window.close() }

        #expect(hotkey.displayText == "⌃⌥S")
    }
}
