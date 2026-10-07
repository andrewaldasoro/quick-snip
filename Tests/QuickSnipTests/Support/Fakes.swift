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
    private(set) var presentCount = 0
    private(set) var dismissCount = 0
    private var onCommand: (@MainActor (OverlayCommand) -> Void)?

    var isPresenting: Bool { presentedSession != nil }

    func present(_ session: CaptureSession, onCommand: @escaping @MainActor (OverlayCommand) -> Void) {
        presentCount += 1
        presentedSession = session
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
