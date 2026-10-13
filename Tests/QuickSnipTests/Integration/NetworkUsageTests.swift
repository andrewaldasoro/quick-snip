import Foundation
import Testing

/// QuickSnip is local only: captures never leave the Mac. The update check (Sparkle, in
/// `Updates/`) is the one network request, so networking anywhere else fails this test.
struct NetworkUsageTests {
    private static let sourcesDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Integration
        .deletingLastPathComponent()  // QuickSnipTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // repo root
        .appendingPathComponent("Sources")

    private static let networkAPIs =
        #"URLSession|URLRequest|NWConnection|NWPathMonitor|import Network|CFNetwork|NSURLConnection|WKWebView|import WebKit|https?://"#

    private func sourceFiles() throws -> [URL] {
        let files = try #require(FileManager.default.enumerator(at: Self.sourcesDir, includingPropertiesForKeys: nil))
        return files.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    @Test func scansTheSources() throws {
        #expect(try sourceFiles().count > 10)
    }

    @Test func onlyTheUpdaterTouchesTheNetwork() throws {
        let offenders = try sourceFiles()
            .filter { !$0.path.contains("/Updates/") }
            .filter { try String(contentsOf: $0, encoding: .utf8).range(of: Self.networkAPIs, options: .regularExpression) != nil }
            .map(\.lastPathComponent)
        #expect(offenders.isEmpty, "Network APIs outside Updates/: \(offenders)")
    }
}
