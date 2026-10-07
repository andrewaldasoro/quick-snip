import Foundation
import Observation

/// Screen Recording (TCC) permission state.
///
/// `CGPreflightScreenCaptureAccess` can stay `false` for the running process after the
/// user grants access; macOS may require a relaunch before it reports `true`.
@MainActor
@Observable
final class ScreenRecordingPermission {
    nonisolated static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )!

    private(set) var isGranted: Bool

    @ObservationIgnored private let access: any ScreenCaptureAccess
    @ObservationIgnored private let urlOpener: any URLOpening

    init(
        access: any ScreenCaptureAccess = SystemScreenCaptureAccess(),
        urlOpener: any URLOpening = WorkspaceURLOpener()
    ) {
        self.access = access
        self.urlOpener = urlOpener
        isGranted = access.preflight()
    }

    func refresh() {
        isGranted = access.preflight()
    }

    /// Shows the system prompt the first time; afterwards it only registers the app in the list.
    func request() {
        isGranted = access.request()
    }

    func openSystemSettings() {
        urlOpener.open(Self.settingsURL)
    }
}
