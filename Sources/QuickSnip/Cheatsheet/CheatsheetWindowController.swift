import AppKit

@MainActor
protocol CheatsheetPresenting: AnyObject {
    func show()
}

/// The Keyboard Shortcuts window, opened from the menu bar menu.
@MainActor
final class CheatsheetWindowController: CheatsheetPresenting {
    static let title = "Keyboard Shortcuts"

    private let hotkey: CaptureHotkey
    private let activation: any AppActivating
    private var window: NSWindow?

    init(hotkey: CaptureHotkey, activation: any AppActivating = SystemAppActivation()) {
        self.hotkey = hotkey
        self.activation = activation
    }

    func show() {
        // The hotkey may have changed in Settings since the window was last open.
        hotkey.refresh()
        let window = window ?? .hosting(CheatsheetView(hotkey: hotkey), title: Self.title)
        self.window = window
        activation.activate()
        window.bringToFront()
    }
}
