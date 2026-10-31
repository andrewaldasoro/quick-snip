import SwiftUI

/// Settings › What's New: the update waiting to be installed, then the notes of every
/// release up to this one.
struct WhatsNewPage: View {
    let updates: UpdatesModel
    let releases: [ChangelogRelease]
    let installedVersion: String

    var body: some View {
        SettingsPageLayout(title: SettingsPage.whatsNew.title) {
            if let update = updates.availableUpdate {
                SettingsSection(title: "Version \(update.version) is available") {
                    if !update.notes.isEmpty {
                        ReleaseNotesList(groups: update.notes)
                    }
                    SettingsRow(title: "Update QuickSnip", subtitle: "Downloads, installs and relaunches") {
                        Button("Update…", action: updates.checkNow)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            if releases.isEmpty {
                Text("Release notes come with the installed app.")
                    .foregroundStyle(.secondary)
            }
            ForEach(releases) { release in
                SettingsSection(title: title(for: release), detail: release.date) {
                    ReleaseNotesList(groups: release.groups)
                }
            }
        }
    }

    private func title(for release: ChangelogRelease) -> String {
        release.version == installedVersion ? "Version \(release.version) (installed)" : "Version \(release.version)"
    }
}
