import SwiftUI

/// Release notes inside a Settings card: each heading ("Added") over its bulleted items.
struct ReleaseNotesList: View {
    static var bulletSpacing: CGFloat { 6 }
    static var itemSpacing: CGFloat { 6 }

    let groups: [ChangelogRelease.Group]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: Self.itemSpacing) {
                    if !group.title.isEmpty {
                        Text(group.title.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: Self.bulletSpacing) {
                            Text("•").foregroundStyle(.secondary)
                            Text(Self.formatted(item))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SettingsRow<EmptyView>.horizontalPadding)
        .padding(.vertical, SettingsRow<EmptyView>.verticalPadding + 2)
    }

    /// The changelog uses inline Markdown (**bold**, `code`).
    static func formatted(_ item: String) -> AttributedString {
        // Text that isn't valid Markdown is still worth showing as typed.
        (try? AttributedString(markdown: item)) ?? AttributedString(item)
    }
}
