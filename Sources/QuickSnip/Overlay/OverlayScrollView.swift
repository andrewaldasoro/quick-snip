import AppKit

/// A scroll view for lists inside the capture overlay: always the thin overlay scroller, which
/// shows only while scrolling, and none at all when everything fits. With "Show scroll bars:
/// Always" (or a mouse plugged in) macOS would otherwise give it a wide legacy scroller.
final class OverlayScrollView: NSScrollView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        drawsBackground = false
        super.scrollerStyle = .overlay
        verticalScroller?.controlSize = .small
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// AppKit resets the style to the system preference when it changes; keep it overlay.
    override var scrollerStyle: NSScroller.Style {
        get { .overlay }
        set { super.scrollerStyle = .overlay }
    }
}
