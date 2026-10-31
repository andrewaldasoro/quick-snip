import Observation

/// Update preferences, the manual check, and the update Sparkle found, for Settings and the menu.
@MainActor
@Observable
final class UpdatesModel {
    @ObservationIgnored private let updater: any UpdateChecking
    @ObservationIgnored private let activation: any AppActivating

    var checksAutomatically: Bool {
        didSet { updater.automaticallyChecksForUpdates = checksAutomatically }
    }

    /// The newer version from the last check, if any.
    private(set) var availableUpdate: AvailableUpdate?
    /// The version whose sidebar card the user closed; a newer one shows the card again.
    private var dismissedVersion: String?

    init(updater: any UpdateChecking, activation: any AppActivating = SystemAppActivation()) {
        self.updater = updater
        self.activation = activation
        checksAutomatically = updater.automaticallyChecksForUpdates
        updater.onCheckFinished = { [weak self] update in
            self?.availableUpdate = update.map {
                AvailableUpdate(version: $0.version, notes: $0.notesHTML.map(ReleaseNotes.groups(fromHTML:)) ?? [])
            }
        }
    }

    var showsUpdateCard: Bool {
        guard let availableUpdate else { return false }
        return availableUpdate.version != dismissedVersion
    }

    func dismissUpdateCard() {
        dismissedVersion = availableUpdate?.version
    }

    /// Sparkle's window would open behind the frontmost app: QuickSnip has no Dock icon.
    /// It also installs a found update, so "Update" in Settings is the same check.
    func checkNow() {
        activation.activate()
        updater.checkForUpdates()
    }
}
