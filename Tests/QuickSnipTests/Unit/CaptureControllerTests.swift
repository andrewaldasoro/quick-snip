import CoreGraphics
import Foundation
import Testing
@testable import QuickSnip

@MainActor
struct CaptureControllerTests {
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)

    private struct Harness {
        let controller: CaptureController
        let capturer: FakeDisplayCapturing
        let presenter: SpyOverlayPresenter
        let pasteboard: SpyPasteboard
        let directory: URL
    }

    private func makeHarness(capturer: FakeDisplayCapturing? = nil, directory: URL? = nil) -> Harness {
        let capturer = capturer ?? FakeDisplayCapturing(displays: [display])
        let presenter = SpyOverlayPresenter()
        let pasteboard = SpyPasteboard()
        let directory = directory ?? TestImages.temporaryDirectory()
        let controller = CaptureController(
            capturer: capturer,
            presenter: presenter,
            pasteboard: pasteboard,
            saver: ScreenshotSaver(directory: directory, now: { Date(timeIntervalSince1970: 0) }, timeZone: .gmt)
        )
        return Harness(controller: controller, capturer: capturer, presenter: presenter, pasteboard: pasteboard, directory: directory)
    }

    private func selectSomething(_ harness: Harness) throws {
        let session = try #require(harness.controller.session)
        session.mouseDown(on: 1, at: CGPoint(x: 10, y: 10))
        session.mouseUp(on: 1, at: CGPoint(x: 30, y: 25))
    }

    @Test func startCapturesAndPresentsOverlay() async {
        let h = makeHarness()
        await h.controller.start()
        #expect(h.capturer.callCount == 1)
        #expect(h.presenter.presentCount == 1)
        #expect(h.presenter.presentedSession === h.controller.session)
        #expect(h.controller.isActive)
    }

    @Test func startIgnoredWhileSessionActive() async {
        let h = makeHarness()
        await h.controller.start()
        await h.controller.start()
        #expect(h.capturer.callCount == 1)
        #expect(h.presenter.presentCount == 1)
    }

    @Test func captureErrorPresentsNothing() async {
        let h = makeHarness(capturer: FakeDisplayCapturing(error: TestError()))
        await h.controller.start()
        #expect(h.presenter.presentCount == 0)
        #expect(!h.controller.isActive)
    }

    @Test func noDisplaysPresentsNothing() async {
        let h = makeHarness(capturer: FakeDisplayCapturing(displays: []))
        await h.controller.start()
        #expect(h.presenter.presentCount == 0)
        #expect(!h.controller.isActive)
    }

    @Test func canCaptureAgainAfterFailure() async {
        let capturer = FakeDisplayCapturing(error: TestError())
        let h = makeHarness(capturer: capturer)
        await h.controller.start()
        capturer.result = .success([display])
        await h.controller.start()
        #expect(h.presenter.presentCount == 1)
    }

    @Test(arguments: [OverlayCommand.copy, .save])
    func commandWithoutSelectionKeepsOverlayOpen(command: OverlayCommand) async {
        let h = makeHarness()
        await h.controller.start()
        #expect(h.controller.handle(command) == .noSelection)
        #expect(h.presenter.dismissCount == 0)
        #expect(h.pasteboard.written.isEmpty)
    }

    @Test func copyWritesPNGAndDismisses() async throws {
        let h = makeHarness()
        await h.controller.start()
        try selectSomething(h)

        #expect(h.controller.handle(.copy) == .copied)
        #expect(h.pasteboard.written.count == 1)
        #expect(h.presenter.dismissCount == 1)
        #expect(h.controller.session == nil)
        #expect(!h.controller.isActive)
    }

    @Test func saveWritesFileAndDismisses() async throws {
        let h = makeHarness()
        await h.controller.start()
        try selectSomething(h)

        let outcome = h.controller.handle(.save)
        guard case .saved(let url) = outcome else {
            Issue.record("Expected .saved, got \(outcome)")
            return
        }
        #expect(url.deletingLastPathComponent().standardizedFileURL == h.directory.standardizedFileURL)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(h.presenter.dismissCount == 1)
        try? FileManager.default.removeItem(at: h.directory)
    }

    @Test func saveFailureKeepsOverlayOpen() async throws {
        // A regular file where the directory should be makes the save fail.
        let blocker = TestImages.temporaryDirectory()
        try Data().write(to: blocker)
        let h = makeHarness(directory: blocker)
        await h.controller.start()
        try selectSomething(h)

        #expect(h.controller.handle(.save) == .failed)
        #expect(h.presenter.dismissCount == 0)
        #expect(h.controller.isActive)
        try? FileManager.default.removeItem(at: blocker)
    }

    @Test func cancelDismissesWithoutOutput() async {
        let h = makeHarness()
        await h.controller.start()
        #expect(h.controller.handle(.cancel) == .cancelled)
        #expect(h.presenter.dismissCount == 1)
        #expect(h.pasteboard.written.isEmpty)
        #expect(!h.controller.isActive)
    }

    @Test func overlayCommandsRouteToController() async throws {
        let h = makeHarness()
        await h.controller.start()
        try selectSomething(h)
        h.presenter.send(.copy)
        #expect(h.pasteboard.written.count == 1)
    }
}
