import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: OnboardingPresenting {
    private let permission: ScreenRecordingPermission
    private var window: NSWindow?

    init(permission: ScreenRecordingPermission) {
        self.permission = permission
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let view = OnboardingView(permission: permission) { [weak self] in
            self?.close()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Welcome to QuickSnip"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
