import AppKit
import SwiftUI

@MainActor
protocol SettingsPresenting: AnyObject {
    func show()
}

/// Settings in a plain AppKit window, so it can be opened without the menu bar icon
/// (SwiftUI's `Settings` scene can only be opened reliably from a `SettingsLink`).
@MainActor
final class SettingsWindowController: SettingsPresenting {
    static let title = "QuickSnip Settings"

    let navigation = SettingsNavigation()
    private let settings: AppSettings
    private let launchAtLogin: LaunchAtLoginModel
    private let hotkey: CaptureHotkey
    private let updates: UpdatesModel
    private let changelog: any ChangelogLoading
    private let version: String
    private let activation: any AppActivating
    private var window: NSWindow?

    init(
        settings: AppSettings,
        launchAtLogin: LaunchAtLoginModel,
        hotkey: CaptureHotkey,
        updates: UpdatesModel,
        changelog: any ChangelogLoading = BundledChangelog(),
        version: String = SettingsWindowController.bundleVersion,
        activation: any AppActivating = SystemAppActivation()
    ) {
        self.settings = settings
        self.launchAtLogin = launchAtLogin
        self.hotkey = hotkey
        self.updates = updates
        self.changelog = changelog
        self.version = version
        self.activation = activation
    }

    static var bundleVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "(development)"
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        activation.activate()
        window.bringToFront()
    }

    /// A sidebar window: the content runs under a transparent title bar, so the sidebar
    /// reaches the top like System Settings.
    private func makeWindow() -> NSWindow {
        let root = SettingsRootView(
            navigation: navigation,
            settings: settings,
            launchAtLogin: launchAtLogin,
            hotkey: hotkey,
            updates: updates,
            releases: Changelog.releases(fromMarkdown: changelog.loadMarkdown() ?? ""),
            version: version
        )
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.title = Self.title
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        // Like `NSWindow.hosting`: the hosted size is only known after a layout pass, so size up front.
        window.setContentSize(SettingsRootView.size)
        window.center()
        return window
    }
}
