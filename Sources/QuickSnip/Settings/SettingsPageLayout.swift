import SwiftUI

/// A Settings page: its title, then its sections, scrolling when they don't fit.
struct SettingsPageLayout<Content: View>: View {
    static var padding: CGFloat { 24 }
    static var sectionSpacing: CGFloat { 22 }

    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                Text(title)
                    .font(.title2.weight(.semibold))
                content
            }
            .padding(Self.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
