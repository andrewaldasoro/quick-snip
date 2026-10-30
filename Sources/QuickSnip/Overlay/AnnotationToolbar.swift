import AppKit

/// Floating toolbar anchored to the selection, styled like a built-in macOS toolbar:
/// a glass panel, borderless glyph buttons, an outlined Save and one prominent primary
/// action (Copy).
///
/// One row: cancel | tools | undo, redo | read text, save, Copy. Colors, line width, font,
/// size and alignment live in `StylePanel` next to it.
/// Every choice is an inline control: pop-up menus would open below the overlay's level.
final class AnnotationToolbar: NSView {
    struct Actions {
        var selectTool: @MainActor (AnnotationTool) -> Void
        var command: @MainActor (OverlayCommand) -> Void
    }

    static let commands: [OverlayCommand] = [.undo, .redo, .cancel, .readText, .save, .copy]
    static let buttonSize = NSSize(width: 28, height: 28)
    static let cornerRadius: CGFloat = 14
    static let insets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)

    private let actions: Actions
    private(set) var toolButtons: [AnnotationTool: NSButton] = [:]
    private(set) var commandButtons: [OverlayCommand: NSButton] = [:]

    init(actions: Actions) {
        self.actions = actions
        super.init(frame: .zero)

        let rows = makeRow()
        rows.translatesAutoresizingMaskIntoConstraints = false

        // Padding as required constraints: a `.leading` stack's own edgeInsets don't hold
        // on the trailing side, which left Copy touching the panel edge.
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.setAccessibilityElement(true)
        content.setAccessibilityRole(.toolbar)
        content.setAccessibilityLabel("Screenshot tools")
        content.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.insets.left),
            rows.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.insets.right),
            rows.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.insets.top),
            rows.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Self.insets.bottom),
        ])

        let background = Self.makeBackground(content: content)
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            content.topAnchor.constraint(equalTo: background.topAnchor),
            content.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        setFrameSize(fittingSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(tool: AnnotationTool?, canUndo: Bool, canRedo: Bool) {
        for (candidate, button) in toolButtons {
            button.state = candidate == tool ? .on : .off
        }
        commandButtons[.undo]?.isEnabled = canUndo
        commandButtons[.redo]?.isEnabled = canRedo
    }

    // MARK: Building

    /// Liquid Glass on macOS 26+, the HUD-style vibrancy material before that.
    static func makeBackground(content: NSView) -> NSView {
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.contentView = content
            return glass
        }
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.maskImage = roundedMask(radius: cornerRadius)
        effect.addSubview(content)
        return effect
    }

    private func makeRow() -> NSStackView {
        let cancel = makeCommandButton(.cancel)

        let tools = AnnotationTool.allCases.enumerated().map { index, tool in
            let button = ToolbarButton(symbol: Self.symbol(for: tool), label: Self.label(for: tool), toggles: true)
            button.target = self
            button.action = #selector(toolClicked(_:))
            button.tag = index
            toolButtons[tool] = button
            return button as NSView
        }

        let history = [makeCommandButton(.undo), makeCommandButton(.redo)]
        let output = [makeCommandButton(.readText), makeCommandButton(.save), makeCommandButton(.copy)]

        return row(groups: [[cancel], tools, history, output])
    }

    private func makeCommandButton(_ command: OverlayCommand) -> NSButton {
        let button: NSButton
        if command == .copy {
            button = PrimaryToolbarButton(title: "Copy", symbol: Self.symbol(for: command), label: Self.label(for: command))
        } else if command == .save {
            button = OutlineToolbarButton(symbol: Self.symbol(for: command), label: Self.label(for: command))
        } else {
            button = ToolbarButton(symbol: Self.symbol(for: command), label: Self.label(for: command), toggles: false)
        }
        button.target = self
        button.action = #selector(commandClicked(_:))
        button.tag = Self.commands.firstIndex(of: command) ?? 0
        commandButtons[command] = button
        return button
    }

    private static let groupSpacing: CGFloat = 4

    /// Groups of items, each tight together, with hairline dividers between groups.
    private func row(groups: [[NSView]]) -> NSStackView {
        var views: [NSView] = []
        for (index, group) in groups.enumerated() {
            if index > 0 { views.append(ToolbarDivider()) }
            views.append(contentsOf: group)
        }
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 2
        for view in views where view is ToolbarDivider {
            row.setCustomSpacing(Self.groupSpacing, after: view)
            if let before = views.firstIndex(of: view).map({ views[$0 - 1] }) {
                row.setCustomSpacing(Self.groupSpacing, after: before)
            }
        }
        return row
    }

    // MARK: Actions

    @objc private func toolClicked(_ sender: NSButton) {
        actions.selectTool(AnnotationTool.allCases[sender.tag])
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
        case .text: "character.textbox"
        case .pixelate: "checkerboard.rectangle"
        }
    }

    static func label(for tool: AnnotationTool) -> String {
        withShortcut(tool.displayName, for: .selectTool(tool))
    }

    static func label(for color: AnnotationColor) -> String {
        withShortcut(color.displayName, for: .selectColor(color))
    }

    /// "Undo (⌘Z)": the name plus the first key bound to the command in `OverlayKeyMap`.
    private static func withShortcut(_ name: String, for command: OverlayCommand) -> String {
        guard let key = OverlayKeyMap.keys(for: command).first else { return name }
        return "\(name) (\(key))"
    }

    static func symbol(for command: OverlayCommand) -> String {
        switch command {
        case .undo: "arrow.uturn.backward"
        case .redo: "arrow.uturn.forward"
        case .cancel: "xmark"
        case .save: "square.and.arrow.down"
        case .copy: "doc.on.doc"
        case .readText: "text.viewfinder"
        case .deleteAnnotation: "trash"
        case .toggleCheatsheet: "questionmark.circle"
        case .selectTool(let tool): symbol(for: tool)
        case .selectColor: "paintpalette"
        }
    }

    static func label(for command: OverlayCommand) -> String {
        switch command {
        case .undo: withShortcut("Undo", for: command)
        case .redo: withShortcut("Redo", for: command)
        case .cancel: withShortcut("Cancel", for: command)
        case .save: withShortcut("Save", for: command)
        case .copy: withShortcut("Copy", for: command)
        case .readText: withShortcut("Read Text", for: command)
        case .deleteAnnotation: withShortcut("Delete", for: command)
        case .toggleCheatsheet: withShortcut("Keyboard Shortcuts", for: command)
        case .selectTool(let tool): label(for: tool)
        case .selectColor(let color): label(for: color)
        }
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

// MARK: - Controls

/// Borderless glyph button like a macOS toolbar item: a soft rounded highlight on hover
/// and press, and a solid accent fill with a white glyph while toggled on.
final class ToolbarButton: NSButton {
    /// An accent glyph on a faint accent wash was hard to read over the glass, so "on" and the
    /// primary action use a solid accent fill with a white or black foreground, whichever
    /// contrasts more with the user's accent color.
    /// How much darker the accent fill gets on hover and press.
    static let hoverDarkening: CGFloat = 0.12
    static let pressDarkening: CGFloat = 0.25

    /// The solid accent fill, darkened while hovered or pressed.
    static func accentFill(isHighlighted: Bool, isHovered: Bool) -> NSColor {
        let accent = NSColor.controlAccentColor
        let darkening = isHighlighted ? pressDarkening : isHovered ? hoverDarkening : 0
        return accent.blended(withFraction: darkening, of: .black) ?? accent
    }

    static var accentForeground: NSColor {
        ColorContrast.readableForeground(on: accentFill(isHighlighted: false, isHovered: false))
    }

    private var isHovered = false { didSet { needsDisplay = true } }

    convenience init(symbol: String, label: String, toggles: Bool) {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image =
            NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(config) ?? NSImage()
        self.init(image: image, label: label, toggles: toggles)
    }

    init(image: NSImage, label: String, toggles: Bool) {
        super.init(frame: NSRect(origin: .zero, size: AnnotationToolbar.buttonSize))
        self.image = image
        imagePosition = .imageOnly
        imageScaling = .scaleNone
        isBordered = false
        setButtonType(toggles ? .pushOnPushOff : .momentaryChange)
        if let cell = cell as? NSButtonCell {
            // All state feedback is drawn by `draw(_:)`.
            cell.highlightsBy = []
            cell.showsStateBy = []
        }
        toolTip = label
        setAccessibilityLabel(label)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: AnnotationToolbar.buttonSize.width),
            heightAnchor.constraint(equalToConstant: AnnotationToolbar.buttonSize.height),
        ])
        refreshTint()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Symbol images carry their own alignment insets; keep every button a plain square.
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets() }
    override var intrinsicContentSize: NSSize { AnnotationToolbar.buttonSize }

    override var state: NSControl.StateValue {
        didSet { refreshTint() }
    }

    override var isEnabled: Bool {
        didSet { refreshTint() }
    }

    override var isHighlighted: Bool {
        didSet { needsDisplay = true }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self
            ))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func draw(_ dirtyRect: NSRect) {
        if let fill = backgroundColor {
            fill.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
        }
        super.draw(dirtyRect)
    }

    private var backgroundColor: NSColor? {
        guard isEnabled else { return nil }
        if state == .on { return Self.accentFill(isHighlighted: isHighlighted, isHovered: isHovered) }
        if isHighlighted { return .labelColor.withAlphaComponent(0.14) }
        if isHovered { return .labelColor.withAlphaComponent(0.08) }
        return nil
    }

    private func refreshTint() {
        contentTintColor = state == .on && isEnabled ? Self.accentForeground : nil
        needsDisplay = true
    }
}

/// The primary action: white icon plus title on a solid accent fill, like a toggled-on
/// tool, so it stands out and stays readable. Same height and corner radius as
/// `ToolbarButton`, so it lines up with the glyphs (a push bezel doesn't).
final class PrimaryToolbarButton: NSButton {
    static let horizontalPadding: CGFloat = 8
    static let iconSpacing: CGFloat = 5

    private let icon: NSImage
    private let titleFont = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
    private var isHovered = false { didSet { needsDisplay = true } }

    init(title: String, symbol: String, label: String) {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        icon =
            NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) ?? NSImage()
        super.init(frame: .zero)
        self.title = title
        image = icon
        isBordered = false
        setButtonType(.momentaryChange)
        toolTip = label
        setAccessibilityLabel(label)
        translatesAutoresizingMaskIntoConstraints = false
        setFrameSize(intrinsicContentSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets() }

    override var intrinsicContentSize: NSSize {
        let content = icon.size.width + Self.iconSpacing + ceil(titleSize.width)
        return NSSize(width: ceil(content) + Self.horizontalPadding * 2, height: AnnotationToolbar.buttonSize.height)
    }

    override var isHighlighted: Bool {
        didSet { needsDisplay = true }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self
            ))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    private var titleSize: NSSize {
        (title as NSString).size(withAttributes: [.font: titleFont])
    }

    override func draw(_ dirtyRect: NSRect) {
        let foreground = ToolbarButton.accentForeground
        ToolbarButton.accentFill(isHighlighted: isHighlighted, isHovered: isHovered).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()

        let iconRect = NSRect(
            x: Self.horizontalPadding,
            y: (bounds.height - icon.size.height) / 2,
            width: icon.size.width,
            height: icon.size.height
        )
        Self.tinted(icon, foreground).draw(in: iconRect)

        let text = NSAttributedString(string: title, attributes: [.font: titleFont, .foregroundColor: foreground])
        text.draw(at: NSPoint(x: iconRect.maxX + Self.iconSpacing, y: (bounds.height - titleSize.height) / 2))
    }

    private static func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}

/// Short vertical hairline between toolbar groups.
final class ToolbarDivider: NSView {
    static let width: CGFloat = 1

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: 18))
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.width),
            heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        bounds.fill()
    }
}
