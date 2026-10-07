import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Lets the menu bar menu finish closing so it isn't in the capture.
    private static let menuDismissDelay: Duration = .milliseconds(200)

    private let permission = ScreenRecordingPermission()
    private lazy var captureController = CaptureController(
        capturer: ScreenCaptureKitCapturer(),
        presenter: OverlayWindowManager(),
        pasteboard: SystemImagePasteboard(),
        saver: ScreenshotSaver(directory: ScreenshotSaver.defaultDirectory)
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
        coordinator.appDidLaunch()
    }

    /// From the menu bar "Capture Area" item.
    func captureRequested() {
        Task {
            try? await Task.sleep(for: Self.menuDismissDelay)
            await coordinator.captureRequested()
        }
    }
}
