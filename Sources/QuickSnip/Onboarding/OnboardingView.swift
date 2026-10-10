import AppKit
import Combine
import KeyboardShortcuts
import SwiftUI

struct OnboardingView: View {
    let permission: ScreenRecordingPermission
    let onDone: () -> Void

    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Screen Recording access", systemImage: "rectangle.dashed.badge.record")
                .font(.title2.bold())

            Text(
                "QuickSnip needs Screen Recording permission to capture your screen. Images never leave your Mac unless you choose to share them."
            )
            .fixedSize(horizontal: false, vertical: true)

            if permission.isGranted {
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                HStack {
                    Text("Capture shortcut:")
                    KeyboardShortcuts.Recorder(for: .captureArea)
                }
            } else {
                Text("After enabling QuickSnip in System Settings, macOS may ask you to quit and reopen the app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if permission.isGranted {
                    Spacer()
                    Button("Done", action: onDone)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Open System Settings") {
                        permission.request()
                        permission.openSystemSettings()
                    }
                    .keyboardShortcut(.defaultAction)
                    Spacer()
                    Button("Quit & Reopen", action: relaunch)
                }
            }
        }
        .padding(24)
        .frame(width: 440)
        .onReceive(poll) { _ in
            if !permission.isGranted { permission.refresh() }
        }
    }

    private func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }
}
