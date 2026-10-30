import AppKit

/// The open list of a style dropdown: line widths drawn as lines, fonts in their own typeface,
/// sizes as numbers. A view inside the overlay rather than a menu, popover or the system font
/// panel: those open below the overlay's window level. The font list adds a search field.
/// Click or Return picks; Up and Down move; Esc closes.
final class DropdownListPanel: NSView, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    static let rowHeight: CGFloat = 26
    static let sampleSize: CGFloat = 14
    static let padding: CGFloat = 6
    static let searchHeight: CGFloat = 28
    static let maximumVisibleRows = 10
    static let width: CGFloat = 150
    static let searchableWidth: CGFloat = 240
    static let linePreviewWidth: CGFloat = 40

    private let allValues: [StyleValue]
    private let onPick: @MainActor (StyleValue) -> Void
    private let onClose: @MainActor () -> Void
    private(set) var values: [StyleValue]
    /// Tall enough for its rows; the overlay may make it shorter to fit the display.
    let preferredSize: CGSize
    let searchField: NSSearchField?
    let table = NSTableView()

    init(
        values: [StyleValue], current: StyleValue?, isSearchable: Bool, onPick: @escaping @MainActor (StyleValue) -> Void,
        onClose: @escaping @MainActor () -> Void
    ) {
        allValues = values
        self.values = values
        self.onPick = onPick
        self.onClose = onClose
        searchField = isSearchable ? NSSearchField() : nil
        preferredSize = Self.size(rows: values.count, isSearchable: isSearchable)
        super.init(frame: CGRect(origin: .zero, size: preferredSize))
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(isSearchable ? "Fonts" : "Choices")
        build()
        if let current, let row = values.firstIndex(of: current) {
            select(row)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Tall enough for every row up to `maximumVisibleRows`; longer lists scroll.
    static func size(rows: Int, isSearchable: Bool) -> CGSize {
        let visible = CGFloat(min(max(rows, 1), maximumVisibleRows))
        let search = isSearchable ? searchHeight + padding : 0
        return CGSize(width: isSearchable ? searchableWidth : width, height: visible * rowHeight + search + padding * 2)
    }

    /// The field to focus when the list opens: the search field, or the list itself.
    var initialFirstResponder: NSView {
        searchField ?? table
    }

    private func build() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("value"))
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = Self.rowHeight
        table.backgroundColor = .clear
        table.style = .plain
        table.intercellSpacing = .zero
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(rowClicked(_:))
        table.setAccessibilityLabel(accessibilityLabel() ?? "Choices")

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        let background = AnnotationToolbar.makeBackground(content: content)
        background.frame = bounds
        background.autoresizingMask = [.width, .height]
        addSubview(background)

        let padding = Self.padding
        var constraints = [
            content.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            content.topAnchor.constraint(equalTo: background.topAnchor),
            content.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: padding),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -padding),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -padding),
        ]
        if let searchField {
            searchField.placeholderString = "Search Fonts"
            searchField.delegate = self
            searchField.focusRingType = .none
            searchField.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(searchField)
            constraints += [
                searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: padding),
                searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -padding),
                searchField.topAnchor.constraint(equalTo: content.topAnchor, constant: padding),
                scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: padding),
            ]
        } else {
            constraints.append(scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: padding))
        }
        NSLayoutConstraint.activate(constraints)
    }

    // MARK: Search and keys

    /// Keeps the values whose title contains `query`, ignoring case and accents.
    func search(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        values =
            trimmed.isEmpty
            ? allValues : allValues.filter { $0.title.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        table.reloadData()
        if !values.isEmpty { select(0) }
    }

    func controlTextDidChange(_ notification: Notification) {
        search(searchField?.stringValue ?? "")
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        handle(commandSelector)
    }

    /// Up and Down move through the list; Return picks; Esc closes.
    @discardableResult
    func handle(_ commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)): moveSelection(by: -1)
        case #selector(NSResponder.moveDown(_:)): moveSelection(by: 1)
        case #selector(NSResponder.insertNewline(_:)): pickSelected()
        case #selector(NSResponder.cancelOperation(_:)): onClose()
        default: return false
        }
        return true
    }

    /// The list itself (no search field) has focus: its keys come here.
    override func keyDown(with event: NSEvent) {
        interpretKeyEvents([event])
    }

    override func doCommand(by selector: Selector) {
        if !handle(selector) { super.doCommand(by: selector) }
    }

    func moveSelection(by offset: Int) {
        guard !values.isEmpty else { return }
        select(min(max(table.selectedRow + offset, 0), values.count - 1))
    }

    func pickSelected() {
        let row = table.selectedRow >= 0 ? table.selectedRow : 0
        guard values.indices.contains(row) else { return }
        onPick(values[row])
    }

    private func select(_ row: Int) {
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    /// Esc from the table (after clicking into it) ends here through the responder chain.
    override func cancelOperation(_ sender: Any?) {
        onClose()
    }

    /// Clicks on the panel's own padding stay here; passed on, the overlay would close it.
    override func mouseDown(with event: NSEvent) {}

    @objc private func rowClicked(_ sender: NSTableView) {
        guard values.indices.contains(sender.clickedRow) else { return }
        onPick(values[sender.clickedRow])
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        values.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        Self.rowView(for: values[row])
    }

    static let swatchDiameter: CGFloat = 14

    /// Fonts in their own typeface; colors and line widths with a swatch or a line that thick in front.
    static func rowView(for value: StyleValue) -> NSView {
        let label = NSTextField(labelWithString: value.title)
        label.lineBreakMode = .byTruncatingTail
        label.setAccessibilityLabel(value.title)
        switch value {
        case .color(let color):
            label.font = .systemFont(ofSize: NSFont.systemFontSize)
            let swatch = NSImageView(image: colorSwatch(color))
            swatch.setContentHuggingPriority(.required, for: .horizontal)
            let row = NSStackView(views: [swatch, label])
            row.spacing = 8
            return row
        case .font(let font):
            label.font = font.font(size: sampleSize)
            return label
        case .fontSize:
            label.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            return label
        case .lineWidth(let width):
            label.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            let line = NSImageView(image: linePreview(width: width))
            line.setContentHuggingPriority(.required, for: .horizontal)
            let row = NSStackView(views: [line, label])
            row.spacing = 8
            return row
        }
    }

    /// A filled circle of the color with a faint ring, so white and black show on any background.
    static func colorSwatch(_ color: AnnotationColor) -> NSImage {
        let size = NSSize(width: swatchDiameter, height: swatchDiameter)
        let image = NSImage(size: size, flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            color.nsColor.setFill()
            circle.fill()
            NSColor.labelColor.withAlphaComponent(0.3).setStroke()
            circle.lineWidth = 1
            circle.stroke()
            return true
        }
        image.accessibilityDescription = color.displayName
        return image
    }

    static func linePreview(width: CGFloat) -> NSImage {
        let height = LineWidth.presets.max() ?? width
        let image = NSImage(size: NSSize(width: linePreviewWidth, height: height), flipped: false) { rect in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: width / 2, y: rect.midY))
            path.line(to: NSPoint(x: rect.maxX - width / 2, y: rect.midY))
            path.lineWidth = width
            path.lineCapStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = StyleChoices.pixels(width)
        return image
    }
}
