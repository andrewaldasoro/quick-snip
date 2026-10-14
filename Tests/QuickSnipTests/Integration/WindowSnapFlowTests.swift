import CoreGraphics
import Foundation
import Testing

@testable import QuickSnip

/// Window snap end to end: the capture carries the window frames, hovering highlights one,
/// a click selects it, and Copy crops exactly that window at full resolution. A covered window
/// is captured on its own first, so the copy holds the window, not what was in front of it.
@MainActor
@Suite("Window snap flow")
struct WindowSnapFlowTests {
    private let red = RGBA(r: 255, g: 0, b: 0, a: 255)
    private let back = SnapWindow(
        id: 7, frame: CGRect(x: 30, y: 20, width: 40, height: 30), visibleFrame: CGRect(x: 30, y: 20, width: 40, height: 30))
    private let front = SnapWindow(
        id: 8, frame: CGRect(x: 0, y: 0, width: 50, height: 40), visibleFrame: CGRect(x: 0, y: 0, width: 50, height: 40))

    @MainActor
    private struct App {
        let controller: CaptureController
        let presenter: SpyOverlayPresenter
        let pasteboard: SpyPasteboard
        let windowCapturer: GatedWindowCapturer

        func copiedImage() throws -> CGImage {
            let png = try #require(pasteboard.written.last)
            return try #require(TestImages.decodePNG(png))
        }
    }

    /// A 100 × 80 point Retina display whose pixels encode their own coordinates.
    private func launch(windows: [SnapWindow]) async throws -> App {
        let retina = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)
        let display = CapturedDisplay(displayID: 1, frame: retina.frame, image: retina.image, windows: windows)
        let presenter = SpyOverlayPresenter()
        let pasteboard = SpyPasteboard()
        let windowCapturer = GatedWindowCapturer()
        let controller = CaptureController(
            capturer: FakeDisplayCapturing(displays: [display]),
            presenter: presenter,
            pasteboard: pasteboard,
            saver: ScreenshotSaver(directory: TestImages.temporaryDirectory()),
            windowCapturer: windowCapturer
        )
        await controller.start()
        return App(controller: controller, presenter: presenter, pasteboard: pasteboard, windowCapturer: windowCapturer)
    }

    private func click(_ app: App, at point: CGPoint) throws {
        let session = try #require(app.presenter.presentedSession)
        session.mouseMoved(on: 1, to: point)
        session.mouseDown(on: 1, at: point)
        session.mouseUp(on: 1, at: point)
    }

    @Test func clickingAWindowThenCopyingCopiesThatWindow() async throws {
        let app = try await launch(windows: [back])
        try click(app, at: CGPoint(x: 50, y: 35))

        app.presenter.send(.copy)

        let image = try app.copiedImage()
        #expect(image.width == 80)
        #expect(image.height == 60)
        // Pixels encode their own coordinates: the crop starts at the window's top-left (60, 40 px).
        #expect(TestImages.pixel(image, x: 0, y: 0) == RGBA(r: 60, g: 40, b: 0, a: 255))
        #expect(app.windowCapturer.requests.isEmpty)
    }

    /// Regression: snapping to a window behind another copied the other window's pixels.
    @Test func copyingACoveredWindowCopiesTheWindowItself() async throws {
        let app = try await launch(windows: [front, back])
        try click(app, at: CGPoint(x: 60, y: 45))

        // Return pressed before the window's capture is in: the copy waits for it.
        #expect(app.controller.handle(.copy) == .waiting)
        #expect(app.pasteboard.written.isEmpty)
        let pending = try #require(app.controller.windowCaptureTask)
        app.windowCapturer.finish(with: .success(TestImages.solidImage(width: 80, height: 60, color: red)))
        await pending.value
        await Task.yield()
        #expect(app.windowCapturer.requests.map(\.id) == [7])
        #expect(app.windowCapturer.requests.map(\.pixelSize) == [CGSize(width: 80, height: 60)])

        let image = try app.copiedImage()
        #expect(image.width == 80)
        #expect(TestImages.pixel(image, x: 0, y: 0) == red)
        #expect(!app.presenter.isPresenting)
    }

    @Test func aFailedWindowCaptureKeepsWhatTheScreenShowed() async throws {
        let app = try await launch(windows: [front, back])
        try click(app, at: CGPoint(x: 60, y: 45))
        let pending = try #require(app.controller.windowCaptureTask)

        app.windowCapturer.finish(with: .failure(TestError()))
        await pending.value
        app.presenter.send(.copy)

        #expect(TestImages.pixel(try app.copiedImage(), x: 0, y: 0) == RGBA(r: 60, g: 40, b: 0, a: 255))
    }

    @Test func cancellingDropsTheWindowCapture() async throws {
        let app = try await launch(windows: [front, back])
        try click(app, at: CGPoint(x: 60, y: 45))
        let pending = try #require(app.controller.windowCaptureTask)

        app.presenter.send(.cancel)
        app.windowCapturer.finish(with: .success(TestImages.solidImage(width: 80, height: 60, color: red)))
        await pending.value

        #expect(app.controller.windowCaptureTask == nil)
        #expect(app.pasteboard.written.isEmpty)
    }
}
