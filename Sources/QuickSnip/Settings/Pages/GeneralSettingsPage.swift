import AppKit
import SwiftUI

/// Settings › General: the capture shortcut, where captures go, and how the app behaves.
struct GeneralSettingsPage: View {
    @Bindable var settings: AppSettings
    let launchAtLogin: LaunchAtLoginModel
    let hotkey: CaptureHotkey

    var body: some View {
        SettingsPageLayout(title: SettingsPage.general.title) {
            SettingsSection(title: "Capture") {
                SettingsRow(title: "Capture area", subtitle: "Freezes the screen so you can select, annotate and copy") {
                    ShortcutField(hotkey: hotkey)
                }
            }

            SettingsSection(title: "Output") {
                SettingsRow(title: "Save to", subtitle: Self.displayPath(settings.saveDirectory)) {
                    Button("Choose…", action: chooseFolder)
                }
                .help(settings.saveDirectory.path)
                SettingsRow(title: "Format", subtitle: "PNG keeps every pixel; JPEG makes smaller files") {
                    Picker("Format", selection: $settings.imageFormat) {
                        ForEach(ImageFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                SettingsRow(title: "Show thumbnail", subtitle: "A preview in the corner after each copy or save") {
                    Toggle("Show thumbnail", isOn: $settings.showThumbnail).labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsSection(title: "Application") {
                SettingsRow(
                    title: "Show menu bar icon",
                    subtitle: settings.showMenuBarIcon ? nil : "Open QuickSnip again from Finder or Spotlight to get back to Settings."
                ) {
                    Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon).labelsHidden().toggleStyle(.switch)
                }
                SettingsRow(title: "Launch at login", subtitle: launchAtLogin.errorMessage) {
                    Toggle(
                        "Launch at login",
                        isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) })
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }
        }
    }

    static func displayPath(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.saveDirectory
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveDirectory = url
        }
    }
}
