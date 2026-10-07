import AppKit
import Testing
@testable import QuickSnip

@MainActor
@Suite(.serialized)
struct OverlayWindowManagerTests {
    private let displays = [
        TestImages.display(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 80), scale: 2),
        TestImages.display(id: 2, frame: CGRect(x: 100, y: 0, width: 120, height: 90), scale: 1),
    ]

    @Test func presentsOnePanelPerDisplay() {
        let manager = OverlayWindowManager()
        manager.present(CaptureSession(displays: displays)) { _ in }
        defer { manager.dismiss() }

        #expect(manager.panels.count == 2)
        #expect(manager.panels.map(\.frame) == displays.map(\.frame))
    }

    @Test func panelsFloatAboveEverythingOnAllSpaces() throws {
        let manager = OverlayWindowManager()
        manager.present(CaptureSession(displays: displays)) { _ in }
        defer { manager.dismiss() }

        let panel = try #require(manager.panels.first)
        #expect(panel.level == OverlayWindowManager.windowLevel)
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(panel.canBecomeKey)
        #expect(panel.styleMask.contains(.borderless))
    }

    @Test func eachPanelHostsItsDisplaysOverlay() {
        let manager = OverlayWindowManager()
        manager.present(CaptureSession(displays: displays)) { _ in }
        defer { manager.dismiss() }

        let ids = manager.panels.compactMap { ($0.contentView as? SelectionOverlayView)?.display.displayID }
        #expect(ids == [1, 2])
    }

    @Test func dismissRemovesAllPanels() {
        let manager = OverlayWindowManager()
        manager.present(CaptureSession(displays: displays)) { _ in }
        manager.dismiss()
        #expect(manager.panels.isEmpty)
    }

    @Test func presentingAgainReplacesPanels() {
        let manager = OverlayWindowManager()
        manager.present(CaptureSession(displays: displays)) { _ in }
        manager.present(CaptureSession(displays: [displays[0]])) { _ in }
        defer { manager.dismiss() }
        #expect(manager.panels.count == 1)
    }

    @Test func selectionChangesRedrawAllPanels() {
        let manager = OverlayWindowManager()
        let session = CaptureSession(displays: displays)
        manager.present(session) { _ in }
        defer { manager.dismiss() }

        manager.panels.forEach { $0.contentView?.needsDisplay = false }
        session.mouseDown(on: 1, at: CGPoint(x: 5, y: 5))

        #expect(manager.panels.allSatisfy { $0.contentView?.needsDisplay == true })
    }
}
