import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import QuickSnip

/// Phase 3 use cases end to end: preferences shape the output, the thumbnail follows
/// copy/save, keyboard-only annotating, and display changes mid-capture.
@MainActor
@Suite("Output and shortcut flow")
struct OutputAndShortcutFlowTests {
    private let builtIn = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 300, height: 200), scale: 2)
    private let selection = CGRect(x: 20, y: 20, width: 200, height: 150)

    @MainActor
    private struct App {
        let coordinator: CaptureCoordinator
        let controller: CaptureController
        let overlay: SpyOverlayPresenter
        let pasteboard: SpyPasteboard
        let thumbnails: SpyThumbnails
        let settings: AppSettings
        let store: TestDefaults

        var session: CaptureSession { overlay.lastSession! }

        /// A key press on the overlay, routed through the real key map.
        func press(_ chars: String, keyCode: UInt16 = 0, _ modifiers: NSEvent.ModifierFlags = []) {
            if let command = OverlayKeyMap.command(keyCode: keyCode, modifiers: modifiers, charactersIgnoringModifiers: chars) {
                overlay.send(command)
            }
        }
    }

    private func launchApp() -> App {
        let store = TestDefaults()
        let settings = AppSettings(defaults: store.defaults, defaultDirectory: TestImages.temporaryDirectory())
        let overlay = SpyOverlayPresenter()
        let pasteboard = SpyPasteboard()
        let thumbnails = SpyThumbnails()
        let controller = CaptureController(
            capturer: FakeDisplayCapturing(displays: [builtIn]),
            presenter: overlay,
            pasteboard: pasteboard,
            saver: ScreenshotSaver(directory: settings.saveDirectory, now: { Date(timeIntervalSince1970: 1_791_373_780) }, timeZone: .gmt),
            settings: settings,
            thumbnails: thumbnails
        )
        let coordinator = CaptureCoordinator(
            permission: ScreenRecordingPermission(access: FakeScreenCaptureAccess(granted: true), urlOpener: SpyURLOpener()),
            onboarding: SpyOnboarding()
        ) { await controller.start() }
        return App(
            coordinator: coordinator, controller: controller, overlay: overlay, pasteboard: pasteboard,
            thumbnails: thumbnails, settings: settings, store: store
        )
    }

    @Test func changeFolderAndFormatThenSave() async throws {
        let app = launchApp()
        let folder = TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        // Settings window.
        app.settings.saveDirectory = folder
        app.settings.imageFormat = .jpeg

        await app.coordinator.captureRequested()
        TestSessions.select(app.session, on: 1, selection)
        app.press("s", keyCode: 1, .command)

        let file = folder.appendingPathComponent("QuickSnip 2026-10-07 at 11.49.40.jpg")
        let data = try Data(contentsOf: file)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]

        #expect(image.width == 400)
        #expect((props?[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue.rounded() == 144)
        #expect(app.thumbnails.shown.last?.fileURL?.standardizedFileURL == file.standardizedFileURL)
        #expect(app.thumbnails.shown.last?.pointSize == CGSize(width: 200, height: 150))
    }

    @Test func settingsSurviveRelaunch() {
        let app = launchApp()
        app.settings.imageFormat = .jpeg
        app.settings.showThumbnail = false
        let relaunched = AppSettings(defaults: app.store.defaults)
        #expect(relaunched.imageFormat == .jpeg)
        #expect(!relaunched.showThumbnail)
    }

    @Test func hiddenMenuBarIconStillCapturesAndReopenShowsSettings() async throws {
        let app = launchApp()
        app.settings.showMenuBarIcon = false
        #expect(!AppSettings(defaults: app.store.defaults).showMenuBarIcon)

        // Hotkey still works without the icon.
        await app.coordinator.captureRequested()
        TestSessions.select(app.session, on: 1, selection)
        app.press("\r", keyCode: OverlayKeyMap.returnKey)
        #expect(app.pasteboard.written.count == 1)

        // Opening the app again is the way back to Settings.
        let delegate = AppDelegate()
        let settingsWindow = SpySettingsWindow()
        delegate.settingsWindow = settingsWindow
        _ = delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        #expect(settingsWindow.showCount == 1)
    }

    @Test func copyWithThumbnailDisabledShowsNothing() async throws {
        let app = launchApp()
        app.settings.showThumbnail = false
        await app.coordinator.captureRequested()
        TestSessions.select(app.session, on: 1, selection)
        app.press("\r", keyCode: OverlayKeyMap.returnKey)

        #expect(app.pasteboard.written.count == 1)
        #expect(app.thumbnails.shown.isEmpty)
    }

    @Test func keyboardOnlyAnnotateAndCopy() async throws {
        let app = launchApp()
        await app.coordinator.captureRequested()
        TestSessions.select(app.session, on: 1, selection)

        app.press("a")  // arrow tool
        app.press("5")  // blue
        TestSessions.drag(app.session, on: 1, from: CGPoint(x: 40, y: 100), to: CGPoint(x: 180, y: 100))
        app.press("r")  // rectangle
        app.press("1")  // red
        TestSessions.drag(app.session, on: 1, from: CGPoint(x: 50, y: 40), to: CGPoint(x: 120, y: 80))
        app.press("z", keyCode: 6, .command)  // undo rectangle
        app.press("c", keyCode: 8, .command)  // copy

        let png = try #require(app.pasteboard.written.last)
        let image = try #require(TestImages.decodePNG(png))
        func pixel(_ x: CGFloat, _ y: CGFloat) -> RGBA {
            TestImages.pixel(image, x: Int((x - selection.minX) * 2), y: Int((y - selection.minY) * 2))
        }
        #expect(pixel(110, 100).isClose(to: .blue))
        #expect(!pixel(50, 60).isClose(to: .red))
    }

    @Test func pressingToolKeyTwiceReturnsToMoveMode() async throws {
        let app = launchApp()
        await app.coordinator.captureRequested()
        TestSessions.select(app.session, on: 1, selection)
        app.press("p")
        app.press("p")
        #expect(app.session.tool == nil)
    }

    @Test func monitorUnpluggedMidCaptureCancelsCleanly() async {
        let app = launchApp()
        await app.coordinator.captureRequested()
        TestSessions.select(app.session, on: 1, selection)

        app.controller.screenConfigurationChanged()

        #expect(!app.overlay.isPresenting)
        #expect(app.pasteboard.written.isEmpty)
        await app.coordinator.captureRequested()
        #expect(app.overlay.isPresenting)
    }
}
