import Observation

/// The text from the last Read Text, shown for review. Nothing is copied until the user
/// chooses: Copy All, or select part and ⌘C.
@MainActor
@Observable
final class RecognizedTextModel {
    var text = "" {
        didSet { isCopied = false }
    }
    /// The current text is on the clipboard (cleared by any edit).
    private(set) var isCopied = false
    @ObservationIgnored private let clipboard: any ClipboardWriting

    init(clipboard: any ClipboardWriting) {
        self.clipboard = clipboard
    }

    func copyAll() {
        clipboard.writeText(text)
        isCopied = true
    }
}
