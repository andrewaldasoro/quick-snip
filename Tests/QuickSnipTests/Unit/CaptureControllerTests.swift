import CoreGraphics
import Foundation
import ImageIO
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

@MainActor
struct CaptureControllerEditingTests {
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)

    private func startedController() async throws -> (CaptureController, CaptureSession) {
        let controller = CaptureController(
            capturer: FakeDisplayCapturing(displays: [display]),
            presenter: SpyOverlayPresenter(),
            pasteboard: SpyPasteboard(),
            saver: ScreenshotSaver(directory: TestImages.temporaryDirectory())
        )
        await controller.start()
        let session = try #require(controller.session)
        TestSessions.select(session, on: 1, CGRect(x: 10, y: 10, width: 60, height: 50))
        session.toggleTool(.shape)
        TestSessions.drag(session, on: 1, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 40, y: 40))
        return (controller, session)
    }

    @Test func undoAndRedoCommands() async throws {
        let (controller, session) = try await startedController()
        #expect(controller.handle(.undo) == .edited)
        #expect(session.document.annotations.isEmpty)
        #expect(controller.handle(.redo) == .edited)
        #expect(session.document.annotations.count == 1)
    }

    @Test func deleteCommandNeedsASelectedAnnotation() async throws {
        let (controller, session) = try await startedController()
        TestSessions.drag(session, on: 1, from: CGPoint(x: 60, y: 50), to: CGPoint(x: 60, y: 50))  // empty spot: deselects
        #expect(controller.handle(.deleteAnnotation) == .ignored)

        TestSessions.drag(session, on: 1, from: CGPoint(x: 30, y: 20), to: CGPoint(x: 30, y: 20))  // its top edge
        #expect(controller.handle(.deleteAnnotation) == .edited)
        #expect(session.document.annotations.isEmpty)
    }

    @Test func editingCommandsWithoutSessionAreIgnored() {
        let controller = CaptureController(
            capturer: FakeDisplayCapturing(displays: []),
            presenter: SpyOverlayPresenter(),
            pasteboard: SpyPasteboard(),
            saver: ScreenshotSaver(directory: TestImages.temporaryDirectory())
        )
        #expect(controller.handle(.undo) == .ignored)
        #expect(controller.handle(.redo) == .ignored)
        #expect(controller.handle(.deleteAnnotation) == .ignored)
    }
}

@MainActor
struct CaptureControllerOutputTests {
    private let retina = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)

    private func make(
        settings: AppSettings? = nil,
        thumbnails: SpyThumbnails? = SpyThumbnails(),
        directory: URL = TestImages.temporaryDirectory()
    ) -> (CaptureController, SpyOverlayPresenter, SpyPasteboard) {
        let presenter = SpyOverlayPresenter()
        let pasteboard = SpyPasteboard()
        let controller = CaptureController(
            capturer: FakeDisplayCapturing(displays: [retina]),
            presenter: presenter,
            pasteboard: pasteboard,
            saver: ScreenshotSaver(directory: directory, now: { Date(timeIntervalSince1970: 0) }, timeZone: .gmt),
            settings: settings,
            thumbnails: thumbnails
        )
        return (controller, presenter, pasteboard)
    }

    private func select(_ controller: CaptureController) throws {
        TestSessions.select(try #require(controller.session), on: 1, CGRect(x: 10, y: 10, width: 40, height: 30))
    }

    @Test func startDismissesPreviousThumbnail() async {
        let thumbnails = SpyThumbnails()
        let (controller, _, _) = make(thumbnails: thumbnails)
        await controller.start()
        #expect(thumbnails.dismissCount == 1)
    }

    @Test func copyShowsThumbnailAtPointSize() async throws {
        let thumbnails = SpyThumbnails()
        let (controller, _, _) = make(thumbnails: thumbnails)
        await controller.start()
        try select(controller)
        controller.handle(.copy)

        #expect(thumbnails.shown.count == 1)
        #expect(thumbnails.shown.first?.size == CGSize(width: 80, height: 60))
        #expect(thumbnails.shown.first?.pointSize == CGSize(width: 40, height: 30))
        #expect(thumbnails.shown.first?.fileURL == nil)
    }

    @Test func saveShowsThumbnailWithFile() async throws {
        let thumbnails = SpyThumbnails()
        let directory = TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (controller, _, _) = make(thumbnails: thumbnails, directory: directory)
        await controller.start()
        try select(controller)

        guard case .saved(let url) = controller.handle(.save) else {
            Issue.record("Expected save")
            return
        }
        #expect(thumbnails.shown.first?.fileURL == url)
    }

    @Test func thumbnailCanBeTurnedOff() async throws {
        let store = TestDefaults()
        let settings = AppSettings(defaults: store.defaults)
        settings.showThumbnail = false
        let thumbnails = SpyThumbnails()
        let (controller, _, _) = make(settings: settings, thumbnails: thumbnails)
        await controller.start()
        try select(controller)
        controller.handle(.copy)
        #expect(thumbnails.shown.isEmpty)
    }

    @Test func newCaptureStartsWithTheRememberedTextStyle() async throws {
        let store = TestDefaults()
        let settings = AppSettings(defaults: store.defaults)
        settings.textFont = .serif
        settings.textSize = 40
        let (controller, _, _) = make(settings: settings)
        await controller.start()

        let session = try #require(controller.session)
        #expect(session.style.font == .serif)
        #expect(session.style.fontSize == 40)
    }

    @Test func textStyleChangesAreRemembered() async throws {
        let store = TestDefaults()
        let settings = AppSettings(defaults: store.defaults)
        let (controller, _, _) = make(settings: settings)
        await controller.start()

        let session = try #require(controller.session)
        session.setFont(.monospaced)
        session.setFontSize(64)

        #expect(settings.textFont == .monospaced)
        #expect(settings.textSize == 64)
    }

    @Test func saveUsesSettingsFolderAndFormat() async throws {
        let store = TestDefaults()
        let settings = AppSettings(defaults: store.defaults)
        let folder = TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        settings.saveDirectory = folder
        settings.imageFormat = .jpeg
        let (controller, _, _) = make(settings: settings)
        await controller.start()
        try select(controller)

        guard case .saved(let url) = controller.handle(.save) else {
            Issue.record("Expected save")
            return
        }
        #expect(url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL)
        #expect(url.pathExtension == "jpg")
        let data = try Data(contentsOf: url)
        #expect(Array(data.prefix(3)) == [0xFF, 0xD8, 0xFF])
    }

    @Test func copiedPNGCarriesRetinaDPI() async throws {
        let (controller, _, pasteboard) = make()
        await controller.start()
        try select(controller)
        controller.handle(.copy)

        let data = try #require(pasteboard.written.last)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        #expect((props?[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue.rounded() == 144)
    }

    @Test func toolAndColorCommandsNeedASelection() async throws {
        let (controller, _, _) = make()
        await controller.start()
        #expect(controller.handle(.selectTool(.arrow)) == .ignored)

        try select(controller)
        #expect(controller.handle(.selectTool(.arrow)) == .edited)
        #expect(controller.session?.tool == .arrow)
        #expect(controller.handle(.selectColor(.green)) == .edited)
        #expect(controller.session?.style.color == .green)
    }

    @Test func screenChangeCancelsActiveCapture() async {
        let (controller, presenter, _) = make()
        await controller.start()
        controller.screenConfigurationChanged()
        #expect(presenter.dismissCount == 1)
        #expect(!controller.isActive)
    }

    @Test func screenChangeWithoutCaptureDoesNothing() {
        let (controller, presenter, _) = make()
        controller.screenConfigurationChanged()
        #expect(presenter.dismissCount == 0)
    }
}

@MainActor
struct CaptureControllerCheatsheetTests {
    private let display = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)

    private func startedController() async throws -> (CaptureController, SpyOverlayPresenter, CaptureSession) {
        let presenter = SpyOverlayPresenter()
        let controller = CaptureController(
            capturer: FakeDisplayCapturing(displays: [display]),
            presenter: presenter,
            pasteboard: SpyPasteboard(),
            saver: ScreenshotSaver(directory: TestImages.temporaryDirectory())
        )
        await controller.start()
        return (controller, presenter, try #require(controller.session))
    }

    @Test func toggleShowsCheatsheetWithoutASelection() async throws {
        let (controller, _, session) = try await startedController()
        #expect(controller.handle(.toggleCheatsheet) == .edited)
        #expect(session.isShowingCheatsheet)
    }

    @Test func toggleWithoutCaptureIsIgnored() {
        let controller = CaptureController(
            capturer: FakeDisplayCapturing(displays: [display]),
            presenter: SpyOverlayPresenter(),
            pasteboard: SpyPasteboard(),
            saver: ScreenshotSaver(directory: TestImages.temporaryDirectory())
        )
        #expect(controller.handle(.toggleCheatsheet) == .ignored)
    }

    @Test func escapeClosesCheatsheetAndKeepsCapture() async throws {
        let (controller, presenter, session) = try await startedController()
        controller.handle(.toggleCheatsheet)

        #expect(controller.handle(.cancel) == .edited)

        #expect(!session.isShowingCheatsheet)
        #expect(controller.isActive)
        #expect(presenter.dismissCount == 0)
    }

    @Test func escapeAfterClosingCheatsheetCancels() async throws {
        let (controller, presenter, _) = try await startedController()
        controller.handle(.toggleCheatsheet)
        controller.handle(.cancel)

        #expect(controller.handle(.cancel) == .cancelled)
        #expect(presenter.dismissCount == 1)
    }
}
