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
    private let activation: any AppActivating
    private var window: NSWindow?

    init(settings: AppSettings, launchAtLogin: LaunchAtLoginModel, activation: any AppActivating = SystemAppActivation()) {
        self.settings = settings
        self.launchAtLogin = launchAtLogin
        self.activation = activation
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        activation.activate()
        window.bringToFront()
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsView(settings: settings, launchAtLogin: launchAtLogin)
        return .hosting(view, title: "QuickSnip Settings")
    }
}
