import AppKit

/// Floating toolbar anchored to the selection: tools, colors, stroke width, undo/redo,
/// and cancel/save/copy. Colors and widths are inline segments: pop-up menus would open
/// below the overlay's window level.
final class AnnotationToolbar: NSVisualEffectView {
    struct Actions {
        var selectTool: @MainActor (AnnotationTool) -> Void
        var selectColor: @MainActor (AnnotationColor) -> Void
        var selectWidth: @MainActor (StrokeWidth) -> Void
        var command: @MainActor (OverlayCommand) -> Void
    }

    static let commands: [OverlayCommand] = [.undo, .redo, .cancel, .save, .copy]
    static let buttonWidth: CGFloat = 28

    private let actions: Actions
    private(set) var toolButtons: [AnnotationTool: NSButton] = [:]
    private(set) var commandButtons: [OverlayCommand: NSButton] = [:]
    let colorControl = NSSegmentedControl()
    let widthControl = NSSegmentedControl()

    init(actions: Actions) {
        self.actions = actions
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        let stack = NSStackView(views: [row(makeToolAndCommandItems()), row(makeStyleItems())])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 5, left: 6, bottom: 5, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setFrameSize(fittingSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    func update(tool: AnnotationTool?, style: AnnotationStyle, canUndo: Bool, canRedo: Bool) {
        for (candidate, button) in toolButtons {
            button.state = candidate == tool ? .on : .off
        }
        colorControl.selectedSegment = AnnotationColor.allCases.firstIndex(of: style.color) ?? 0
        widthControl.selectedSegment = StrokeWidth.allCases.firstIndex(of: style.width) ?? 0
        commandButtons[.undo]?.isEnabled = canUndo
        commandButtons[.redo]?.isEnabled = canRedo
    }

    // MARK: Building

    private func row(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.spacing = 2
        return row
    }

    /// Top row: tools, then undo/redo, then cancel/save/copy.
    private func makeToolAndCommandItems() -> [NSView] {
        var items: [NSView] = []

        for (index, tool) in AnnotationTool.allCases.enumerated() {
            let button = makeButton(symbol: Self.symbol(for: tool), label: Self.label(for: tool), action: #selector(toolClicked(_:)))
            button.setButtonType(.pushOnPushOff)
            button.tag = index
            toolButtons[tool] = button
            items.append(button)
        }

        for (index, command) in Self.commands.enumerated() {
            if command == .undo || command == .cancel { items.append(separator()) }
            let button = makeButton(symbol: Self.symbol(for: command), label: Self.label(for: command), action: #selector(commandClicked(_:)))
            button.tag = index
            commandButtons[command] = button
            items.append(button)
        }
        return items
    }

    /// Bottom row: colors and stroke width.
    private func makeStyleItems() -> [NSView] {
        var items: [NSView] = []

        colorControl.segmentCount = AnnotationColor.allCases.count
        colorControl.trackingMode = .selectOne
                for (index, color) in AnnotationColor.allCases.enumerated() {
            colorControl.setImage(Self.swatch(for: color), forSegment: index)
            colorControl.setWidth(18, forSegment: index)
            colorControl.setToolTip(color.rawValue.capitalized, forSegment: index)
        }
        colorControl.target = self
        colorControl.action = #selector(colorChanged(_:))
        colorControl.setAccessibilityLabel("Color")
        items.append(colorControl)

        widthControl.segmentCount = StrokeWidth.allCases.count
        widthControl.trackingMode = .selectOne
        for (index, width) in StrokeWidth.allCases.enumerated() {
            widthControl.setImage(Self.widthImage(for: width), forSegment: index)
            widthControl.setWidth(22, forSegment: index)
            widthControl.setToolTip(width.rawValue.capitalized, forSegment: index)
        }
        widthControl.target = self
        widthControl.action = #selector(widthChanged(_:))
        widthControl.setAccessibilityLabel("Stroke width")
        items.append(separator())
        items.append(widthControl)
        return items
    }

    private func makeButton(symbol: String, label: String, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label) ?? NSImage()
        let button = NSButton(image: image, target: self, action: action)
        button.bezelStyle = .accessoryBarAction
        button.imagePosition = .imageOnly
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: Self.buttonWidth).isActive = true
        button.toolTip = label
        button.setAccessibilityLabel(label)
        return button
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 1).isActive = true
        box.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return box
    }

    // MARK: Actions

    @objc private func toolClicked(_ sender: NSButton) {
        actions.selectTool(AnnotationTool.allCases[sender.tag])
    }

    @objc private func colorChanged(_ sender: NSSegmentedControl) {
        guard AnnotationColor.allCases.indices.contains(sender.selectedSegment) else { return }
        actions.selectColor(AnnotationColor.allCases[sender.selectedSegment])
    }

    @objc private func widthChanged(_ sender: NSSegmentedControl) {
        guard StrokeWidth.allCases.indices.contains(sender.selectedSegment) else { return }
        actions.selectWidth(StrokeWidth.allCases[sender.selectedSegment])
    }

    @objc private func commandClicked(_ sender: NSButton) {
        actions.command(Self.commands[sender.tag])
    }

    // MARK: Appearance

    static func symbol(for tool: AnnotationTool) -> String {
        switch tool {
        case .rectangle: "rectangle"
        case .arrow: "arrow.up.right"
        case .line: "line.diagonal"
        case .pen: "pencil.tip"
        case .marker: "highlighter"
        case .text: "textformat"
        case .pixelate: "checkerboard.rectangle"
        }
    }

    static func label(for tool: AnnotationTool) -> String {
        tool == .pixelate ? "Pixelate" : tool.rawValue.capitalized
    }

    static func symbol(for command: OverlayCommand) -> String {
        switch command {
        case .undo: "arrow.uturn.backward"
        case .redo: "arrow.uturn.forward"
        case .cancel: "xmark"
        case .save: "square.and.arrow.down"
        case .copy: "doc.on.doc"
        case .deleteAnnotation: "trash"
        }
    }

    static func label(for command: OverlayCommand) -> String {
        switch command {
        case .undo: "Undo (⌘Z)"
        case .redo: "Redo (⌘⇧Z)"
        case .cancel: "Cancel (Esc)"
        case .save: "Save (⌘S)"
        case .copy: "Copy (⌘C)"
        case .deleteAnnotation: "Delete"
        }
    }

    private static func swatch(for color: AnnotationColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            color.nsColor.setFill()
            circle.fill()
            NSColor.gray.setStroke()
            circle.lineWidth = 0.5
            circle.stroke()
            return true
        }
    }

    private static func widthImage(for width: StrokeWidth) -> NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 12), flipped: false) { rect in
            let line = NSBezierPath()
            line.move(to: NSPoint(x: 2, y: rect.midY))
            line.line(to: NSPoint(x: rect.maxX - 2, y: rect.midY))
            line.lineWidth = width.lineWidth / 1.5
            line.lineCapStyle = .round
            NSColor.black.setStroke()
            line.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
