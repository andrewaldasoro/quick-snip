/// A newer version Sparkle found in the feed, not yet installed.
struct AvailableUpdate: Equatable, Sendable {
    let version: String
    /// Release notes from the feed, grouped by heading; empty when it had none.
    let notes: [ChangelogRelease.Group]
}
