import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct RecognizedTextModelTests {
    @Test func copyAllCopiesTheEditedText() {
        let clipboard = SpyPasteboard()
        let model = RecognizedTextModel(clipboard: clipboard)
        model.text = "Invoice 2O48"

        model.text = "Invoice 2048"
        model.copyAll()

        #expect(clipboard.writtenText == ["Invoice 2048"])
    }

    @Test func copyAllSaysItsCopiedUntilTheNextEdit() {
        let model = RecognizedTextModel(clipboard: SpyPasteboard())
        model.text = "Invoice"
        #expect(!model.isCopied)

        model.copyAll()
        #expect(model.isCopied)

        model.text = "Invoice 2048"
        #expect(!model.isCopied)
    }

    @Test func nothingIsCopiedUntilAsked() {
        let clipboard = SpyPasteboard()
        let model = RecognizedTextModel(clipboard: clipboard)
        model.text = "Invoice 2048"
        #expect(clipboard.writtenText.isEmpty)
    }
}

@MainActor
struct RecognizedTextWindowControllerTests {
    private func openedWindow(by action: () -> Void) throws -> NSWindow {
        _ = NSApplication.shared  // `NSApp` is nil until something creates the app.
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        action()
        return try #require(NSApp.windows.first { !before.contains(ObjectIdentifier($0)) })
    }

    @Test func showsTheTextInOneReusedWindow() throws {
        let controller = RecognizedTextWindowController(clipboard: SpyPasteboard(), activation: SpyAppActivation())
        let window = try openedWindow {
            controller.show("first")
            controller.show("second")
        }
        defer { window.close() }

        #expect(controller.model.text == "second")
        #expect(window.title == "Recognized Text")
        #expect(NSApp.windows.filter { $0.title == RecognizedTextWindowController.title && $0.isVisible }.count == 1)
        #expect(window.contentLayoutRect.size == RecognizedTextView.size)
    }

    /// Like every QuickSnip window: without forced activation it opens behind the frontmost app.
    @Test func showingActivatesTheApp() throws {
        let activation = SpyAppActivation()
        let controller = RecognizedTextWindowController(clipboard: SpyPasteboard(), activation: activation)
        let window = try openedWindow { controller.show("text") }
        defer { window.close() }
        #expect(activation.activateCount == 1)
    }
}
