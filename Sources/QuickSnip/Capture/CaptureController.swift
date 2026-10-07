import Foundation
import OSLog

enum OverlayCommand: Equatable, Sendable {
    case copy
    case save
    case cancel
}

@MainActor
protocol OverlayPresenting: AnyObject {
    func present(_ session: CaptureSession, onCommand: @escaping @MainActor (OverlayCommand) -> Void)
    func dismiss()
}

/// Runs one capture: freeze displays → overlay → copy / save / cancel.
@MainActor
final class CaptureController {
    enum Outcome: Equatable {
        case copied
        case saved(URL)
        case cancelled
        case noSelection
        case failed
    }

    private let logger = Logger(subsystem: Log.subsystem, category: "capture")
    private let capturer: any DisplayCapturing
    private let presenter: any OverlayPresenting
    private let pasteboard: any ImagePasteboard
    private let saver: ScreenshotSaver

    private(set) var session: CaptureSession?
    private var isCapturing = false

    init(
        capturer: any DisplayCapturing,
        presenter: any OverlayPresenting,
        pasteboard: any ImagePasteboard,
        saver: ScreenshotSaver
    ) {
        self.capturer = capturer
        self.presenter = presenter
        self.pasteboard = pasteboard
        self.saver = saver
    }

    var isActive: Bool { session != nil || isCapturing }

    func start() async {
        guard !isActive else { return }
        isCapturing = true
        defer { isCapturing = false }

        do {
            let displays = try await capturer.captureAllDisplays()
            guard !displays.isEmpty else {
                logger.error("Capture returned no displays")
                return
            }
            let session = CaptureSession(displays: displays)
            self.session = session
            presenter.present(session) { [weak self] command in
                self?.handle(command)
            }
        } catch {
            logger.error("Capture failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    @discardableResult
    func handle(_ command: OverlayCommand) -> Outcome {
        switch command {
        case .cancel:
            finish()
            return .cancelled

        case .copy:
            guard let png = encodedSelection() else { return .noSelection }
            pasteboard.writePNG(png)
            finish()
            return .copied

        case .save:
            guard let png = encodedSelection() else { return .noSelection }
            do {
                let url = try saver.save(png)
                logger.info("Saved \(url.path, privacy: .public)")
                finish()
                return .saved(url)
            } catch {
                logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
                return .failed
            }
        }
    }

    private func encodedSelection() -> Data? {
        session?.croppedImage().flatMap(PNGEncoder.encode)
    }

    private func finish() {
        presenter.dismiss()
        session = nil
    }
}
