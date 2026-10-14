import ScreenCaptureKit

/// Captures one window's own content, even where other windows cover it.
@MainActor
protocol WindowImageCapturing {
    func captureWindow(_ id: CGWindowID, pixelSize: CGSize) async throws -> CGImage
}

struct ScreenCaptureKitWindowCapturer: WindowImageCapturing {
    enum CaptureError: Error {
        case windowClosed
    }

    func captureWindow(_ id: CGWindowID, pixelSize: CGSize) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == id }) else { throw CaptureError.windowClosed }
        let configuration = SCStreamConfiguration()
        configuration.width = Int(pixelSize.width)
        configuration.height = Int(pixelSize.height)
        configuration.showsCursor = false
        configuration.captureResolution = .best
        configuration.ignoreShadowsSingleWindow = true
        return try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration)
    }
}
