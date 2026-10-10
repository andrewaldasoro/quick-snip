import CoreGraphics
import Foundation
import OSLog

enum OverlayCommand: Hashable, Sendable {
    case copy
    case save
    case cancel
    case undo
    case redo
    case deleteAnnotation
    case selectTool(AnnotationTool)
    case selectColor(AnnotationColor)
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
        case edited
        case ignored
    }

    private let logger = Logger(subsystem: Log.subsystem, category: "capture")
    private let capturer: any DisplayCapturing
    private let presenter: any OverlayPresenting
    private let pasteboard: any ImagePasteboard
    private let saver: ScreenshotSaver
    private let settings: AppSettings?
    private let thumbnails: (any ThumbnailPresenting)?

    private(set) var session: CaptureSession?
    private var isCapturing = false

    /// `settings` overrides the saver's directory and format at save time.
    init(
        capturer: any DisplayCapturing,
        presenter: any OverlayPresenting,
        pasteboard: any ImagePasteboard,
        saver: ScreenshotSaver,
        settings: AppSettings? = nil,
        thumbnails: (any ThumbnailPresenting)? = nil
    ) {
        self.capturer = capturer
        self.presenter = presenter
        self.pasteboard = pasteboard
        self.saver = saver
        self.settings = settings
        self.thumbnails = thumbnails
    }

    var isActive: Bool { session != nil || isCapturing }

    func start() async {
        guard !isActive else { return }
        isCapturing = true
        defer { isCapturing = false }
        thumbnails?.dismiss()

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

    /// Displays were added, removed, or rearranged: the frozen images no longer match.
    func screenConfigurationChanged() {
        guard session != nil else { return }
        logger.notice("Screen configuration changed; cancelling capture")
        finish()
    }

    @discardableResult
    func handle(_ command: OverlayCommand) -> Outcome {
        switch command {
        case .cancel:
            finish()
            return .cancelled

        case .copy:
            guard let output = renderOutput(),
                let png = ImageEncoder.encode(output.image, as: .png, scale: output.scale)
            else { return .noSelection }
            pasteboard.writePNG(png)
            finish()
            showThumbnail(output, fileURL: nil)
            return .copied

        case .save:
            guard let output = renderOutput() else { return .noSelection }
            var saver = saver
            if let settings {
                saver.directory = settings.saveDirectory
                saver.format = settings.imageFormat
            }
            do {
                guard let data = ImageEncoder.encode(output.image, as: saver.format, scale: output.scale) else {
                    return .failed
                }
                let url = try saver.save(data)
                logger.info("Saved \(url.path, privacy: .private)")
                finish()
                showThumbnail(output, fileURL: url)
                return .saved(url)
            } catch {
                logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
                return .failed
            }

        case .undo:
            guard let session else { return .ignored }
            session.undo()
            return .edited

        case .redo:
            guard let session else { return .ignored }
            session.redo()
            return .edited

        case .deleteAnnotation:
            return session?.deleteSelectedAnnotation() == true ? .edited : .ignored

        case .selectTool(let tool):
            guard let session, session.hasSelection else { return .ignored }
            session.toggleTool(tool)
            return .edited

        case .selectColor(let color):
            guard let session, session.hasSelection else { return .ignored }
            session.setColor(color)
            return .edited
        }
    }

    private struct Output {
        let image: CGImage
        let scale: CGFloat
    }

    private func renderOutput() -> Output? {
        guard let session, let image = session.renderedImage() else { return nil }
        return Output(image: image, scale: session.outputScale)
    }

    private func showThumbnail(_ output: Output, fileURL: URL?) {
        guard let thumbnails, settings?.showThumbnail ?? true else { return }
        let pointSize = CGSize(width: CGFloat(output.image.width) / output.scale, height: CGFloat(output.image.height) / output.scale)
        thumbnails.show(output.image, pointSize: pointSize, fileURL: fileURL)
    }

    private func finish() {
        presenter.dismiss()
        session = nil
    }
}
