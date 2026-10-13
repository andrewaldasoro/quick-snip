import AppKit
import SwiftUI
import Testing

@testable import QuickSnip

/// The shortcut cheatsheet: the same list from the menu and from Settings, and **?** during a capture.
@MainActor
@Suite("Cheatsheet flow")
struct CheatsheetFlowTests {
    private func openedWindow(by action: () -> Void) throws -> NSWindow {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        action()
        return try #require(NSApp.windows.first { !before.contains(ObjectIdentifier($0)) })
    }

    @Test func menuAndSettingsShowTheSameShortcuts() throws {
        let hotkey = CaptureHotkey(read: { "⌃⌥S" })
        let settings = SettingsWindowController(
            settings: AppSettings(defaults: TestDefaults().defaults),
            launchAtLogin: LaunchAtLoginModel(service: FakeLoginItemService()),
            hotkey: hotkey,
            activation: SpyAppActivation()
        )
        let cheatsheet = CheatsheetWindowController(hotkey: hotkey, activation: SpyAppActivation())

        let settingsWindow = try openedWindow { settings.show() }
        defer { settingsWindow.close() }
        let cheatsheetWindow = try openedWindow { cheatsheet.show() }
        defer { cheatsheetWindow.close() }

        let settingsTabs = try #require(settingsWindow.contentViewController as? NSTabViewController)
        let fromSettings = try #require(
            settingsTabs.tabViewItems.compactMap { $0.viewController as? NSHostingController<CheatsheetView> }.first)
        let fromMenu = try #require(cheatsheetWindow.contentViewController as? NSHostingController<CheatsheetView>)
        #expect(fromSettings.rootView.hotkey.cheatsheet == fromMenu.rootView.hotkey.cheatsheet)
        #expect(fromMenu.rootView.hotkey.cheatsheet == ShortcutCheatsheet(captureShortcut: "⌃⌥S"))
    }

    @Test func questionMarkShowsShortcutsAndEscapeOnlyClosesThem() async throws {
        let presenter = SpyOverlayPresenter()
        let controller = CaptureController(
            capturer: FakeDisplayCapturing(displays: [
                TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 300, height: 200), scale: 2)
            ]),
            presenter: presenter,
            pasteboard: SpyPasteboard(),
            saver: ScreenshotSaver(directory: TestImages.temporaryDirectory())
        )
        await controller.start()
        let session = try #require(presenter.lastSession)
        func press(_ chars: String, keyCode: UInt16, _ modifiers: NSEvent.ModifierFlags = []) {
            if let command = OverlayKeyMap.command(keyCode: keyCode, modifiers: modifiers, charactersIgnoringModifiers: chars) {
                presenter.send(command)
            }
        }

        press("?", keyCode: 44, .shift)
        #expect(session.isShowingCheatsheet)

        press("\u{1b}", keyCode: OverlayKeyMap.escape)
        #expect(!session.isShowingCheatsheet)
        #expect(presenter.isPresenting)

        press("\u{1b}", keyCode: OverlayKeyMap.escape)
        #expect(!presenter.isPresenting)
    }
}
