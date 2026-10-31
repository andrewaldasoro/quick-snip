import Sparkle

/// Checks for and installs app updates.
@MainActor
protocol UpdateChecking: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    /// Called after each check: the newer version and its HTML notes, or nil when up to date.
    var onCheckFinished: (@MainActor (_ update: (version: String, notesHTML: String?)?) -> Void)? { get set }
    func checkForUpdates()
}

/// Sparkle, reading `SUFeedURL` and `SUPublicEDKey` from Info.plist. Without
/// `SUEnableAutomaticChecks`, Sparkle asks on the second launch before checking on its own.
@MainActor
final class SparkleUpdater: UpdateChecking {
    private let observer = SparkleCheckObserver()
    private lazy var controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: observer, userDriverDelegate: nil)

    var onCheckFinished: (@MainActor (_ update: (version: String, notesHTML: String?)?) -> Void)? {
        get { observer.onCheckFinished }
        set { observer.onCheckFinished = newValue }
    }

    init() {
        _ = controller  // Starts the updater and its scheduled checks.
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

/// Forwards Sparkle's check results. Sparkle calls its delegate on the main thread.
private final class SparkleCheckObserver: NSObject, SPUUpdaterDelegate {
    @MainActor var onCheckFinished: (@MainActor (_ update: (version: String, notesHTML: String?)?) -> Void)?

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let update = (version: item.displayVersionString, notesHTML: item.itemDescription)
        MainActor.assumeIsolated { onCheckFinished?(update) }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        MainActor.assumeIsolated { onCheckFinished?(nil) }
    }
}
