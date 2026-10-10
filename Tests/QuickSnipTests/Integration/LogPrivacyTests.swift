import Foundation
import Testing

/// Unified logs are readable by other processes and end up in sysdiagnoses, so file paths
/// (which contain the user name) must stay redacted.
struct LogPrivacyTests {
    private static let sourcesDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Integration
        .deletingLastPathComponent()  // QuickSnipTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // repo root
        .appendingPathComponent("Sources")

    private func logLines() throws -> [String] {
        let files = try #require(FileManager.default.enumerator(at: Self.sourcesDir, includingPropertiesForKeys: nil))
        return try files.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .flatMap { try String(contentsOf: $0, encoding: .utf8).components(separatedBy: .newlines) }
            .filter { $0.contains("logger.") }
    }

    @Test func logsFindTheSources() throws {
        #expect(try !logLines().isEmpty)
    }

    @Test func logsNeverMakeFilePathsPublic() throws {
        let leaks = try logLines().filter { $0.range(of: #"(path|url|URL)[^)]*privacy: \.public"#, options: .regularExpression) != nil }
        #expect(leaks.isEmpty, "Public file paths in logs: \(leaks)")
    }
}
