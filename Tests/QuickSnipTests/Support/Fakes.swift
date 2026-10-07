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
