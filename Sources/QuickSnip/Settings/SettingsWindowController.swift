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
    private let settings: AppSettings
    private let launchAtLogin: LaunchAtLoginModel
    private let hotkey: CaptureHotkey
    private let updates: UpdatesModel
    private let activation: any AppActivating
    private var window: NSWindow?

    init(
        settings: AppSettings,
        launchAtLogin: LaunchAtLoginModel,
        hotkey: CaptureHotkey,
        updates: UpdatesModel,
        activation: any AppActivating = SystemAppActivation()
    ) {
        self.settings = settings
        self.launchAtLogin = launchAtLogin
        self.hotkey = hotkey
        self.updates = updates
        self.activation = activation
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        activation.activate()
        window.bringToFront()
    }

    /// Native toolbar tabs (icon + label in the title bar); the window takes each tab's
    /// title and resizes to fit it.
    private func makeWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(
            Self.tab(
                SettingsView(settings: settings, launchAtLogin: launchAtLogin, hotkey: hotkey, updates: updates), label: "General",
                symbol: "gearshape"))
        tabs.addTabViewItem(Self.tab(CheatsheetView(hotkey: hotkey), label: "Shortcuts", symbol: "keyboard"))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        // Like `NSWindow.hosting`: the hosted size is only known after a layout pass, so size up front.
        if let first = tabs.tabViewItems.first?.viewController {
            window.setContentSize(first.preferredContentSize)
        }
        window.center()
        return window
    }

    private static func tab(_ view: some View, label: String, symbol: String) -> NSTabViewItem {
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = .preferredContentSize
        hosting.preferredContentSize = hosting.view.fittingSize
        hosting.title = label
        let item = NSTabViewItem(viewController: hosting)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
}
