import AppKit
import SwiftUI
import Testing

@testable import QuickSnip

@MainActor
struct HostingWindowTests {
    /// Regression: windows built from `NSHostingController` opened as a bare title bar.
    @Test func windowIsSizedToTheView() {
        let window = NSWindow.hosting(Color.clear.frame(width: 320, height: 180), title: "Test")
        #expect(window.contentLayoutRect.size == CGSize(width: 320, height: 180))
    }

    @Test func windowIsTitledClosableAndReusable() {
        let window = NSWindow.hosting(Text("Hi"), title: "Test")
        #expect(window.title == "Test")
        #expect(window.styleMask.contains(.titled))
        #expect(window.styleMask.contains(.closable))
        #expect(!window.styleMask.contains(.resizable))
        #expect(!window.isReleasedWhenClosed)
    }
}

@MainActor
struct BringToFrontTests {
    private final class SpyWindow: NSWindow {
        private(set) var raisedRegardless = 0
        override func orderFrontRegardless() {
            raisedRegardless += 1
            super.orderFrontRegardless()
        }
    }

    /// Regression: Settings opened behind other apps' windows. `makeKeyAndOrderFront`
    /// only orders within the app while it's inactive, which a single test process can't
    /// show, so check that the window is raised regardless of activation.
    @Test func raisesEvenWhileTheAppIsInactive() {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let window = SpyWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        defer { window.close() }

        window.bringToFront()

        #expect(window.raisedRegardless == 1)
        #expect(window.isVisible)
    }

    @Test func endsAboveTheAppsOtherWindows() throws {
        _ = NSApplication.shared
        let target = NSWindow.hosting(Text("Target"), title: "Target")
        let other = NSWindow.hosting(Text("Other"), title: "Other")
        defer {
            target.close()
            other.close()
        }
        other.orderFrontRegardless()

        target.bringToFront()

        let order = NSApp.orderedWindows
        #expect(try #require(order.firstIndex(of: target)) < #require(order.firstIndex(of: other)))
    }
}
