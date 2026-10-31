import CoreGraphics
import Foundation
import Testing

@testable import QuickSnip

/// Common annotation use cases end to end: hotkey → select → annotate (toolbar + mouse) →
/// copy / save. Output PNGs are decoded and checked pixel by pixel.
@MainActor
@Suite("Annotation flow")
struct AnnotationFlowTests {
    /// Retina built-in display; selection (20, 20)–(220, 170) pt → 400×300 px.
    private let builtIn = TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 300, height: 200), scale: 2)
    private let selection = CGRect(x: 20, y: 20, width: 200, height: 150)

    @MainActor
    private struct App {
        let coordinator: CaptureCoordinator
        let controller: CaptureController
        let overlay: SpyOverlayPresenter
        let pasteboard: SpyPasteboard
        let saveDirectory: URL
        let selection: CGRect

        var session: CaptureSession { overlay.lastSession! }

        /// Hotkey, then drag out the selection.
        func captureAndSelect() async {
            await coordinator.captureRequested()
            TestSessions.select(session, on: 1, selection)
        }

        /// Toolbar tool click + drag on the overlay.
        func draw(_ tool: AnnotationTool, from start: CGPoint, through points: [CGPoint] = [], to end: CGPoint) {
            if session.tool != tool { session.toggleTool(tool) }
            TestSessions.drag(session, on: 1, from: start, through: points, to: end)
        }

        func copied() throws -> CGImage {
            let png = try #require(pasteboard.written.last)
            return try #require(TestImages.decodePNG(png))
        }

        /// Pixel in the copied image for a display-local point.
        func pixel(_ image: CGImage, atPoint x: CGFloat, _ y: CGFloat) -> RGBA {
            TestImages.pixel(image, x: Int((x - selection.minX) * 2), y: Int((y - selection.minY) * 2))
        }
    }

    private func launchApp(settings: AppSettings? = nil) -> App {
        let permission = ScreenRecordingPermission(access: FakeScreenCaptureAccess(granted: true), urlOpener: SpyURLOpener())
        let overlay = SpyOverlayPresenter()
        let pasteboard = SpyPasteboard()
        let saveDirectory = TestImages.temporaryDirectory()
        let controller = CaptureController(
            capturer: FakeDisplayCapturing(displays: [builtIn]),
            presenter: overlay,
            pasteboard: pasteboard,
            saver: ScreenshotSaver(directory: saveDirectory, now: { Date(timeIntervalSince1970: 1_791_373_780) }, timeZone: .gmt),
            settings: settings
        )
        let coordinator = CaptureCoordinator(permission: permission, onboarding: SpyOnboarding()) {
            await controller.start()
        }
        return App(
            coordinator: coordinator, controller: controller, overlay: overlay,
            pasteboard: pasteboard, saveDirectory: saveDirectory, selection: selection
        )
    }

    private func original(atPoint x: CGFloat, _ y: CGFloat) -> RGBA {
        TestImages.pixel(builtIn.image, x: Int(x * 2), y: Int(y * 2))
    }

    @Test func highlightABugWithARectangleAndCopy() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        app.draw(.shape, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 120))
        app.overlay.send(.copy)

        let image = try app.copied()
        #expect(image.width == 400)
        #expect(image.height == 300)
        #expect(app.pixel(image, atPoint: 50, 80).isClose(to: .red))
        #expect(app.pixel(image, atPoint: 100, 120).isClose(to: .red))
        #expect(app.pixel(image, atPoint: 100, 80) == original(atPoint: 100, 80))
        #expect(!app.overlay.isPresenting)
    }

    @Test func pointAtSomethingWithABlueArrow() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        app.session.setColor(.blue)
        app.draw(.arrow, from: CGPoint(x: 40, y: 100), to: CGPoint(x: 160, y: 100))
        app.overlay.send(.copy)

        let image = try app.copied()
        #expect(app.pixel(image, atPoint: 100, 100).isClose(to: .blue))
        #expect(app.pixel(image, atPoint: 152, 103).isClose(to: .blue))  // arrow head
    }

    @Test func hideSensitiveInfoWithPixelate() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        app.draw(.pixelate, from: CGPoint(x: 60, y: 60), to: CGPoint(x: 140, y: 100))
        app.overlay.send(.copy)

        let image = try app.copied()
        // Inside: neighbouring pixels identical (blocks). Outside: original detail kept.
        #expect(app.pixel(image, atPoint: 62, 62) == app.pixel(image, atPoint: 62.5, 62.5))
        #expect(app.pixel(image, atPoint: 62, 62) != original(atPoint: 62, 62))
        #expect(app.pixel(image, atPoint: 30, 30) == original(atPoint: 30, 30))
    }

    @Test func addATextLabel() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        var requested: TextPlacement?
        app.session.onRequestTextEntry = { _, request in requested = request.placement }
        app.session.toggleTool(.text)
        TestSessions.drag(app.session, on: 1, from: CGPoint(x: 60, y: 60), to: CGPoint(x: 60, y: 60))  // a click
        let placement = try #require(requested)
        #expect(placement == .line(at: CGPoint(x: 60, y: 60)))
        app.session.addText("Bug here", at: placement, on: 1)
        app.overlay.send(.copy)

        let image = try app.copied()
        let bounds = try #require(app.session.document.annotations.first).bounds
        var changed = 0
        for y in stride(from: bounds.minY, to: bounds.maxY, by: 1) {
            for x in stride(from: bounds.minX, to: bounds.maxX, by: 1) where app.pixel(image, atPoint: x, y) != original(atPoint: x, y) {
                changed += 1
            }
        }
        #expect(changed > 20)
    }

    /// Drag out a box with the text tool: the text wraps inside it, centered.
    @Test func centeredTextWrapsInsideADraggedBox() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        var requested: TextPlacement?
        app.session.onRequestTextEntry = { _, request in requested = request.placement }
        app.session.toggleTool(.text)
        app.session.setAlignment(.center)
        TestSessions.drag(app.session, on: 1, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 160, y: 50))
        let placement = try #require(requested)
        #expect(placement == TextPlacement(origin: CGPoint(x: 40, y: 40), boxWidth: 120))
        app.session.addText("Wrap this sentence onto more lines", at: placement, on: 1)
        app.overlay.send(.copy)

        let text = try #require(app.session.document.annotations.first)
        #expect(text.bounds.width == 120)
        #expect(text.bounds.height > TextLayout.lineHeight(text.style) * 1.5)  // wrapped
        let image = try app.copied()
        var changedOnSecondLine = 0
        let secondLine = text.bounds.minY + TextLayout.lineHeight(text.style) * 1.5
        for x in stride(from: CGFloat(40), to: 160, by: 1)
        where app.pixel(image, atPoint: x, secondLine) != original(atPoint: x, secondLine) {
            changedOnSecondLine += 1
        }
        #expect(changedOnSecondLine > 3)
    }

    @Test func largeSerifTextIsExportedAtItsSizeAndRemembered() async throws {
        let store = TestDefaults()
        let app = launchApp(settings: AppSettings(defaults: store.defaults, defaultDirectory: TestImages.temporaryDirectory()))
        await app.captureAndSelect()

        app.session.toggleTool(.text)
        app.session.setFont(.serif)
        app.session.setFontSize(60)
        app.session.addText("WWW", at: .line(at: CGPoint(x: 40, y: 40)), on: 1)
        app.overlay.send(.copy)

        // Default-size text would end ~30pt down; 60pt glyphs reach well past that.
        let image = try app.copied()
        var changed = 0
        for y in stride(from: CGFloat(80), to: 95, by: 1) {
            for x in stride(from: CGFloat(40), to: 180, by: 1) where app.pixel(image, atPoint: x, y) != original(atPoint: x, y) {
                changed += 1
            }
        }
        #expect(changed > 20)

        await app.captureAndSelect()
        #expect(app.session.style.font == .serif)
        #expect(app.session.style.fontSize == 60)
    }

    @Test func undoMistakeThenRedo() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        app.draw(.arrow, from: CGPoint(x: 40, y: 140), to: CGPoint(x: 200, y: 140))
        app.overlay.send(.undo)
        app.overlay.send(.copy)
        let undone = try app.copied()
        #expect(app.pixel(undone, atPoint: 100, 140) == original(atPoint: 100, 140))
    }

    @Test func redoRestoresUndoneAnnotation() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        app.draw(.arrow, from: CGPoint(x: 40, y: 140), to: CGPoint(x: 200, y: 140))
        app.overlay.send(.undo)
        app.overlay.send(.redo)
        app.overlay.send(.copy)
        #expect(app.pixel(try app.copied(), atPoint: 100, 140).isClose(to: .red))
    }

    @Test func moveAnAnnotationThenDeleteAnother() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        app.draw(.shape, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 80, y: 80))
        app.draw(.shape, from: CGPoint(x: 120, y: 40), to: CGPoint(x: 160, y: 80))

        // Drag the first rectangle down by 60pt.
        TestSessions.drag(app.session, on: 1, from: CGPoint(x: 40, y: 60), to: CGPoint(x: 40, y: 120))
        // Select the second and delete it.
        TestSessions.drag(app.session, on: 1, from: CGPoint(x: 160, y: 60), to: CGPoint(x: 160, y: 60))
        app.overlay.send(.deleteAnnotation)
        app.overlay.send(.copy)

        let image = try app.copied()
        #expect(app.pixel(image, atPoint: 40, 120).isClose(to: .red))  // moved
        #expect(app.pixel(image, atPoint: 40, 60) == original(atPoint: 40, 60))  // old spot clear
        #expect(app.pixel(image, atPoint: 160, 60) == original(atPoint: 160, 60))  // deleted
    }

    @Test func resizeARectangleByItsCornerThenUndo() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        app.draw(.shape, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 80, y: 80))
        TestSessions.drag(app.session, on: 1, from: CGPoint(x: 40, y: 60), to: CGPoint(x: 40, y: 60))
        TestSessions.drag(app.session, on: 1, from: CGPoint(x: 80, y: 80), to: CGPoint(x: 160, y: 140))
        app.overlay.send(.copy)

        let image = try app.copied()
        #expect(app.pixel(image, atPoint: 160, 100).isClose(to: .red))  // new right edge
        #expect(app.pixel(image, atPoint: 100, 140).isClose(to: .red))  // new bottom edge
        #expect(app.pixel(image, atPoint: 80, 60) == original(atPoint: 80, 60))  // old right edge clear
    }

    @Test func undoAResizeRestoresTheOriginalSize() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        app.draw(.shape, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 80, y: 80))
        TestSessions.drag(app.session, on: 1, from: CGPoint(x: 40, y: 60), to: CGPoint(x: 40, y: 60))
        TestSessions.drag(app.session, on: 1, from: CGPoint(x: 80, y: 80), to: CGPoint(x: 160, y: 140))
        app.overlay.send(.undo)
        app.overlay.send(.copy)

        let image = try app.copied()
        #expect(app.pixel(image, atPoint: 80, 60).isClose(to: .red))
        #expect(app.pixel(image, atPoint: 160, 100) == original(atPoint: 160, 100))
    }

    /// Drawing turns the tool off and selects the shape, so it can be restyled and moved at once.
    @Test func drawThenThickenAndMoveRightAway() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        app.draw(.shape, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 100, y: 100))
        app.session.setLineWidth(16)
        TestSessions.drag(app.session, on: 1, from: CGPoint(x: 55, y: 40), to: CGPoint(x: 85, y: 60))  // top edge, between handles
        app.overlay.send(.copy)

        let image = try app.copied()
        #expect(app.pixel(image, atPoint: 70, 100).isClose(to: .red))  // moved left edge, 30 pt right and 20 down
        #expect(app.pixel(image, atPoint: 64, 110).isClose(to: .red))  // 6 pt into a 16 pt stroke
        #expect(app.pixel(image, atPoint: 40, 70) == original(atPoint: 40, 70))  // old left edge clear
    }

    @Test func freehandPenAndMarkerThenSave() async throws {
        let app = launchApp()
        defer { try? FileManager.default.removeItem(at: app.saveDirectory) }
        await app.captureAndSelect()

        app.session.setColor(.green)
        app.draw(.pen, from: CGPoint(x: 40, y: 40), through: [CGPoint(x: 80, y: 60), CGPoint(x: 120, y: 40)], to: CGPoint(x: 160, y: 60))
        // Pick the tool first: a color change with the pen still selected would recolor the pen.
        app.session.toggleTool(.marker)
        app.session.setColor(.yellow)
        app.draw(.marker, from: CGPoint(x: 40, y: 150), to: CGPoint(x: 200, y: 150))
        app.overlay.send(.save)

        let file = app.saveDirectory.appendingPathComponent("QuickSnip 2026-10-07 at 11.49.40.png")
        let data = try Data(contentsOf: file)
        let image = try #require(TestImages.decodePNG(data))
        #expect(image.width == 400)
        #expect(app.pixel(image, atPoint: 80, 60).isClose(to: .green))
        let marked = app.pixel(image, atPoint: 100, 150)
        #expect(marked != original(atPoint: 100, 150))
        #expect(!marked.isClose(to: .yellow, tolerance: 10))  // translucent, not solid
    }

    @Test func adjustSelectionAfterAnnotatingKeepsAnnotations() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        app.draw(.shape, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 100, y: 100))
        // Resize from the bottom-right handle with the tool still active.
        TestSessions.drag(app.session, on: 1, from: CGPoint(x: 220, y: 170), to: CGPoint(x: 240, y: 180))
        app.overlay.send(.copy)

        let image = try app.copied()
        #expect(image.width == 440)
        #expect(image.height == 320)
        #expect(app.pixel(image, atPoint: 50, 75).isClose(to: .red))
    }

    @Test func cancelDiscardsAnnotations() async throws {
        let app = launchApp()
        await app.captureAndSelect()
        app.draw(.shape, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 100, y: 100))

        app.overlay.send(.cancel)
        #expect(app.pasteboard.written.isEmpty)

        await app.coordinator.captureRequested()
        #expect(app.session.document.annotations.isEmpty)
    }

    @Test func circleAroundABugWithShiftIsCopiedAndOvalIsRemembered() async throws {
        let store = TestDefaults()
        let app = launchApp(settings: AppSettings(defaults: store.defaults, defaultDirectory: TestImages.temporaryDirectory()))
        await app.captureAndSelect()

        app.session.toggleTool(.shape)
        app.session.setShape(.oval)
        app.session.mouseDown(on: 1, at: CGPoint(x: 40, y: 40))
        app.session.mouseDragged(on: 1, to: CGPoint(x: 140, y: 90), modifiers: DrawModifiers(isConstrained: true))
        app.session.mouseUp(on: 1, at: CGPoint(x: 140, y: 90), modifiers: DrawModifiers(isConstrained: true))
        app.overlay.send(.copy)

        // A 100 pt circle at (40, 40): its bottom reaches y 140, past where the drag ended.
        let image = try app.copied()
        #expect(app.pixel(image, atPoint: 90, 140).isClose(to: .red))
        #expect(app.pixel(image, atPoint: 40, 90).isClose(to: .red))
        #expect(app.pixel(image, atPoint: 42, 42) == original(atPoint: 42, 42))  // outside the curve
        #expect(app.pixel(image, atPoint: 90, 90) == original(atPoint: 90, 90))

        await app.captureAndSelect()
        #expect(app.session.style.shape == .oval)
    }

    @Test func doubleArrowIsCopiedWithAHeadAtEachEnd() async throws {
        let app = launchApp()
        await app.captureAndSelect()

        app.session.toggleTool(.arrow)
        app.session.setArrowHeads(.both)
        app.draw(.arrow, from: CGPoint(x: 40, y: 100), to: CGPoint(x: 200, y: 100))
        app.overlay.send(.copy)

        // 4 pt line: a head's 16 pt sides spread to ±7 pt, the shaft only ±2 pt.
        let image = try app.copied()
        #expect(app.pixel(image, atPoint: 50, 96).isClose(to: .red))
        #expect(app.pixel(image, atPoint: 190, 96).isClose(to: .red))
        #expect(app.pixel(image, atPoint: 120, 96) == original(atPoint: 120, 96))
    }
}
