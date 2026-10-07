import AppKit

/// Borderless panel that can take key focus (for Esc / ⌘C / ⌘S).
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Shows one overlay panel per captured display, above everything, on every Space.
@MainActor
final class OverlayWindowManager: OverlayPresenting {
    static let windowLevel = NSWindow.Level.screenSaver

    private(set) var panels: [OverlayPanel] = []

    func present(_ session: CaptureSession, onCommand: @escaping @MainActor (OverlayCommand) -> Void) {
        dismiss()
        panels = session.displays.map { makePanel(for: $0, session: session, onCommand: onCommand) }
        session.onChange = { [weak self] in
            self?.panels.forEach { $0.contentView?.needsDisplay = true }
        }

        NSApp.activate()
        panels.forEach { $0.orderFrontRegardless() }

        let mouse = NSEvent.mouseLocation
        let keyPanel = panels.first { $0.frame.contains(mouse) } ?? panels.first
        keyPanel?.makeKey()
        keyPanel?.makeFirstResponder(keyPanel?.contentView)
    }

    func dismiss() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }

    private func makePanel(
        for display: CapturedDisplay,
        session: CaptureSession,
        onCommand: @escaping @MainActor (OverlayCommand) -> Void
    ) -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: display.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = Self.windowLevel
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none

        let view = SelectionOverlayView(display: display, session: session, onCommand: onCommand)
        panel.contentView = view
        panel.initialFirstResponder = view
        panel.setFrame(display.frame, display: false)
        return panel
    }
}
