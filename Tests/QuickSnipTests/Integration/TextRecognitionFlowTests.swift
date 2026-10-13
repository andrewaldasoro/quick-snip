import AppKit
import CoreGraphics
import Foundation
import Testing
import Vision

@testable import QuickSnip

/// Read Text end to end: ⇧⌘C during a capture reads the selection with the real (on-device)
/// Vision recognizer, closes the capture and shows the text; Copy All puts it on the clipboard.
@MainActor
@Suite("Text recognition flow")
struct TextRecognitionFlowTests {
    /// A white display with two lines of black text, like a document on screen.
    private func documentDisplay() throws -> CapturedDisplay {
        let size = CGSize(width: 600, height: 240)
        let context = try #require(
            CGContext(
                data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
        context.setFillColor(.white)
        context.fill(CGRect(origin: .zero, size: size))
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 40), .foregroundColor: NSColor.black]
        NSAttributedString(string: "Invoice 2048", attributes: attributes).draw(at: CGPoint(x: 30, y: 140))
        NSAttributedString(string: "Total due today", attributes: attributes).draw(at: CGPoint(x: 30, y: 60))
        NSGraphicsContext.current = nil
        let image = try #require(context.makeImage())
        return CapturedDisplay(displayID: 1, frame: CGRect(origin: .zero, size: size), image: image)
    }

    private func readDocument(level: RecognizeTextRequest.RecognitionLevel) async throws {
        let display = try documentDisplay()
        do {
            let text = try await VisionTextRecognizer(level: level).recognizeText(in: display.image)
            #expect(text.contains("Invoice"))
        } catch {
            Issue.record("Vision (\(level)) failed: \(String(reflecting: error))")
        }
    }

    /// GitHub's macOS VMs throw `CRImageReaderError.unknownError` for the accurate model (it works
    /// on real Macs); the fallback to fast covers them, tested below.
    @Test(
        .disabled(if: ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true", "Vision's accurate model can't run on GitHub's VMs"))
    func accurateVisionReadsTheDocument() async throws {
        try await readDocument(level: .accurate)
    }

    @Test func fastVisionReadsTheDocument() async throws {
        try await readDocument(level: .fast)
    }

    @Test func commandShiftCReadsTheSelectionThenCopyAllCopiesIt() async throws {
        let display = try documentDisplay()
        let presenter = SpyOverlayPresenter()
        let pasteboard = SpyPasteboard()
        let window = RecognizedTextWindowController(clipboard: pasteboard, activation: SpyAppActivation())
        let controller = CaptureController(
            capturer: FakeDisplayCapturing(displays: [display]),
            presenter: presenter,
            pasteboard: pasteboard,
            saver: ScreenshotSaver(directory: TestImages.temporaryDirectory()),
            textRecognizer: FallbackTextRecognizer.vision,
            recognizedText: window
        )
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        defer {
            for opened in NSApp.windows where opened.title == RecognizedTextWindowController.title { opened.close() }
        }
        await controller.start()
        let session = try #require(presenter.lastSession)
        TestSessions.select(session, on: 1, CGRect(x: 10, y: 10, width: 580, height: 220))

        let command = OverlayKeyMap.command(keyCode: 8, modifiers: [.command, .shift], charactersIgnoringModifiers: "C")
        presenter.send(try #require(command))
        await controller.recognitionTask?.value

        let text = window.model.text
        #expect(!text.isEmpty, "Nothing read; notice: \(session.notice ?? "none")")
        #expect(text.contains("Invoice 2048"))
        #expect(text.contains("Total due today"))
        #expect(text.firstRange(of: "Invoice")!.lowerBound < text.firstRange(of: "Total")!.lowerBound)
        #expect(!presenter.isPresenting)
        #expect(pasteboard.writtenText.isEmpty)

        window.model.copyAll()
        #expect(pasteboard.writtenText == [text])
    }
}
