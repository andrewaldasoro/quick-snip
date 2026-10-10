import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: OnboardingPresenting {
    private let permission: ScreenRecordingPermission
    private let activation: any AppActivating
    private var window: NSWindow?

    init(permission: ScreenRecordingPermission, activation: any AppActivating = SystemAppActivation()) {
        self.permission = permission
        self.activation = activation
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        activation.activate()
        window.bringToFront()
    }

    func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let view = OnboardingView(permission: permission) { [weak self] in
            self?.close()
        }
        return .hosting(view, title: "Welcome to QuickSnip")
    }
}
