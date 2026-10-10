import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct OnboardingWindowControllerTests {
    private func makeController(activation: SpyAppActivation = SpyAppActivation()) -> OnboardingWindowController {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let permission = ScreenRecordingPermission(access: FakeScreenCaptureAccess(granted: false), urlOpener: SpyURLOpener())
        return OnboardingWindowController(permission: permission, activation: activation)
    }

    private func newWindows(since before: Set<ObjectIdentifier>) -> [NSWindow] {
        NSApp.windows.filter { !before.contains(ObjectIdentifier($0)) }
    }

    @Test func showOpensOneWelcomeWindowAndReusesIt() throws {
        let controller = makeController()
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        controller.show()
        controller.show()
        let opened = newWindows(since: before)
        #expect(opened.count == 1)
        let window = try #require(opened.first)
        #expect(window.title == "Welcome to QuickSnip")
        #expect(window.contentLayoutRect.height >= 100)  // not a bare title bar
        #expect(window.isVisible)
        controller.close()
        #expect(!window.isVisible)
    }

    @Test func reopensAfterClose() throws {
        let controller = makeController()
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        controller.show()
        controller.close()
        controller.show()
        let window = try #require(newWindows(since: before).first)
        #expect(window.isVisible)
        controller.close()
    }

    @Test func showingActivatesTheApp() {
        let activation = SpyAppActivation()
        let controller = makeController(activation: activation)
        controller.show()
        defer { controller.close() }
        #expect(activation.activateCount == 1)
    }
}
