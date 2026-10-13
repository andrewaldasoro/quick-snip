import SwiftUI

/// The recognized text, editable and selectable. Copy All, or select part and press ⌘C.
struct RecognizedTextView: View {
    static let size = CGSize(width: 480, height: 320)

    @Bindable var model: RecognizedTextModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $model.text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                .accessibilityLabel("Recognized text")

            HStack {
                if model.isCopied {
                    Label("Copied to the clipboard", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Select text and press ⌘C, or copy it all.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Copy All", action: model.copyAll)
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            .font(.callout)
        }
        .padding(16)
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
