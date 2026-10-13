import SwiftUI

/// The full shortcut list, grouped by section, with each key drawn as a key cap.
struct CheatsheetView: View {
    static let size = CGSize(width: 460, height: 560)

    let hotkey: CaptureHotkey

    var body: some View {
        Form {
            ForEach(hotkey.cheatsheet.sections) { section in
                Section {
                    ForEach(section.entries, id: \.self) { entry in
                        LabeledContent(entry.action) {
                            KeyCapsView(keys: entry.keys)
                        }
                    }
                } header: {
                    Text(section.title)
                } footer: {
                    if let note = section.note {
                        Text(note)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
