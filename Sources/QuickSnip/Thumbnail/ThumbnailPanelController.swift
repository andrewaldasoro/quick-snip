import AppKit

@MainActor
protocol ThumbnailPresenting: AnyObject {
    /// `pointSize` is the image's size in points; `fileURL` is set when it was saved.
    func show(_ image: CGImage, pointSize: CGSize, fileURL: URL?)
    func dismiss()
}

/// Floating preview after copy/save. Click opens the saved file; it disappears on its own.
@MainActor
final class ThumbnailPanelController: ThumbnailPresenting {
    static let displayDuration: Duration = .seconds(5)

    private(set) var panel: NSPanel?
    private(set) var fileURL: URL?
    private var dismissTask: Task<Void, Never>?
    private let urlOpener: any URLOpening
    private let displayDuration: Duration

    init(urlOpener: any URLOpening = WorkspaceURLOpener(), displayDuration: Duration = ThumbnailPanelController.displayDuration) {
        self.urlOpener = urlOpener
        self.displayDuration = displayDuration
    }

    func show(_ image: CGImage, pointSize: CGSize, fileURL: URL?) {
        dismiss()
        guard let screen = NSScreen.main else { return }

        let size = ThumbnailLayout.size(for: pointSize)
        let panel = NSPanel(
            contentRect: ThumbnailLayout.frame(size: size, visibleFrame: screen.visibleFrame),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false

        let view = ThumbnailView(image: NSImage(cgImage: image, size: size), canOpen: fileURL != nil)
        view.onClick = { [weak self] in self?.open() }
        view.onClose = { [weak self] in self?.dismiss() }
        panel.contentView = view
        panel.orderFrontRegardless()

        self.panel = panel
        self.fileURL = fileURL
        dismissTask = Task { [weak self, displayDuration] in
            // Throws only on cancellation, which the guard below handles.
            try? await Task.sleep(for: displayDuration)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
        panel = nil
        fileURL = nil
    }

    func open() {
        guard let fileURL else { return }
        urlOpener.open(fileURL)
        dismiss()
    }
}

final class ThumbnailView: NSView {
    var onClick: (@MainActor () -> Void)?
    var onClose: (@MainActor () -> Void)?
    private let canOpen: Bool

    init(image: NSImage, canOpen: Bool) {
        self.canOpen = canOpen
        super.init(frame: CGRect(origin: .zero, size: image.size))
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor

        let imageView = NSImageView(frame: bounds)
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)

        let close = NSButton(
            image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close") ?? NSImage(),
            target: self,
            action: #selector(closeClicked)
        )
        close.isBordered = false
        close.frame = CGRect(x: 4, y: bounds.height - 22, width: 18, height: 18)
        close.autoresizingMask = [.minYMargin]
        close.setAccessibilityLabel("Close thumbnail")
        addSubview(close)

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(canOpen ? "Screenshot thumbnail, click to open" : "Screenshot thumbnail")
        toolTip = canOpen ? "Click to open" : "Copied to clipboard"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func mouseUp(with event: NSEvent) {
        onClick?()
    }

    @objc private func closeClicked() {
        onClose?()
    }
}
