import AppKit
import SwiftUI
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
            updates: UpdatesModel(updater: FakeUpdater(), activation: SpyAppActivation()),
            activation: SpyAppActivation()
        )
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        controller.show()
        controller.show()
        let opened = NSApp.windows.filter { !before.contains(ObjectIdentifier($0)) }
        #expect(opened.count == 1)
        let window = try #require(opened.first)
        #expect(window.title == SettingsWindowController.title)
        #expect(window.isVisible)
        window.close()
    }

    /// Settings is a sidebar window whose content runs under a transparent title bar.
    @Test func settingsIsASidebarWindow() throws {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let controller = SettingsWindowController(
            settings: AppSettings(defaults: TestDefaults().defaults),
            launchAtLogin: LaunchAtLoginModel(service: FakeLoginItemService()),
            hotkey: CaptureHotkey(read: { "⇧⌘2" }),
            updates: UpdatesModel(updater: FakeUpdater(), activation: SpyAppActivation()),
            changelog: FakeChangelog(markdown: "## [1.0.0] - 2026-10-14\n### Added\n- Snap\n"),
            version: "1.0.0",
            activation: SpyAppActivation()
        )
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        controller.show()
        let window = try #require(NSApp.windows.first { !before.contains(ObjectIdentifier($0)) })
        defer { window.close() }

        let root = try #require(window.contentViewController as? NSHostingController<SettingsRootView>).rootView
        #expect(root.releases.map(\.version) == ["1.0.0"])
        #expect(root.version == "1.0.0")
        #expect(controller.navigation.page == .general)
        #expect(window.styleMask.contains(.fullSizeContentView))
        #expect(window.titlebarAppearsTransparent)
        #expect(window.contentLayoutRect.size.width >= SettingsRootView.size.width - 1)
    }

    /// Regression: the window opened as a bare title bar (content 1×0).
    @Test func windowIsSizedToItsContent() throws {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let controller = SettingsWindowController(
            settings: AppSettings(defaults: TestDefaults().defaults),
            launchAtLogin: LaunchAtLoginModel(service: FakeLoginItemService()),
            hotkey: CaptureHotkey(read: { "⇧⌘2" }),
            updates: UpdatesModel(updater: FakeUpdater(), activation: SpyAppActivation()),
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
            updates: UpdatesModel(updater: FakeUpdater(), activation: SpyAppActivation()),
            activation: activation
        )
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))

        controller.show()
        controller.show()

        #expect(activation.activateCount == 2)
        NSApp.windows.first { !before.contains(ObjectIdentifier($0)) }?.close()
    }
}
