import Observation

/// Which Settings page is showing, so the update card can jump to What's New.
@MainActor
@Observable
final class SettingsNavigation {
    var page: SettingsPage = .general
}
