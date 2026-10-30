import SwiftUI

/// The sidebar's note about a new version: what it is, a way to read the changes, and Update.
struct UpdateCard: View {
    static var cornerRadius: CGFloat { 10 }
    static var padding: CGFloat { 10 }

    let update: AvailableUpdate
    let onShowNotes: @MainActor () -> Void
    let onUpdate: @MainActor () -> Void
    let onDismiss: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label("Update available", systemImage: "arrow.down.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("Hide until the next version")
                .accessibilityLabel("Hide update")
            }
            Text("Version \(update.version)").font(.headline)
            Button("See what's new", action: onShowNotes)
                .buttonStyle(.link)
                .font(.caption)
            Button(action: onUpdate) {
                Text("Update").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(Self.padding)
        .background(.fill.quinary, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Self.cornerRadius).strokeBorder(.separator))
    }
}
