import AppKit

/// Every installed font family, searchable, opened from the toolbar's More Fonts button. A view
/// inside the overlay rather than a popover or the system font panel: those open below the
/// overlay's window level. Click or Return picks a family; Esc closes.
final class FontListPanel: NSView, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    static let size = CGSize(width: 240, height: 300)
    static let rowHeight: CGFloat = 26
    static let sampleSize: CGFloat = 14
    static let padding: CGFloat = 8

    private let catalog: FontCatalog
    private let onPick: @MainActor (String) -> Void
    private let onClose: @MainActor () -> Void
    private(set) var families: [String]
    let searchField = NSSearchField()
    let table = NSTableView()

    init(
        catalog: FontCatalog, current: TextFont, onPick: @escaping @MainActor (String) -> Void,
        onClose: @escaping @MainActor () -> Void
    ) {
        self.catalog = catalog
        self.onPick = onPick
        self.onClose = onClose
        families = catalog.families
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Fonts")
        build()
        if case .family(let name) = current, let row = families.firstIndex(of: name) {
            table.selectRowIndexes([row], byExtendingSelection: false)
            table.scrollRowToVisible(row)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func build() {
        searchField.placeholderString = "Search Fonts"
        searchField.delegate = self
        searchField.focusRingType = .none
        searchField.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("family"))
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = Self.rowHeight
        table.backgroundColor = .clear
        table.style = .plain
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(rowClicked(_:))
        table.setAccessibilityLabel("Font families")

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(searchField)
        content.addSubview(scroll)
        let background = AnnotationToolbar.makeBackground(content: content)
        background.frame = bounds
        background.autoresizingMask = [.width, .height]
        addSubview(background)
        let padding = Self.padding
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            content.topAnchor.constraint(equalTo: background.topAnchor),
            content.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: padding),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -padding),
            searchField.topAnchor.constraint(equalTo: content.topAnchor, constant: padding),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: padding),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -padding),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: padding),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -padding),
        ])
    }

    // MARK: Search

    func search(_ query: String) {
        families = catalog.matching(query)
        table.reloadData()
        if !families.isEmpty {
            table.selectRowIndexes([0], byExtendingSelection: false)
            table.scrollRowToVisible(0)
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        search(searchField.stringValue)
    }

    /// Up and Down move through the list while typing; Return picks; Esc closes.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)): moveSelection(by: -1)
        case #selector(NSResponder.moveDown(_:)): moveSelection(by: 1)
        case #selector(NSResponder.insertNewline(_:)): pickSelected()
        case #selector(NSResponder.cancelOperation(_:)): onClose()
        default: return false
        }
        return true
    }

    func moveSelection(by offset: Int) {
        guard !families.isEmpty else { return }
        let row = min(max(table.selectedRow + offset, 0), families.count - 1)
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    func pickSelected() {
        let row = table.selectedRow >= 0 ? table.selectedRow : 0
        guard families.indices.contains(row) else { return }
        onPick(families[row])
    }

    /// Esc from the list itself (after clicking into it) ends here through the responder chain.
    override func cancelOperation(_ sender: Any?) {
        onClose()
    }

    /// Clicks on the panel's own padding stay here; passed on, the overlay would close it.
    override func mouseDown(with event: NSEvent) {}

    @objc private func rowClicked(_ sender: NSTableView) {
        guard families.indices.contains(sender.clickedRow) else { return }
        onPick(families[sender.clickedRow])
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        families.count
    }

    /// Each family is shown in its own typeface.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let family = families[row]
        let label = NSTextField(labelWithString: family)
        label.font = TextFont.family(family).font(size: Self.sampleSize)
        label.lineBreakMode = .byTruncatingTail
        label.setAccessibilityLabel(family)
        return label
    }
}
