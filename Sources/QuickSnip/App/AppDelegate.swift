import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permission = ScreenRecordingPermission()
    private lazy var coordinator = CaptureCoordinator(
        permission: permission,
        onboarding: OnboardingWindowController(permission: permission),
        startCapture: {
            // Phase 1: capture all displays and show selection overlay.
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        KeyboardShortcuts.onKeyUp(for: .captureArea) { [weak self] in
            self?.captureRequested()
        }
        coordinator.appDidLaunch()
    }

    func captureRequested() {
        coordinator.captureRequested()
    }
}
