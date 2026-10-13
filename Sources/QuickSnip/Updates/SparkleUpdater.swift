import Sparkle

/// Checks for and installs app updates.
@MainActor
protocol UpdateChecking: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    func checkForUpdates()
}

/// Sparkle, reading `SUFeedURL` and `SUPublicEDKey` from Info.plist. Without
/// `SUEnableAutomaticChecks`, Sparkle asks on the second launch before checking on its own.
@MainActor
final class SparkleUpdater: UpdateChecking {
    private let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
