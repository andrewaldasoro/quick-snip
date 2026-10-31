import Foundation

/// The release notes shipped inside the app.
protocol ChangelogLoading {
    func loadMarkdown() -> String?
}

/// `CHANGELOG.md`, copied into the app's resources by `scripts/bundle.sh`. Absent from
/// `swift run` builds, which have no bundle.
struct BundledChangelog: ChangelogLoading {
    func loadMarkdown() -> String? {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md") else { return nil }
        // Unreadable notes only leave the What's New list empty; nothing else depends on them.
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
