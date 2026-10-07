import SwiftUI

@main
struct QuickSnipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("QuickSnip", systemImage: "camera.viewfinder") {
            MenuContent(appDelegate: appDelegate)
        }

        Settings {
            SettingsView()
        }
    }
}

private struct MenuContent: View {
    let appDelegate: AppDelegate

    var body: some View {
        Button("Capture Area") {
            appDelegate.captureRequested()
        }

        Divider()

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",")

        Button("Quit QuickSnip") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
