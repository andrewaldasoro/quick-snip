import AppKit
import CoreGraphics
import Foundation

@testable import QuickSnip

final class FakeScreenCaptureAccess: ScreenCaptureAccess {
    var granted: Bool
    var grantOnRequest: Bool
    private(set) var preflightCount = 0
    private(set) var requestCount = 0

    init(granted: Bool, grantOnRequest: Bool = false) {
        self.granted = granted
        self.grantOnRequest = grantOnRequest
    }

    func preflight() -> Bool {
        preflightCount += 1
        return granted
    }

    func request() -> Bool {
        requestCount += 1
        if grantOnRequest { granted = true }
        return granted
    }
}

@MainActor
final class SpyURLOpener: URLOpening {
    private(set) var opened: [URL] = []
    func open(_ url: URL) { opened.append(url) }
}

@MainActor
final class SpyOnboarding: OnboardingPresenting {
    private(set) var showCount = 0
    func show() { showCount += 1 }
}

@MainActor
final class SpyAppActivation: AppActivating {
    private(set) var activateCount = 0
    func activate() { activateCount += 1 }
}

@MainActor
final class SpySettingsWindow: SettingsPresenting {
    private(set) var showCount = 0
    func show() { showCount += 1 }
}

@MainActor
final class FakeDisplayCapturing: DisplayCapturing {
    var result: Result<[CapturedDisplay], any Error>
    private(set) var callCount = 0

    init(displays: [CapturedDisplay]) {
        result = .success(displays)
    }

    init(error: any Error) {
        result = .failure(error)
    }

    func captureAllDisplays() async throws -> [CapturedDisplay] {
        callCount += 1
        return try result.get()
    }
}

@MainActor
final class SpyOverlayPresenter: OverlayPresenting {
    private(set) var presentedSession: CaptureSession?
    /// Most recently presented session, kept after dismissal for inspection.
    private(set) var lastSession: CaptureSession?
    private(set) var presentCount = 0
    private(set) var dismissCount = 0
    private var onCommand: (@MainActor (OverlayCommand) -> Void)?

    var isPresenting: Bool { presentedSession != nil }

    func present(_ session: CaptureSession, onCommand: @escaping @MainActor (OverlayCommand) -> Void) {
        presentCount += 1
        presentedSession = session
        lastSession = session
        self.onCommand = onCommand
    }

    func dismiss() {
        dismissCount += 1
        presentedSession = nil
        onCommand = nil
    }

    /// Simulates a key command from the overlay.
    func send(_ command: OverlayCommand) {
        onCommand?(command)
    }
}

@MainActor
final class SpyPasteboard: ImagePasteboard {
    private(set) var written: [Data] = []
    func writePNG(_ data: Data) { written.append(data) }
}

struct TestError: Error {}

@MainActor
final class SpyThumbnails: ThumbnailPresenting {
    struct Shown {
        let size: CGSize
        let pointSize: CGSize
        let fileURL: URL?
    }

    private(set) var shown: [Shown] = []
    private(set) var dismissCount = 0

    func show(_ image: CGImage, pointSize: CGSize, fileURL: URL?) {
        shown.append(Shown(size: CGSize(width: image.width, height: image.height), pointSize: pointSize, fileURL: fileURL))
    }

    func dismiss() { dismissCount += 1 }
}

@MainActor
final class FakeLoginItemService: LoginItemService {
    var isEnabled = false
    var error: (any Error)?
    private(set) var requests: [Bool] = []

    func setEnabled(_ enabled: Bool) throws {
        requests.append(enabled)
        if let error { throw error }
        isEnabled = enabled
    }
}

/// Isolated `UserDefaults` per test, removed on deinit.
final class TestDefaults {
    let suiteName = "QuickSnipTests-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

/// Records requested sleeps and returns immediately, so timer-driven code runs without real time.
actor SleepRecorder {
    private(set) var durations: [Duration] = []

    func record(_ duration: Duration) {
        durations.append(duration)
    }
}
