import AppKit

@MainActor
protocol RecognizedTextPresenting: AnyObject {
    func show(_ text: String)
}

/// After Read Text: a window with what was read, where the user can fix a misread word
/// and copy all of it, part of it, or nothing.
@MainActor
final class RecognizedTextWindowController: RecognizedTextPresenting {
    static let title = "Recognized Text"

    let model: RecognizedTextModel
    private let activation: any AppActivating
    private var window: NSWindow?

    init(clipboard: any ClipboardWriting, activation: any AppActivating = SystemAppActivation()) {
        model = RecognizedTextModel(clipboard: clipboard)
        self.activation = activation
    }

    func show(_ text: String) {
        model.text = text
        let window = window ?? .hosting(RecognizedTextView(model: model), title: Self.title)
        self.window = window
        activation.activate()
        window.bringToFront()
    }
}
