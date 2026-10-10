import AppKit
import Testing

@testable import QuickSnip

struct ThumbnailLayoutTests {
    @Test(
        arguments: [
            (CGSize(width: 480, height: 320), CGSize(width: 240, height: 160)),  // scaled down, aspect kept
            (CGSize(width: 1000, height: 100), CGSize(width: 240, height: 40)),  // wide: min side
            (CGSize(width: 100, height: 50), CGSize(width: 100, height: 50)),  // never scaled up
            (CGSize(width: 10, height: 10), CGSize(width: 40, height: 40)),  // tiny: min side
            (CGSize.zero, CGSize(width: 40, height: 40)),
        ] as [(CGSize, CGSize)])
    func sizeFitsWithinMax(image: CGSize, expected: CGSize) {
        #expect(ThumbnailLayout.size(for: image) == expected)
    }

    @Test func frameSitsBottomRightOfVisibleFrame() {
        let visible = CGRect(x: 0, y: 80, width: 1440, height: 820)  // dock at bottom
        let frame = ThumbnailLayout.frame(size: CGSize(width: 200, height: 100), visibleFrame: visible)
        #expect(frame.maxX == 1440 - ThumbnailLayout.margin)
        #expect(frame.minY == 80 + ThumbnailLayout.margin)
    }

    @Test func frameWorksOnSecondaryScreens() {
        let visible = CGRect(x: -1920, y: 200, width: 1920, height: 1080)
        let frame = ThumbnailLayout.frame(size: CGSize(width: 200, height: 100), visibleFrame: visible)
        #expect(visible.contains(frame))
    }
}

@MainActor
@Suite(.serialized)
struct ThumbnailPanelControllerTests {
    private let image = TestImages.coordinateImage(width: 480, height: 320)
    private let file = URL(fileURLWithPath: "/tmp/QuickSnip test.png")

    @Test func showsFloatingPanelSizedToImage() throws {
        let controller = ThumbnailPanelController(urlOpener: SpyURLOpener())
        controller.show(image, pointSize: CGSize(width: 240, height: 160), fileURL: file)
        defer { controller.dismiss() }

        let panel = try #require(controller.panel)
        #expect(panel.isVisible)
        #expect(panel.level == .floating)
        #expect(panel.frame.size == CGSize(width: 240, height: 160))
        #expect(NSScreen.main.map { $0.visibleFrame.contains(panel.frame) } ?? true)
    }

    @Test func clickOpensSavedFileAndDismisses() throws {
        let opener = SpyURLOpener()
        let controller = ThumbnailPanelController(urlOpener: opener)
        controller.show(image, pointSize: CGSize(width: 240, height: 160), fileURL: file)

        let view = try #require(controller.panel?.contentView as? ThumbnailView)
        view.onClick?()

        #expect(opener.opened == [file])
        #expect(controller.panel == nil)
    }

    @Test func clickWithoutFileDoesNothing() {
        let opener = SpyURLOpener()
        let controller = ThumbnailPanelController(urlOpener: opener)
        controller.show(image, pointSize: CGSize(width: 240, height: 160), fileURL: nil)
        defer { controller.dismiss() }

        controller.open()
        #expect(opener.opened.isEmpty)
        #expect(controller.panel != nil)
    }

    @Test func closeButtonDismisses() throws {
        let controller = ThumbnailPanelController(urlOpener: SpyURLOpener())
        controller.show(image, pointSize: CGSize(width: 240, height: 160), fileURL: nil)
        try #require(controller.panel?.contentView as? ThumbnailView).onClose?()
        #expect(controller.panel == nil)
    }

    @Test func showingAgainReplacesThePanel() throws {
        let controller = ThumbnailPanelController(urlOpener: SpyURLOpener())
        controller.show(image, pointSize: CGSize(width: 240, height: 160), fileURL: nil)
        let first = try #require(controller.panel)
        controller.show(image, pointSize: CGSize(width: 240, height: 160), fileURL: file)
        defer { controller.dismiss() }

        #expect(!first.isVisible)
        #expect(controller.fileURL == file)
    }

    @Test func dismissesItselfAfterDuration() async throws {
        let controller = ThumbnailPanelController(urlOpener: SpyURLOpener(), displayDuration: .milliseconds(50))
        controller.show(image, pointSize: CGSize(width: 240, height: 160), fileURL: nil)
        #expect(controller.panel != nil)
        try await Task.sleep(for: .milliseconds(300))
        #expect(controller.panel == nil)
    }

    @Test func thumbnailIsAccessible() throws {
        let controller = ThumbnailPanelController(urlOpener: SpyURLOpener())
        controller.show(image, pointSize: CGSize(width: 240, height: 160), fileURL: file)
        defer { controller.dismiss() }
        let view = try #require(controller.panel?.contentView as? ThumbnailView)
        #expect(view.accessibilityLabel()?.contains("click to open") == true)
    }
}
