import SwiftUI

/// Settings: page list in a sidebar (with the update card under it) and the page on the right.
struct SettingsRootView: View {
    static let size = CGSize(width: 720, height: 540)
    static let sidebarWidth: CGFloat = 200

    @Bindable var navigation: SettingsNavigation
    let settings: AppSettings
    let launchAtLogin: LaunchAtLoginModel
    let hotkey: CaptureHotkey
    let updates: UpdatesModel
    let releases: [ChangelogRelease]
    let version: String

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $navigation.page) { page in
                Label(page.title, systemImage: page.symbol)
                    .tag(page)
            }
            .safeAreaInset(edge: .bottom) { sidebarFooter }
            .navigationSplitViewColumnWidth(Self.sidebarWidth)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            page
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    @ViewBuilder private var page: some View {
        switch navigation.page {
        case .general: GeneralSettingsPage(settings: settings, launchAtLogin: launchAtLogin, hotkey: hotkey)
        case .shortcuts:
            SettingsPageLayout(title: SettingsPage.shortcuts.title) { CheatsheetSections(hotkey: hotkey) }
        case .whatsNew: WhatsNewPage(updates: updates, releases: releases, installedVersion: version)
        case .about: AboutPage(updates: updates, version: version)
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: 8) {
            if updates.showsUpdateCard, let update = updates.availableUpdate {
                UpdateCard(
                    update: update,
                    onShowNotes: { navigation.page = .whatsNew },
                    onUpdate: updates.checkNow,
                    onDismiss: updates.dismissUpdateCard
                )
            }
            Text("QuickSnip \(version)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
    }
}
