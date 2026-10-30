import SwiftUI

/// The full shortcut list, grouped by section, with each key drawn as a key cap.
struct CheatsheetView: View {
    static let size = CGSize(width: 460, height: 560)

    let hotkey: CaptureHotkey

    var body: some View {
        SettingsPageLayout(title: SettingsPage.shortcuts.title) {
            CheatsheetSections(hotkey: hotkey)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
