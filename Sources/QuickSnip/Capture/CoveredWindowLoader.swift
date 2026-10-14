import CoreGraphics
import OSLog

/// After a click snaps to a window that others cover, captures that window on its own and
/// paints it into the session, so the selection holds the whole window.
@MainActor
final class CoveredWindowLoader {
    private let logger = Logger(subsystem: Log.subsystem, category: "capture")
    private let capturer: any WindowImageCapturing
    /// The capture in flight; outputs wait for it.
    private(set) var task: Task<Void, Never>?

    init(capturer: any WindowImageCapturing) {
        self.capturer = capturer
    }

    func load(_ window: SnapWindow, on displayID: CGDirectDisplayID, into session: CaptureSession) {
        task?.cancel()
        guard let display = session.display(displayID) else { return }
        let pixelSize = display.pixelSize(of: window)
        let capturer = capturer
        task = Task { [weak self, weak session] in
            do {
                let image = try await capturer.captureWindow(window.id, pixelSize: pixelSize)
                guard !Task.isCancelled else { return }
                session?.bringToFront(window, image: image, on: displayID)
            } catch {
                // The selection keeps what the frozen screen showed.
                self?.logger.error("Window capture failed: \(error.localizedDescription, privacy: .public)")
            }
            guard !Task.isCancelled else { return }
            self?.task = nil
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
