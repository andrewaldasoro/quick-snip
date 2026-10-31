import SwiftUI

/// A titled group of rows on a rounded card, with hairlines between rows.
struct SettingsSection<Content: View>: View {
    static var cornerRadius: CGFloat { 10 }
    static var titleSpacing: CGFloat { 8 }

    let title: String
    /// Secondary text at the end of the title line (a release date).
    var detail: String?
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Self.titleSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            Divider().padding(.leading, SettingsRow<EmptyView>.horizontalPadding)
                        }
                        row
                    }
                }
            }
            .background(.fill.quinary, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Self.cornerRadius).strokeBorder(.separator))
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
