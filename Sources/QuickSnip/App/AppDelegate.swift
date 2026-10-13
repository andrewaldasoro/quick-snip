import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Lets the menu bar menu finish closing so it isn't in the capture.
    private static let menuDismissDelay: Duration = .milliseconds(200)

    let settings = AppSettings()
    let launchAtLogin = LaunchAtLoginModel()
    let hotkey = CaptureHotkey()
    private let permission = ScreenRecordingPermission()
    lazy var settingsWindow: any SettingsPresenting = SettingsWindowController(
        settings: settings,
        launchAtLogin: launchAtLogin,
        hotkey: hotkey
    )
    lazy var cheatsheetWindow: any CheatsheetPresenting = CheatsheetWindowController(hotkey: hotkey)
    private lazy var captureController = CaptureController(
        capturer: ScreenCaptureKitCapturer(),
        presenter: OverlayWindowManager(),
        pasteboard: SystemImagePasteboard(),
        saver: ScreenshotSaver(directory: settings.saveDirectory),
        settings: settings,
        thumbnails: ThumbnailPanelController()
    )
    private lazy var coordinator = CaptureCoordinator(
        permission: permission,
        onboarding: OnboardingWindowController(permission: permission),
        startCapture: { [unowned self] in await captureController.start() }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        KeyboardShortcuts.onKeyUp(for: .captureArea) { [weak self] in
            guard let self else { return }
            Task { await self.coordinator.captureRequested() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.captureController.screenConfigurationChanged() }
        }
        coordinator.appDidLaunch()
    }

    /// Opening the app again (Finder, Spotlight, `open`) shows Settings. It's the only
    /// way back when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func showSettings() {
        settingsWindow.show()
    }

    func showCheatsheet() {
        cheatsheetWindow.show()
    }

    /// From the menu bar "Capture Area" item.
    func captureRequested() {
        Task {
            // Throws only on cancellation; capturing anyway is fine.
            try? await Task.sleep(for: Self.menuDismissDelay)
            await coordinator.captureRequested()
        }
    }
}
