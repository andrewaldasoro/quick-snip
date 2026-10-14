import AppKit
import ScreenCaptureKit

@MainActor
protocol DisplayCapturing {
    func captureAllDisplays() async throws -> [CapturedDisplay]
}

/// An `NSScreen` reduced to what capture needs.
struct ScreenInfo: Equatable {
    let displayID: CGDirectDisplayID
    /// AppKit global frame (points).
    let frame: CGRect
    let scale: CGFloat

    var pixelSize: CGSize {
        CGSize(width: (frame.width * scale).rounded(), height: (frame.height * scale).rounded())
    }

    @MainActor
    static func current() -> [ScreenInfo] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return ScreenInfo(displayID: number.uint32Value, frame: screen.frame, scale: screen.backingScaleFactor)
        }
    }
}

struct ScreenCaptureKitCapturer: DisplayCapturing {
    enum CaptureError: Error {
        case noDisplays
    }

    func captureAllDisplays() async throws -> [CapturedDisplay] {
        let screens = ScreenInfo.current()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        // Keep QuickSnip's own windows (thumbnail, settings, onboarding) out of the capture.
        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        let ownApps = content.applications.filter { $0.processID == ownProcessID }
        let windows = Self.onScreenWindows()
        let primaryScreenHeight = WindowSnap.primaryScreenHeight(of: screens.map(\.frame))

        var captured: [CapturedDisplay] = []
        for screen in screens {
            guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else { continue }

            let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = Int(screen.pixelSize.width)
            configuration.height = Int(screen.pixelSize.height)
            configuration.showsCursor = false
            configuration.captureResolution = .best

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            let snapFrames = WindowSnap.localFrames(
                of: windows, on: screen.frame, primaryScreenHeight: primaryScreenHeight, excluding: ownProcessID)
            captured.append(CapturedDisplay(displayID: screen.displayID, frame: screen.frame, image: image, windows: snapFrames))
        }

        guard !captured.isEmpty else { throw CaptureError.noDisplays }
        return captured
    }

    /// Front to back. `SCShareableContent` doesn't promise an order; the window list does.
    private static func onScreenWindows() -> [WindowInfo] {
        let entries = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        return (entries ?? []).compactMap(WindowInfo.init)
    }
}
