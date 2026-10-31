import AppKit
import SwiftUI

/// Settings › About & Updates: the app and its version, and how it updates.
struct AboutPage: View {
    static var iconSize: CGFloat { 64 }

    @Bindable var updates: UpdatesModel
    let version: String

    var body: some View {
        SettingsPageLayout(title: SettingsPage.about.title) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: Self.iconSize, height: Self.iconSize)
                VStack(alignment: .leading, spacing: 2) {
                    Text("QuickSnip").font(.title3.weight(.semibold))
                    Text("Version \(version)").foregroundStyle(.secondary)
                    Text("Screenshots stay on your Mac.").font(.caption).foregroundStyle(.secondary)
                }
            }

            SettingsSection(title: "Updates") {
                SettingsRow(title: "Check for updates automatically", subtitle: "Once a day, from QuickSnip's signed release feed") {
                    Toggle("Check for updates automatically", isOn: $updates.checksAutomatically)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                SettingsRow(title: updateTitle, subtitle: updateSubtitle) {
                    if updates.availableUpdate != nil {
                        Button("Update…", action: updates.checkNow).buttonStyle(.borderedProminent)
                    } else {
                        Button("Check Now", action: updates.checkNow)
                    }
                }
            }

            SettingsSection(title: "Acknowledgements") {
                SettingsRow(title: "Open-source notices", subtitle: "Licenses of the libraries QuickSnip uses") {
                    Button("Show…") { NSApp.orderFrontStandardAboutPanel(nil) }
                }
            }
        }
    }

    private var updateTitle: String {
        updates.availableUpdate.map { "Version \($0.version) is available" } ?? "QuickSnip is up to date"
    }

    private var updateSubtitle: String? {
        updates.availableUpdate == nil ? "As of the last check" : "See What's New for the changes"
    }
}
