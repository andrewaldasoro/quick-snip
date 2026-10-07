import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Capture area:", name: .captureArea)
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .onAppear {
            // Menu bar (LSUIElement) apps don't come to the front on their own.
            NSApp.activate()
        }
    }
}
