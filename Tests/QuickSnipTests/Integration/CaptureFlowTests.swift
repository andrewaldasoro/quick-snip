import CoreGraphics
import Foundation
import Testing

@testable import QuickSnip

/// Most common use cases end to end: hotkey → permission check → freeze displays →
/// select → copy / save / cancel. Only OS seams are faked (TCC, ScreenCaptureKit,
/// windows, pasteboard); selection, cropping, PNG encoding and file writing are real.
@MainActor
@Suite("Capture flow")
struct CaptureFlowTests {
    /// Built-in Retina display + 1x external to its right.
    private let builtIn = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2)
    private let external = TestImages.display(id: 2, frame: CGRect(x: 100, y: 0, width: 120, height: 90), scale: 1)

    @MainActor
    private struct App {
        let coordinator: CaptureCoordinator
        let controller: CaptureController
        let access: FakeScreenCaptureAccess
        let capturer: FakeDisplayCapturing
        let overlay: SpyOverlayPresenter
        let onboarding: SpyOnboarding
        let pasteboard: SpyPasteboard
        let saveDirectory: URL

        var session: CaptureSession? { overlay.presentedSession }

        /// Mouse drag on the overlay of `display`, in display-local points.
        func drag(on display: CGDirectDisplayID, from start: CGPoint, to end: CGPoint) throws {
            let session = try #require(session)
            session.mouseDown(on: display, at: start)
            session.mouseDragged(on: display, to: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2))
            session.mouseUp(on: display, at: end)
        }

        func copiedImage() throws -> CGImage {
            let png = try #require(pasteboard.written.last)
            return try #require(TestImages.decodePNG(png))
        }
    }

    private func launchApp(granted: Bool = true, displays: [CapturedDisplay]? = nil) -> App {
        let access = FakeScreenCaptureAccess(granted: granted)
        let permission = ScreenRecordingPermission(access: access, urlOpener: SpyURLOpener())
        let capturer = FakeDisplayCapturing(displays: displays ?? [builtIn, external])
        let overlay = SpyOverlayPresenter()
        let onboarding = SpyOnboarding()
        let pasteboard = SpyPasteboard()
        let saveDirectory = TestImages.temporaryDirectory()
        let controller = CaptureController(
            capturer: capturer,
            presenter: overlay,
            pasteboard: pasteboard,
            saver: ScreenshotSaver(directory: saveDirectory, now: { Date(timeIntervalSince1970: 1_791_373_780) }, timeZone: .gmt)
        )
        let coordinator = CaptureCoordinator(permission: permission, onboarding: onboarding) {
            await controller.start()
        }
        coordinator.appDidLaunch()
        return App(
            coordinator: coordinator, controller: controller, access: access, capturer: capturer, overlay: overlay,
            onboarding: onboarding, pasteboard: pasteboard, saveDirectory: saveDirectory
        )
    }

    @Test func hotkeySelectCopyOnRetina() async throws {
        let app = launchApp()

        await app.coordinator.captureRequested()
        #expect(app.overlay.isPresenting)
        #expect(app.session?.displays.count == 2)

        try app.drag(on: 1, from: CGPoint(x: 10, y: 20), to: CGPoint(x: 40, y: 35))
        app.overlay.send(.copy)

        let image = try app.copiedImage()
        #expect(image.width == 60)
        #expect(image.height == 30)
        #expect(TestImages.pixel(image, x: 0, y: 0) == RGBA(r: 20, g: 40, b: 0, a: 255))
        #expect(!app.overlay.isPresenting)
        #expect(!app.controller.isActive)
    }

    @Test func hotkeySelectCopyOnExternalOneXDisplay() async throws {
        let app = launchApp()
        await app.coordinator.captureRequested()

        try app.drag(on: 2, from: CGPoint(x: 50, y: 60), to: CGPoint(x: 5, y: 10))
        app.overlay.send(.copy)

        let image = try app.copiedImage()
        #expect(image.width == 45)
        #expect(image.height == 50)
        #expect(TestImages.pixel(image, x: 0, y: 0) == RGBA(r: 5, g: 10, b: 0, a: 255))
    }

    @Test func switchingDisplaysMidCaptureUsesLastSelection() async throws {
        let app = launchApp()
        await app.coordinator.captureRequested()

        try app.drag(on: 1, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 30, y: 30))
        try app.drag(on: 2, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 15, y: 12))
        app.overlay.send(.copy)

        let image = try app.copiedImage()
        #expect(image.width == 15)
        #expect(image.height == 12)
        #expect(app.session == nil)
    }

    @Test func adjustSelectionThenCopy() async throws {
        let app = launchApp()
        await app.coordinator.captureRequested()

        try app.drag(on: 1, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 30, y: 30))
        // Move it by (+20, +5), then pull the bottom-right corner out by (+10, +10).
        try app.drag(on: 1, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 40, y: 25))
        try app.drag(on: 1, from: CGPoint(x: 50, y: 35), to: CGPoint(x: 60, y: 45))
        app.overlay.send(.copy)

        let image = try app.copiedImage()
        #expect(image.width == 60)  // (60 - 30) pt × 2
        #expect(image.height == 60)  // (45 - 15) pt × 2
        #expect(TestImages.pixel(image, x: 0, y: 0) == RGBA(r: 60, g: 30, b: 0, a: 255))
    }

    @Test func hotkeySelectSaveWritesPNGFile() async throws {
        let app = launchApp()
        defer { try? FileManager.default.removeItem(at: app.saveDirectory) }
        await app.coordinator.captureRequested()

        try app.drag(on: 1, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 25, y: 20))
        app.overlay.send(.save)

        let file = app.saveDirectory.appendingPathComponent("QuickSnip 2026-10-07 at 11.49.40.png")
        let image = try #require(TestImages.decodePNG(try Data(contentsOf: file)))
        #expect(image.width == 50)
        #expect(image.height == 40)
        #expect(app.pasteboard.written.isEmpty)
        #expect(!app.overlay.isPresenting)
    }

    @Test func escapeCancelsWithoutOutput() async throws {
        let app = launchApp()
        await app.coordinator.captureRequested()
        try app.drag(on: 1, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 25, y: 20))

        app.overlay.send(.cancel)

        #expect(app.pasteboard.written.isEmpty)
        #expect(!app.overlay.isPresenting)
        #expect(!FileManager.default.fileExists(atPath: app.saveDirectory.path))
    }

    @Test func copyWithoutSelectionKeepsOverlayOpenUntilSelected() async throws {
        let app = launchApp()
        await app.coordinator.captureRequested()

        app.overlay.send(.copy)
        #expect(app.overlay.isPresenting)

        try app.drag(on: 1, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 10, y: 10))
        app.overlay.send(.copy)
        #expect(app.pasteboard.written.count == 1)
    }

    @Test func secondCaptureAfterFirstCompletes() async throws {
        let app = launchApp()
        await app.coordinator.captureRequested()
        app.overlay.send(.cancel)

        await app.coordinator.captureRequested()
        #expect(app.capturer.callCount == 2)
        #expect(app.overlay.isPresenting)
    }

    @Test func hotkeyWhileOverlayOpenDoesNotRecapture() async {
        let app = launchApp()
        await app.coordinator.captureRequested()
        await app.coordinator.captureRequested()
        #expect(app.capturer.callCount == 1)
        #expect(app.overlay.presentCount == 1)
    }

    @Test func hotkeyWithoutPermissionNeverCaptures() async {
        let app = launchApp(granted: false)
        await app.coordinator.captureRequested()
        #expect(app.capturer.callCount == 0)
        #expect(!app.overlay.isPresenting)
        #expect(app.onboarding.showCount == 2)  // launch + hotkey
    }
}
