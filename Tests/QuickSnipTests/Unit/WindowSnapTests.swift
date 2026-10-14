import CoreGraphics
import Testing

@testable import QuickSnip

struct WindowSnapTests {
    /// Primary display 1000 × 600 at the AppKit origin.
    private let primary = CGRect(x: 0, y: 0, width: 1000, height: 600)
    private let ownProcessID: pid_t = 99

    private func snapWindows(_ windows: [WindowInfo], on display: CGRect) -> [SnapWindow] {
        WindowSnap.localFrames(of: windows, on: display, primaryScreenHeight: primary.height, excluding: ownProcessID)
    }

    private func frames(_ windows: [WindowInfo], on display: CGRect) -> [CGRect] {
        snapWindows(windows, on: display).map(\.visibleFrame)
    }

    @Test func primaryDisplayFramesAreAlreadyLocal() {
        let window = WindowInfo(frame: CGRect(x: 100, y: 50, width: 400, height: 300))
        #expect(frames([window], on: primary) == [CGRect(x: 100, y: 50, width: 400, height: 300)])
    }

    @Test func keepsFrontToBackOrder() {
        let front = WindowInfo(frame: CGRect(x: 100, y: 100, width: 200, height: 200))
        let back = WindowInfo(frame: CGRect(x: 0, y: 0, width: 800, height: 500))
        #expect(frames([front, back], on: primary) == [front.frame, back.frame])
    }

    /// External display to the right and lower: AppKit y grows up, Core Graphics y grows down.
    @Test func displayBelowAndRightOfThePrimary() {
        let external = CGRect(x: 1000, y: -400, width: 800, height: 700)  // CG top edge: 600 - 300 = 300
        let window = WindowInfo(frame: CGRect(x: 1100, y: 350, width: 300, height: 200))
        #expect(frames([window], on: external) == [CGRect(x: 100, y: 50, width: 300, height: 200)])
    }

    @Test func displayAboveThePrimary() {
        let above = CGRect(x: 0, y: 600, width: 1000, height: 600)  // CG top edge: -600
        let window = WindowInfo(frame: CGRect(x: 10, y: -590, width: 200, height: 100))
        #expect(frames([window], on: above) == [CGRect(x: 10, y: 10, width: 200, height: 100)])
    }

    @Test func windowsSpanningDisplaysAreClippedButKeepTheirFullFrame() {
        let window = WindowInfo(id: 7, frame: CGRect(x: 900, y: 500, width: 300, height: 300))
        #expect(
            snapWindows([window], on: primary) == [
                SnapWindow(id: 7, frame: window.frame, visibleFrame: CGRect(x: 900, y: 500, width: 100, height: 100))
            ])
    }

    @Test(arguments: [
        WindowInfo(frame: CGRect(x: 2000, y: 0, width: 300, height: 300)),  // another display
        WindowInfo(frame: CGRect(x: 0, y: 0, width: 300, height: 25), layer: 24),  // menu bar
        WindowInfo(frame: CGRect(x: 0, y: 0, width: 300, height: 300), alpha: 0),  // invisible
        WindowInfo(frame: CGRect(x: 0, y: 0, width: 300, height: 300), ownerProcessID: 99),  // QuickSnip
        WindowInfo(frame: CGRect(x: 0, y: 0, width: 300, height: 10)),  // a sliver
    ])
    func skipsWindowsThatCantBeSnapped(window: WindowInfo) {
        #expect(frames([window], on: primary).isEmpty)
    }

    @Test func primaryHeightComesFromTheDisplayAtTheOrigin() {
        let external = CGRect(x: -800, y: 0, width: 800, height: 900)
        #expect(WindowSnap.primaryScreenHeight(of: [external, primary]) == 600)
    }

    @Test func primaryHeightFallsBackToTheFirstDisplay() {
        #expect(WindowSnap.primaryScreenHeight(of: [CGRect(x: 5, y: 5, width: 10, height: 70)]) == 70)
        #expect(WindowSnap.primaryScreenHeight(of: []) == 0)
    }
}
