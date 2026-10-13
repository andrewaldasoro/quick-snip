import CoreGraphics
import Foundation
import Testing

@testable import QuickSnip

@MainActor
struct CaptureControllerTextTests {
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)

    private struct Harness {
        let controller: CaptureController
        let presenter: SpyOverlayPresenter
        let pasteboard: SpyPasteboard
        let recognizer: GatedTextRecognizer
        let recognizedText: SpyRecognizedText
    }

    private func startedWithSelection() async throws -> Harness {
        let presenter = SpyOverlayPresenter()
        let pasteboard = SpyPasteboard()
        let recognizer = GatedTextRecognizer()
        let recognizedText = SpyRecognizedText()
        let controller = CaptureController(
            capturer: FakeDisplayCapturing(displays: [display]),
            presenter: presenter,
            pasteboard: pasteboard,
            saver: ScreenshotSaver(directory: TestImages.temporaryDirectory()),
            textRecognizer: recognizer,
            recognizedText: recognizedText
        )
        await controller.start()
        TestSessions.select(try #require(controller.session), on: 1, CGRect(x: 10, y: 10, width: 40, height: 30))
        return Harness(
            controller: controller, presenter: presenter, pasteboard: pasteboard, recognizer: recognizer, recognizedText: recognizedText)
    }

    /// Regression: the capture closed instantly with no sign the text was read, and no way to
    /// review it or copy just part of it.
    @Test func readTextShowsTheTextAndClosesTheCapture() async throws {
        let h = try await startedWithSelection()

        #expect(h.controller.handle(.readText) == .recognizing)
        let task = try #require(h.controller.recognitionTask)
        await h.recognizer.finish(with: .success("Invoice 2048"))
        await task.value

        #expect(h.recognizedText.shown == ["Invoice 2048"])
        #expect(h.presenter.dismissCount == 1)
        #expect(!h.controller.isActive)
    }

    /// The user decides what to copy (Copy All, or a selection) in the window.
    @Test func readTextCopiesNothingByItself() async throws {
        let h = try await startedWithSelection()
        h.controller.handle(.readText)
        let task = try #require(h.controller.recognitionTask)

        await h.recognizer.finish(with: .success("Invoice 2048"))
        await task.value

        #expect(h.pasteboard.writtenText.isEmpty)
        #expect(h.pasteboard.written.isEmpty)
    }

    @Test func nothingIsShownWhenNoTextIsFound() async throws {
        let h = try await startedWithSelection()
        h.controller.handle(.readText)
        let task = try #require(h.controller.recognitionTask)

        await h.recognizer.finish(with: .success(""))
        await task.value

        #expect(h.recognizedText.shown.isEmpty)
    }

    @Test func readsTheSelectionAtFullResolution() async throws {
        let h = try await startedWithSelection()
        h.controller.handle(.readText)
        let task = try #require(h.controller.recognitionTask)
        await h.recognizer.finish(with: .success("x"))
        await task.value

        // 40 × 30 points on a 2× display.
        #expect(await h.recognizer.imageSizes == [CGSize(width: 80, height: 60)])
    }

    @Test func showsANoticeWhileReading() async throws {
        let h = try await startedWithSelection()
        let session = try #require(h.controller.session)

        h.controller.handle(.readText)

        #expect(session.notice == CaptureController.recognizingNotice)
        await h.recognizer.finish(with: .success(""))
    }

    @Test func noTextKeepsTheCaptureAndSaysSo() async throws {
        let h = try await startedWithSelection()
        let session = try #require(h.controller.session)
        h.controller.handle(.readText)
        let task = try #require(h.controller.recognitionTask)

        await h.recognizer.finish(with: .success(" \n "))
        await task.value

        #expect(session.notice == CaptureController.noTextNotice)
        #expect(h.recognizedText.shown.isEmpty)
        #expect(h.controller.isActive)
    }

    @Test func failureKeepsTheCaptureAndSaysSo() async throws {
        let h = try await startedWithSelection()
        let session = try #require(h.controller.session)
        h.controller.handle(.readText)
        let task = try #require(h.controller.recognitionTask)

        await h.recognizer.finish(with: .failure(TestError()))
        await task.value

        #expect(session.notice == CaptureController.recognitionFailedNotice)
        #expect(h.controller.isActive)
    }

    @Test func cancellingWhileReadingShowsNothing() async throws {
        let h = try await startedWithSelection()
        h.controller.handle(.readText)
        let task = try #require(h.controller.recognitionTask)

        h.controller.handle(.cancel)
        await h.recognizer.finish(with: .success("late"))
        await task.value

        #expect(h.recognizedText.shown.isEmpty)
        #expect(h.controller.recognitionTask == nil)
    }

    @Test func secondReadTextWhileReadingIsIgnored() async throws {
        let h = try await startedWithSelection()
        h.controller.handle(.readText)

        #expect(h.controller.handle(.readText) == .ignored)

        await h.recognizer.finish(with: .success(""))
    }

    @Test func readTextNeedsASelection() async throws {
        let recognizer = GatedTextRecognizer()
        let controller = CaptureController(
            capturer: FakeDisplayCapturing(displays: [display]),
            presenter: SpyOverlayPresenter(),
            pasteboard: SpyPasteboard(),
            saver: ScreenshotSaver(directory: TestImages.temporaryDirectory()),
            textRecognizer: recognizer
        )
        await controller.start()
        #expect(controller.handle(.readText) == .noSelection)
    }

    @Test func nextActionClearsTheNotice() async throws {
        let h = try await startedWithSelection()
        let session = try #require(h.controller.session)
        h.controller.handle(.readText)
        let task = try #require(h.controller.recognitionTask)
        await h.recognizer.finish(with: .success(""))
        await task.value

        h.controller.handle(.selectColor(.blue))

        #expect(session.notice == nil)
    }
}
