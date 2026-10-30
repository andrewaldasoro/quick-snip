import AppKit

/// The style of what's being drawn or is selected, in its own small glass panel next to the
/// toolbar: a Width dropdown for shapes, lines and strokes; Font and Size dropdowns for text.
final class StylePanel: NSView {
    static let spacing: CGFloat = 4
    static let insets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
    /// The font dropdown shows its title in the font itself, at this size.
    static let fontTitleSize: CGFloat = 13

    private let onOpenList: @MainActor (StyleList, NSView) -> Void
    private(set) var options: StyleOptions?
    private(set) var buttons: [StyleList: DropdownButton] = [:]
    private let row = NSStackView()

    init(onOpenList: @escaping @MainActor (StyleList, NSView) -> Void) {
        self.onOpenList = onOpenList
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.toolbar)
        setAccessibilityLabel("Style")

        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = Self.spacing
        row.translatesAutoresizingMaskIntoConstraints = false
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

    /// Shows the dropdowns for `options`, marking `openList`'s as open.
    func update(options: StyleOptions, openList: StyleList?) {
        if !Self.isSameKind(options, self.options) { rebuild(for: options) }
        self.options = options
        switch options {
        case .stroke(let width):
            buttons[.lineWidth]?.title = StyleValue.lineWidth(width).title
        case .text(let font, let size):
            buttons[.font]?.title = font.displayName
            buttons[.font]?.titleFontOverride = font.font(size: Self.fontTitleSize)
            buttons[.fontSize]?.title = StyleValue.fontSize(size).title
        }
        markOpen(openList)
        setFrameSize(fittingSize)
    }

    func markOpen(_ openList: StyleList?) {
        for (list, button) in buttons {
            button.isOpen = list == openList
        }
    }

    private static func isSameKind(_ a: StyleOptions, _ b: StyleOptions?) -> Bool {
        switch (a, b) {
        case (.stroke, .stroke?), (.text, .text?): true
        default: false
        }
    }

    private func rebuild(for options: StyleOptions) {
        for view in row.arrangedSubviews {
            row.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        buttons = [:]
        let lists: [(StyleList, String)] =
            switch options {
            case .stroke: [(.lineWidth, "Line width")]
            case .text: [(.font, "Font"), (.fontSize, "Text size")]
            }
        if case .stroke = options {
            let icon = NSImageView(image: NSImage(systemSymbolName: "lineweight", accessibilityDescription: nil) ?? NSImage())
            icon.contentTintColor = .secondaryLabelColor
            row.addArrangedSubview(icon)
        }
        for (list, label) in lists {
            let button = DropdownButton(title: "", label: label)
            button.target = self
            button.action = #selector(buttonClicked(_:))
            buttons[list] = button
            row.addArrangedSubview(button)
        }
    }

    @objc private func buttonClicked(_ sender: DropdownButton) {
        guard let list = buttons.first(where: { $0.value === sender })?.key else { return }
        onOpenList(list, sender)
    }
}
