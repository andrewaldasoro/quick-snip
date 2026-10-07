import Foundation
import Testing

/// Guards the app bundle settings that `scripts/bundle.sh` ships.
struct BundleConfigurationTests {
    private static let supportDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Integration
        .deletingLastPathComponent()   // QuickSnipTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repo root
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

    @Test func bundleScriptSubstitutesPlaceholders() throws {
        let plist = try infoPlist()
        #expect(plist["CFBundleIdentifier"] as? String == "$(BUNDLE_ID)")
        #expect(plist["CFBundleShortVersionString"] as? String == "$(VERSION)")
        #expect(plist["CFBundleVersion"] as? String == "$(BUILD)")
    }
}
