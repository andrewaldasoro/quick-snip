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

    private let activation: any AppActivating
    private(set) var panels: [OverlayPanel] = []
    private var activationObserver: (any NSObjectProtocol)?

    init(activation: any AppActivating = SystemAppActivation()) {
        self.activation = activation
    }

    func present(_ session: CaptureSession, onCommand: @escaping @MainActor (OverlayCommand) -> Void) {
        dismiss()
        panels = session.displays.map { makePanel(for: $0, session: session, onCommand: onCommand) }
        session.onChange = { [weak self] in
            for view in self?.overlayViews ?? [] { view.sessionDidChange() }
        }
        session.onRequestTextEntry = { [weak self] displayID, point in
            self?.overlayViews.first { $0.display.displayID == displayID }?.beginTextEntry(at: point)
        }

        // Only the active app may change the cursor, so the crosshair needs QuickSnip active.
        activation.activate()
        for panel in panels { panel.orderFrontRegardless() }

        let mouse = NSEvent.mouseLocation
        let keyPanel = panels.first { $0.frame.contains(mouse) } ?? panels.first
        keyPanel?.makeKey()
        keyPanel?.makeFirstResponder(keyPanel?.contentView)
        refreshCursor()
        // Activation completes asynchronously; set the cursor again once it has.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Posted on the main queue (see `queue:` above).
            MainActor.assumeIsolated { self?.refreshCursor() }
        }
    }

    /// Sets the cursor for the overlay under the mouse.
    func refreshCursor() {
        let mouse = NSEvent.mouseLocation
        overlayViews.first { $0.window?.frame.contains(mouse) ?? false }?.refreshCursor()
    }

    var overlayViews: [SelectionOverlayView] {
        panels.compactMap { $0.contentView as? SelectionOverlayView }
    }

    func dismiss() {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        for panel in panels { panel.orderOut(nil) }
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
        panel.acceptsMouseMovedEvents = true

        let view = SelectionOverlayView(display: display, session: session, onCommand: onCommand)
        panel.contentView = view
        panel.initialFirstResponder = view
        panel.setFrame(display.frame, display: false)
        return panel
    }
}
