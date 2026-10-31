import SwiftUI

/// The cheatsheet's sections as Settings cards, shared by its window and the Shortcuts page.
struct CheatsheetSections: View {
    let hotkey: CaptureHotkey

    var body: some View {
        ForEach(hotkey.cheatsheet.sections) { section in
            SettingsSection(title: section.title, footer: section.note) {
                ForEach(section.entries, id: \.self) { entry in
                    SettingsRow(title: entry.action) {
                        Self.keyCaps(for: entry.keys)
                    }
                }
            }
        }
    }

    /// One cap per key of each combination ("⇧ ⌘ C"), with "or" between alternatives.
    @ViewBuilder
    private static func keyCaps(for keys: [String]) -> some View {
        HStack(spacing: KeyCapsView.spacing * 2) {
            ForEach(Array(keys.enumerated()), id: \.offset) { index, combination in
                if index > 0 {
                    Text("or").font(.caption).foregroundStyle(.secondary)
                }
                KeyCapsView(keys: ShortcutKeys.caps(for: combination), isCombination: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keys.joined(separator: " or "))
    }
}
