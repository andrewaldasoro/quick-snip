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
final class SpyCheatsheetWindow: CheatsheetPresenting {
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
final class SpyPasteboard: ClipboardWriting {
    private(set) var written: [Data] = []
    func writePNG(_ data: Data) { written.append(data) }
    private(set) var writtenText: [String] = []
    func writeText(_ text: String) { writtenText.append(text) }
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

/// Stands in for the recorded capture shortcut, so tests can change it.
@MainActor
final class FakeHotkeySource {
    var text: String?
    init(_ text: String?) { self.text = text }

    func makeHotkey() -> CaptureHotkey {
        CaptureHotkey(read: { [unowned self] in text })
    }
}

@MainActor
final class FakeUpdater: UpdateChecking {
    var automaticallyChecksForUpdates: Bool
    private(set) var checkCount = 0

    init(automaticallyChecksForUpdates: Bool = false) {
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }

    func checkForUpdates() { checkCount += 1 }
}

/// Text recognition that waits until the test releases it, so tests control when it finishes.
actor GatedTextRecognizer: TextRecognizing {
    private var result: Result<String, TestError>?
    private var waiting: CheckedContinuation<Result<String, TestError>, Never>?
    private(set) var imageSizes: [CGSize] = []

    func recognizeText(in image: CGImage) async throws -> String {
        imageSizes.append(CGSize(width: image.width, height: image.height))
        let result = await withCheckedContinuation { continuation in
            if let result = self.result { continuation.resume(returning: result) } else { waiting = continuation }
        }
        return try result.get()
    }

    /// Finishes the current (or next) recognition with `result`.
    func finish(with result: Result<String, TestError>) {
        if let waiting {
            self.waiting = nil
            waiting.resume(returning: result)
        } else {
            self.result = result
        }
    }
}

@MainActor
final class SpyRecognizedText: RecognizedTextPresenting {
    private(set) var shown: [String] = []
    func show(_ text: String) { shown.append(text) }
}

/// Window captures that finish when the test says so; records what was asked for.
@MainActor
final class GatedWindowCapturer: WindowImageCapturing {
    private var result: Result<CGImage, TestError>?
    private var waiting: CheckedContinuation<Result<CGImage, TestError>, Never>?
    private(set) var requests: [(id: CGWindowID, pixelSize: CGSize)] = []

    func captureWindow(_ id: CGWindowID, pixelSize: CGSize) async throws -> CGImage {
        requests.append((id, pixelSize))
        let result = await withCheckedContinuation { continuation in
            if let result = self.result { continuation.resume(returning: result) } else { waiting = continuation }
        }
        return try result.get()
    }

    /// Finishes the current (or next) capture with `result`.
    func finish(with result: Result<CGImage, TestError>) {
        if let waiting {
            self.waiting = nil
            waiting.resume(returning: result)
        } else {
            self.result = result
        }
    }
}

struct FakeFontFamilies: FontFamilyProviding {
    var availableFamilies: [String]
}
