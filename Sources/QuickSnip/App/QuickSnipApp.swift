import SwiftUI

@main
struct QuickSnipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(
            "QuickSnip", systemImage: "camera.viewfinder",
            isInserted: Binding(
                get: { appDelegate.settings.showMenuBarIcon },
                set: { appDelegate.settings.showMenuBarIcon = $0 }
            )
        ) {
            MenuContent(appDelegate: appDelegate)
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

        Button("Settings…") {
            appDelegate.showSettings()
        }
        .keyboardShortcut(",")

        Button("Keyboard Shortcuts…") {
            appDelegate.showCheatsheet()
        }

        Button("Quit QuickSnip") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
