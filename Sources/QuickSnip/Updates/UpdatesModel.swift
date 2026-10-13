import Observation

/// Update preferences and the manual check, for Settings and the menu.
@MainActor
@Observable
final class UpdatesModel {
    @ObservationIgnored private let updater: any UpdateChecking
    @ObservationIgnored private let activation: any AppActivating

    var checksAutomatically: Bool {
        didSet { updater.automaticallyChecksForUpdates = checksAutomatically }
    }

    init(updater: any UpdateChecking, activation: any AppActivating = SystemAppActivation()) {
        self.updater = updater
        self.activation = activation
        checksAutomatically = updater.automaticallyChecksForUpdates
    }

    /// Sparkle's window would open behind the frontmost app: QuickSnip has no Dock icon.
    func checkNow() {
        activation.activate()
        updater.checkForUpdates()
    }
}
