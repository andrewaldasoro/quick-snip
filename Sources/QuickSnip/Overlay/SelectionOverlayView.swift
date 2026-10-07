import AppKit

/// Full-screen view for one display: frozen image, dimming outside the selection,
/// border, handles, and the pixel size label. Flipped, so local points match `CaptureSession`.
final class SelectionOverlayView: NSView {
    static let dimColor = NSColor.black.withAlphaComponent(0.45)
    static let borderColor = NSColor.white
    static let handleSize: CGFloat = 7

    let display: CapturedDisplay
    private let session: CaptureSession
    private let onCommand: @MainActor (OverlayCommand) -> Void
    private let frozenImage: NSImage

    init(display: CapturedDisplay, session: CaptureSession, onCommand: @escaping @MainActor (OverlayCommand) -> Void) {
        self.display = display
        self.session = session
        self.onCommand = onCommand
        frozenImage = NSImage(cgImage: display.image, size: display.frame.size)
        super.init(frame: display.localBounds)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        frozenImage.draw(
            in: bounds,
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.none.rawValue]
        )

        let selection = session.selection(on: display.displayID)

        let dim = NSBezierPath(rect: bounds)
        if let selection, !selection.isEmpty {
            dim.append(NSBezierPath(rect: selection))
            dim.windingRule = .evenOdd
        }
        Self.dimColor.setFill()
        dim.fill()

        guard let selection, !selection.isEmpty else { return }
        drawBorder(selection)
        drawHandles(selection)
        drawSizeLabel(selection)
    }

    private func drawBorder(_ selection: CGRect) {
        let border = NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        Self.borderColor.setStroke()
        border.stroke()
    }

    private func drawHandles(_ selection: CGRect) {
        let size = Self.handleSize
        for handle in SelectionHandle.allCases {
            let center = handle.point(in: selection)
            let rect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
            let path = NSBezierPath(rect: rect)
            Self.borderColor.setFill()
            path.fill()
            NSColor.darkGray.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func drawSizeLabel(_ selection: CGRect) {
        guard let pixelSize = session.selectionPixelSize(on: display.displayID) else { return }
        let text = NSAttributedString(
            string: SizeLabel.text(for: pixelSize),
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white,
            ]
        )
        let padding = CGSize(width: 6, height: 3)
        let textSize = text.size()
        let labelSize = CGSize(width: textSize.width + padding.width * 2, height: textSize.height + padding.height * 2)
        let origin = SizeLabel.origin(labelSize: labelSize, selection: selection, bounds: bounds)

        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: CGRect(origin: origin, size: labelSize), xRadius: 4, yRadius: 4).fill()
        text.draw(at: CGPoint(x: origin.x + padding.width, y: origin.y + padding.height))
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        session.mouseDown(on: display.displayID, at: localPoint(of: event))
    }

    override func mouseDragged(with event: NSEvent) {
        session.mouseDragged(on: display.displayID, to: localPoint(of: event))
    }

    override func mouseUp(with event: NSEvent) {
        session.mouseUp(on: display.displayID, at: localPoint(of: event))
    }

    private func localPoint(of event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if let command = OverlayKeyMap.command(for: event) {
            onCommand(command)
        } else {
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let command = OverlayKeyMap.command(for: event) {
            onCommand(command)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
