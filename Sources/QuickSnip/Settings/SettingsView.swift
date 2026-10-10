import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let launchAtLogin: LaunchAtLoginModel

    var body: some View {
        Form {
            Section("Capture") {
                KeyboardShortcuts.Recorder("Capture area:", name: .captureArea)
            }

            Section("Output") {
                LabeledContent("Save to:") {
                    HStack {
                        Text(SettingsView.displayPath(settings.saveDirectory))
                            .truncationMode(.middle)
                            .lineLimit(1)
                            .help(settings.saveDirectory.path)
                        Button("Choose…", action: chooseFolder)
                    }
                }

                Picker("Format:", selection: $settings.imageFormat) {
                    ForEach(ImageFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }

                Toggle("Show thumbnail after capture", isOn: $settings.showThumbnail)
            }

            Section("General") {
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                if !settings.showMenuBarIcon {
                    Text("Open QuickSnip again from Finder or Spotlight to get back to Settings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    ))
                if let error = launchAtLogin.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
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
