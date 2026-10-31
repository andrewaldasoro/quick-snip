import AppKit

/// The style of what's being drawn or is selected, in its own small glass panel next to the
/// toolbar, on one row: a Color dropdown | a Width dropdown for shapes, arrows and strokes, then
/// rectangle/oval buttons for shapes or arrowhead buttons for arrows; or Font and Size dropdowns
/// and the alignment buttons for text.
final class StylePanel: NSView {
    struct Actions {
        var openList: @MainActor (StyleList) -> Void
        var selectAlignment: @MainActor (TextAlignment) -> Void
        var selectShape: @MainActor (ShapeKind) -> Void = { _ in }
        var selectArrowHeads: @MainActor (ArrowHeads) -> Void = { _ in }
    }

    static let spacing: CGFloat = 2
    static let groupSpacing: CGFloat = 6
    static let insets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
    /// The font dropdown shows its title in the font itself, at this size.
    static let fontTitleSize: CGFloat = 13

    private let actions: Actions
    private(set) var options: StyleOptions?
    private(set) var buttons: [StyleList: DropdownButton] = [:]
    private(set) var alignmentButtons: [TextAlignment: NSButton] = [:]
    private(set) var shapeButtons: [ShapeKind: NSButton] = [:]
    private(set) var arrowHeadButtons: [ArrowHeads: NSButton] = [:]
    private let row = NSStackView()
    /// Everything after the color dropdown; rebuilt when switching between shapes and text.
    private var styleViews: [NSView] = []

    init(actions: Actions) {
        self.actions = actions
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.toolbar)
        setAccessibilityLabel("Style")

        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = Self.spacing
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(makeDropdown(.color, label: "Color"))

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(row)
        let background = AnnotationToolbar.makeBackground(content: content)
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
            row.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.insets.left),
            row.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.insets.right),
            row.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.insets.top),
            row.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Self.insets.bottom),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Clicks no control takes (a disabled button, the padding) stay here; passed on, they'd
    /// reach the capture behind and start moving or redrawing the selection.
    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}

    /// Shows `color` and the controls for `options`, marking `openList`'s dropdown as open.
    func update(options: StyleOptions, color: AnnotationColor, openList: StyleList?) {
        if !Self.isSameKind(options, self.options) { rebuild(for: options) }
        self.options = options
        buttons[.color]?.leadingImage = DropdownListPanel.colorSwatch(color)
        buttons[.color]?.setAccessibilityValue(color.displayName)
        if let width = options.lineWidth {
            buttons[.lineWidth]?.title = StyleValue.lineWidth(width).title
        }
        switch options {
        case .stroke:
            break
        case .shape(let shape, _):
            Self.markOn(shape, in: shapeButtons)
        case .arrow(let heads, _):
            Self.markOn(heads, in: arrowHeadButtons)
        case .text(let font, let size, let alignment):
            buttons[.font]?.title = font.displayName
            buttons[.font]?.titleFontOverride = font.font(size: Self.fontTitleSize)
            buttons[.fontSize]?.title = StyleValue.fontSize(size).title
            Self.markOn(alignment, in: alignmentButtons)
        }
        markOpen(openList)
        setFrameSize(fittingSize)
    }

    func markOpen(_ openList: StyleList?) {
        for (list, button) in buttons {
            button.isOpen = list == openList
        }
    }

    private static func markOn<Value: Hashable>(_ value: Value, in buttons: [Value: NSButton]) {
        for (candidate, button) in buttons {
            button.state = candidate == value ? .on : .off
        }
    }

    private static func isSameKind(_ a: StyleOptions, _ b: StyleOptions?) -> Bool {
        switch (a, b) {
        case (.stroke, .stroke?), (.shape, .shape?), (.arrow, .arrow?), (.text, .text?): true
        default: false
        }
    }

    private func rebuild(for options: StyleOptions) {
        for view in styleViews {
            row.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        buttons = buttons.filter { $0.key == .color }
        alignmentButtons = [:]
        shapeButtons = [:]
        arrowHeadButtons = [:]
        styleViews = [ToolbarDivider()]
        switch options {
        case .stroke:
            styleViews += makeLineWidthViews()
        case .shape:
            styleViews += makeLineWidthViews() + [ToolbarDivider()]
            styleViews += ShapeKind.allCases.map { shape in
                shapeButtons[shape] = makeToggle(symbol: shape.symbol, label: shape.displayName, action: #selector(shapeClicked(_:)))
                return shapeButtons[shape] ?? NSView()
            }
        case .arrow:
            styleViews += makeLineWidthViews() + [ToolbarDivider()]
            styleViews += ArrowHeads.allCases.map { heads in
                arrowHeadButtons[heads] = makeToggle(
                    symbol: heads.symbol, label: heads.displayName, action: #selector(arrowHeadsClicked(_:)))
                return arrowHeadButtons[heads] ?? NSView()
            }
        case .text:
            styleViews += [makeDropdown(.font, label: "Font"), makeDropdown(.fontSize, label: "Text size"), ToolbarDivider()]
            styleViews += TextAlignment.allCases.map(makeAlignmentButton)
        }
        for view in styleViews {
            row.addArrangedSubview(view)
        }
        // Hairlines get a little room on each side, like the toolbar's groups.
        for (index, view) in row.arrangedSubviews.enumerated() where view is ToolbarDivider && index > 0 {
            row.setCustomSpacing(Self.groupSpacing, after: row.arrangedSubviews[index - 1])
            row.setCustomSpacing(Self.groupSpacing, after: view)
        }
    }

    private func makeDropdown(_ list: StyleList, label: String) -> DropdownButton {
        let button = DropdownButton(title: "", label: label)
        button.target = self
        button.action = #selector(dropdownClicked(_:))
        buttons[list] = button
        return button
    }

    private func makeLineWidthViews() -> [NSView] {
        let icon = NSImageView(image: NSImage(systemSymbolName: "lineweight", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .secondaryLabelColor
        return [icon, makeDropdown(.lineWidth, label: "Line width")]
    }

    private func makeToggle(symbol: String, label: String, action: Selector) -> NSButton {
        let button = ToolbarButton(symbol: symbol, label: label, toggles: true)
        button.target = self
        button.action = action
        return button
    }

    private func makeAlignmentButton(_ alignment: TextAlignment) -> NSView {
        let button = ToolbarButton(symbol: alignment.symbol, label: alignment.displayName, toggles: true)
        button.target = self
        button.action = #selector(alignmentClicked(_:))
        alignmentButtons[alignment] = button
        return button
    }

    @objc private func dropdownClicked(_ sender: DropdownButton) {
        guard let list = buttons.first(where: { $0.value === sender })?.key else { return }
        actions.openList(list)
    }

    @objc private func alignmentClicked(_ sender: NSButton) {
        guard let alignment = alignmentButtons.first(where: { $0.value === sender })?.key else { return }
        actions.selectAlignment(alignment)
    }

    @objc private func shapeClicked(_ sender: NSButton) {
        guard let shape = shapeButtons.first(where: { $0.value === sender })?.key else { return }
        actions.selectShape(shape)
    }

    @objc private func arrowHeadsClicked(_ sender: NSButton) {
        guard let heads = arrowHeadButtons.first(where: { $0.value === sender })?.key else { return }
        actions.selectArrowHeads(heads)
    }
}
