import CoreGraphics

/// Turns the window server's list into the frames a click can snap to on one display.
enum WindowSnap {
    /// Ordinary app windows. Higher layers are the menu bar, Dock and overlays; lower ones the desktop.
    static let appWindowLayer = 0
    /// Skips the invisible slivers some apps keep on screen.
    static let minimumSize: CGFloat = 20

    /// The windows on one display, in its local points (top-left origin), front to back.
    /// - Parameters:
    ///   - windows: front to back, as `CGWindowListCopyWindowInfo` returns them.
    ///   - displayFrame: the display in AppKit global coordinates (bottom-left origin).
    ///   - primaryScreenHeight: height of the display at the AppKit origin, where both coordinate systems meet.
    static func localFrames(
        of windows: [WindowInfo], on displayFrame: CGRect, primaryScreenHeight: CGFloat, excluding ownProcessID: pid_t
    ) -> [SnapWindow] {
        // Core Graphics y grows down from the primary display's top edge; AppKit y grows up from its bottom.
        let displayTop = primaryScreenHeight - displayFrame.maxY
        let bounds = CGRect(origin: .zero, size: displayFrame.size)
        return windows.compactMap { window in
            guard window.layer == appWindowLayer, window.alpha > 0, window.ownerProcessID != ownProcessID else { return nil }
            let local = window.frame.offsetBy(dx: -displayFrame.minX, dy: -displayTop)
            let visible = local.intersection(bounds)
            guard !visible.isNull, visible.width >= minimumSize, visible.height >= minimumSize else { return nil }
            return SnapWindow(id: window.id, frame: local, visibleFrame: visible)
        }
    }

    /// The screen at the AppKit origin carries the menu bar and anchors Core Graphics coordinates.
    static func primaryScreenHeight(of frames: [CGRect]) -> CGFloat {
        (frames.first { $0.origin == .zero } ?? frames.first)?.height ?? 0
    }
}
