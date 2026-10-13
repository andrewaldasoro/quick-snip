import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct AppDelegateSettingsTests {
    @Test func reopeningAppShowsSettings() {
        let delegate = AppDelegate()
        let spy = SpySettingsWindow()
        delegate.settingsWindow = spy
        let handled = delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        #expect(spy.showCount == 1)
        #expect(!handled)
    }

    @Test func menuItemShowsSettings() {
        let delegate = AppDelegate()
        let spy = SpySettingsWindow()
        delegate.settingsWindow = spy
        delegate.showSettings()
        #expect(spy.showCount == 1)
    }
}

@MainActor
struct SettingsWindowControllerTests {
    @Test func showReusesOneWindow() throws {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let store = TestDefaults()
        let controller = SettingsWindowController(
            settings: AppSettings(defaults: store.defaults),
            launchAtLogin: LaunchAtLoginModel(service: FakeLoginItemService()),
            hotkey: CaptureHotkey(read: { "⇧⌘2" }),
            activation: SpyAppActivation()
        )
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        controller.show()
        controller.show()
        let opened = NSApp.windows.filter { !before.contains(ObjectIdentifier($0)) }
        #expect(opened.count == 1)
        let window = try #require(opened.first)
        #expect(window.title == "General")
        #expect(window.isVisible)
        window.close()
    }

    /// Regression: SwiftUI tabs drawn at the top of the form looked out of place; Settings uses
    /// native toolbar tabs instead.
    @Test func tabsAreNativeToolbarTabs() throws {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let controller = SettingsWindowController(
            settings: AppSettings(defaults: TestDefaults().defaults),
            launchAtLogin: LaunchAtLoginModel(service: FakeLoginItemService()),
            hotkey: CaptureHotkey(read: { "⇧⌘2" }),
            activation: SpyAppActivation()
        )
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        controller.show()
        let window = try #require(NSApp.windows.first { !before.contains(ObjectIdentifier($0)) })
        defer { window.close() }

        let tabs = try #require(window.contentViewController as? NSTabViewController)
        #expect(tabs.tabStyle == .toolbar)
        #expect(tabs.tabViewItems.map(\.label) == ["General", "Shortcuts"])
        #expect(tabs.tabViewItems.allSatisfy { $0.image != nil })
        #expect(window.toolbarStyle == .preference)
    }

    /// Regression: the window opened as a bare title bar (content 1×0).
    @Test func windowIsSizedToItsContent() throws {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let controller = SettingsWindowController(
            settings: AppSettings(defaults: TestDefaults().defaults),
            launchAtLogin: LaunchAtLoginModel(service: FakeLoginItemService()),
            hotkey: CaptureHotkey(read: { "⇧⌘2" }),
            activation: SpyAppActivation()
        )
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        controller.show()
        let window = try #require(NSApp.windows.first { !before.contains(ObjectIdentifier($0)) })
        defer { window.close() }
        #expect(window.contentLayoutRect.width >= 400)
        #expect(window.contentLayoutRect.height >= 200)
    }
}

@MainActor
struct SettingsWindowFocusTests {
    /// Regression: Settings opened from the menu bar came to the front without focus,
    /// because macOS declined a plain activation request for a Dock-less app.
    @Test func showingSettingsActivatesTheApp() {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let activation = SpyAppActivation()
        let controller = SettingsWindowController(
            settings: AppSettings(defaults: TestDefaults().defaults),
            launchAtLogin: LaunchAtLoginModel(service: FakeLoginItemService()),
            hotkey: CaptureHotkey(read: { "⇧⌘2" }),
            activation: activation
        )
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))

        controller.show()
        controller.show()

        #expect(activation.activateCount == 2)
        NSApp.windows.first { !before.contains(ObjectIdentifier($0)) }?.close()
    }
}
