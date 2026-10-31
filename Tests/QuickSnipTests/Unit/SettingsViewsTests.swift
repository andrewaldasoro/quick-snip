import AppKit
import KeyboardShortcuts
import SwiftUI
import Testing

@testable import QuickSnip

/// Every Settings page renders, with and without an update waiting.
@MainActor
struct SettingsViewsTests {
    private let releases = Changelog.releases(
        fromMarkdown: "## [1.0.0] - 2026-10-14\n### Added\n- **Window snap**\n### Fixed\n- A crash\n")

    private func makeRoot(page: SettingsPage, update: (version: String, notesHTML: String?)? = nil) -> SettingsRootView {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let updater = FakeUpdater()
        let updates = UpdatesModel(updater: updater, activation: SpyAppActivation())
        updater.onCheckFinished?(update)
        let navigation = SettingsNavigation()
        navigation.page = page
        return SettingsRootView(
            navigation: navigation,
            settings: AppSettings(defaults: TestDefaults().defaults),
            launchAtLogin: LaunchAtLoginModel(service: FakeLoginItemService()),
            hotkey: CaptureHotkey(read: { "⌃⌥S" }, restoreDefault: {}, defaultText: "⇧⌘2"),
            updates: updates,
            releases: releases,
            version: "1.0.0"
        )
    }

    /// Lays the view out in a window, which runs every body it shows.
    private func render(_ view: some View) -> NSView {
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: SettingsRootView.size), styleMask: .titled, backing: .buffered, defer: true)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        _ = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds).map { hosting.cacheDisplay(in: hosting.bounds, to: $0) }
        return hosting
    }

    @Test(arguments: SettingsPage.allCases)
    func everyPageRenders(page: SettingsPage) {
        let view = render(makeRoot(page: page))
        #expect(view.frame.size == SettingsRootView.size)
    }

    @Test(arguments: SettingsPage.allCases)
    func everyPageRendersWithAnUpdateWaiting(page: SettingsPage) {
        let view = render(makeRoot(page: page, update: (version: "1.1.0", notesHTML: "<ul><li>Fonts</li></ul>")))
        #expect(view.frame.size == SettingsRootView.size)
    }

    @Test func whatsNewExplainsMissingNotes() {
        let view = render(
            WhatsNewPage(
                updates: UpdatesModel(updater: FakeUpdater(), activation: SpyAppActivation()), releases: [], installedVersion: "1.0.0"))
        #expect(view.fittingSize.height > 0)
    }

    @Test func cheatsheetWindowContentRenders() {
        let view = render(CheatsheetView(hotkey: CaptureHotkey(read: { nil }, restoreDefault: {}, defaultText: "⇧⌘2")))
        #expect(view.fittingSize == CheatsheetView.size)
    }

    @Test func releaseNoteItemsKeepTheirMarkdown() {
        let formatted = ReleaseNotesList.formatted("**Bold** text")
        #expect(String(formatted.characters) == "Bold text")
    }
}

@MainActor
struct ShortcutRecorderFieldTests {
    @Test func endingTheEditReportsTheEnd() throws {
        _ = NSApplication.shared
        var ended = 0
        let hosting = NSHostingView(rootView: ShortcutRecorderField(name: .init("settingsViewsTest")) { ended += 1 })
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 200, height: 40), styleMask: .titled, backing: .buffered, defer: true)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let recorder = try #require(Self.find(KeyboardShortcuts.RecorderCocoa.self, in: hosting))

        NotificationCenter.default.post(name: NSControl.textDidEndEditingNotification, object: recorder)

        #expect(ended == 1)
        window.contentView = nil
    }

    private static func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let match = find(type, in: subview) { return match }
        }
        return nil
    }
}
