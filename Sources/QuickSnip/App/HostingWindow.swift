import AppKit
import SwiftUI

extension NSWindow {
    /// A titled, closable window showing a SwiftUI view, sized to that view.
    ///
    /// `NSHostingController` reports its preferred size only after a layout pass, so a window
    /// built from it opens as a bare 1×0 title bar unless it's sized from the content up front.
    static func hosting(_ view: some View, title: String) -> NSWindow {
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(hosting.view.fittingSize)
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    /// Puts the window in front of every app's windows and makes it key.
    ///
    /// `orderFrontRegardless()` raises it even while QuickSnip isn't active yet; focus
    /// itself comes from activating the app (see `SystemAppActivation`).
    func bringToFront() {
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }
}
