import SwiftUI

/// One setting: a title, an optional explanation under it, and its control on the right.
struct SettingsRow<Control: View>: View {
    static var horizontalPadding: CGFloat { 14 }
    static var verticalPadding: CGFloat { 10 }
    static var minimumHeight: CGFloat { 44 }

    let title: String
    var subtitle: String?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            control
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .frame(minHeight: Self.minimumHeight)
        .accessibilityElement(children: .combine)
    }
}
