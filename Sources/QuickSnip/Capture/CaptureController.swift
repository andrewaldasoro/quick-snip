import CoreGraphics
import Foundation
import OSLog

enum OverlayCommand: Hashable, Sendable {
    case copy
    case readText
    case save
    case cancel
    case undo
    case redo
    case deleteAnnotation
    case selectTool(AnnotationTool)
    case selectColor(AnnotationColor)
    case toggleCheatsheet
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
        case recognizing
    }

    static let recognizingNotice = "Reading text…"
    static let noTextNotice = "No text found"
    static let recognitionFailedNotice = "Couldn’t read the text"

    private let logger = Logger(subsystem: Log.subsystem, category: "capture")
    private let capturer: any DisplayCapturing
    private let presenter: any OverlayPresenting
    private let pasteboard: any ClipboardWriting
    private let saver: ScreenshotSaver
    private let settings: AppSettings?
    private let thumbnails: (any ThumbnailPresenting)?
    private let textRecognizer: any TextRecognizing
    private let recognizedText: (any RecognizedTextPresenting)?

    private(set) var session: CaptureSession?
    /// Text recognition for Read Text, while it runs.
    private(set) var recognitionTask: Task<Void, Never>?
    private var isCapturing = false

    /// `settings` overrides the saver's directory and format at save time.
    init(
        capturer: any DisplayCapturing,
        presenter: any OverlayPresenting,
        pasteboard: any ClipboardWriting,
        saver: ScreenshotSaver,
        settings: AppSettings? = nil,
        thumbnails: (any ThumbnailPresenting)? = nil,
        textRecognizer: any TextRecognizing = FallbackTextRecognizer.vision,
        recognizedText: (any RecognizedTextPresenting)? = nil
    ) {
        self.capturer = capturer
        self.presenter = presenter
        self.pasteboard = pasteboard
        self.saver = saver
        self.settings = settings
        self.thumbnails = thumbnails
        self.textRecognizer = textRecognizer
        self.recognizedText = recognizedText
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
        // A notice answers the last action; the next one replaces it (unless text is still being read).
        if recognitionTask == nil { session?.clearNotice() }

        switch command {
        case .cancel:
            // Esc closes the cheatsheet first, so checking a shortcut doesn't throw the capture away.
            if let session, session.isShowingCheatsheet {
                session.hideCheatsheet()
                return .edited
            }
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

        case .readText:
            return recognizeText()

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

        case .toggleCheatsheet:
            guard let session else { return .ignored }
            session.toggleCheatsheet()
            return .edited
        }
    }

    /// Reads the text in the selection off the main thread, then closes the capture and shows the text.
    /// It reads the rendered image, annotations included, so text the user pixelated stays private.
    private func recognizeText() -> Outcome {
        guard recognitionTask == nil else { return .ignored }
        guard let session, let image = session.renderedImage() else { return .noSelection }
        session.showNotice(Self.recognizingNotice)
        let recognizer = textRecognizer
        recognitionTask = Task { [weak self] in
            let text: String?
            do {
                text = try await recognizer.recognizeText(in: image)
            } catch {
                self?.logger.error("Text recognition failed: \(error.localizedDescription, privacy: .public)")
                text = nil
            }
            guard !Task.isCancelled else { return }
            self?.finishRecognition(text, in: session)
        }
        return .recognizing
    }

    private func finishRecognition(_ text: String?, in recognized: CaptureSession) {
        recognitionTask = nil
        guard recognized === session else { return }
        guard let text else {
            recognized.showNotice(Self.recognitionFailedNotice)
            return
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            recognized.showNotice(Self.noTextNotice)
            return
        }
        // Nothing goes to the clipboard yet: the window lets the user copy all of it, part of
        // it, or none.
        finish()
        recognizedText?.show(text)
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
        recognitionTask?.cancel()
        recognitionTask = nil
        presenter.dismiss()
        session = nil
    }
}
