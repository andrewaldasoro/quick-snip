import Foundation
import Testing

/// Guards the app bundle settings that `scripts/bundle.sh` ships.
struct BundleConfigurationTests {
    private static let supportDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Integration
        .deletingLastPathComponent()  // QuickSnipTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // repo root
        .appendingPathComponent("Support")

    private func infoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: Self.supportDir.appendingPathComponent("Info.plist"))
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @Test func isMenuBarOnlyApp() throws {
        #expect(try infoPlist()["LSUIElement"] as? Bool == true)
    }

    @Test func targetsMacOS15AppleSilicon() throws {
        let plist = try infoPlist()
        #expect(plist["LSMinimumSystemVersion"] as? String == "15.0")
        #expect(plist["LSArchitecturePriority"] as? [String] == ["arm64"])
    }

    @Test func executableMatchesProduct() throws {
        #expect(try infoPlist()["CFBundleExecutable"] as? String == "QuickSnip")
    }

    @Test func declaresAppIconThatExists() throws {
        #expect(try infoPlist()["CFBundleIconFile"] as? String == "AppIcon")
        #expect(FileManager.default.fileExists(atPath: Self.supportDir.appendingPathComponent("AppIcon.icns").path))
    }

    @Test func bundleScriptSubstitutesPlaceholders() throws {
        let plist = try infoPlist()
        #expect(plist["CFBundleIdentifier"] as? String == "$(BUNDLE_ID)")
        #expect(plist["CFBundleShortVersionString"] as? String == "$(VERSION)")
        #expect(plist["CFBundleVersion"] as? String == "$(BUILD)")
    }

    /// Changing the ID later resets the Screen Recording grant and preferences, so the scripts must agree on the final one.
    @Test(arguments: ["bundle.sh", "test-bundle.sh"])
    func scriptsDefaultToTheFinalBundleID(script: String) throws {
        let url = Self.supportDir.deletingLastPathComponent().appendingPathComponent("scripts").appendingPathComponent(script)
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains(#"BUNDLE_ID="${BUNDLE_ID:-io.github.andrewaldasoro.quicksnip}""#))
    }
}
