import SwiftUI

/// Keys drawn as small key caps, like the ones in macOS menus and help.
struct KeyCapsView: View {
    static let spacing: CGFloat = 4
    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 1
    static let cornerRadius: CGFloat = 5

    let keys: [String]
    /// Keys pressed together (⇧ ⌘ C) rather than alternatives (Delete or ⌦).
    var isCombination = false

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                    .padding(.horizontal, Self.horizontalPadding)
                    .padding(.vertical, Self.verticalPadding)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keys.joined(separator: isCombination ? " " : " or "))
    }
}
