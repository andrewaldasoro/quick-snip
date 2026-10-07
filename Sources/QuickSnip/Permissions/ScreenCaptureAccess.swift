import AppKit
import CoreGraphics

/// System seam for Screen Recording (TCC) checks, so permission logic can be tested.
protocol ScreenCaptureAccess {
    func preflight() -> Bool
    func request() -> Bool
}

struct SystemScreenCaptureAccess: ScreenCaptureAccess {
    func preflight() -> Bool { CGPreflightScreenCaptureAccess() }
    func request() -> Bool { CGRequestScreenCaptureAccess() }
}

/// System seam for opening URLs (System Settings deep links).
protocol URLOpening {
    @MainActor func open(_ url: URL)
}

struct WorkspaceURLOpener: URLOpening {
    @MainActor func open(_ url: URL) { NSWorkspace.shared.open(url) }
}
