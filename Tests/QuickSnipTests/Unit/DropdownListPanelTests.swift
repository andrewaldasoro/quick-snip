import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct DropdownListPanelTests {
    private final class Recorder {
        var picked: [StyleValue] = []
        var closed = 0
    }

    private let fonts: [StyleValue] = [.font(.system), .font(.serif), .font(.family("Helvetica")), .font(.family("Helvetica Neue"))]

    private func make(values: [StyleValue]? = nil, current: StyleValue? = nil, isSearchable: Bool = true) -> (DropdownListPanel, Recorder) {
        let recorder = Recorder()
        let panel = DropdownListPanel(
            values: values ?? fonts, current: current, isSearchable: isSearchable,
            onPick: { recorder.picked.append($0) }, onClose: { recorder.closed += 1 })
        return (panel, recorder)
    }

    @Test func showsEveryValueAndSelectsTheCurrentOne() {
        let (panel, _) = make(current: .font(.family("Helvetica")))
        #expect(panel.table.numberOfRows == 4)
        #expect(panel.table.selectedRow == 2)
    }

    @Test func onlySearchableListsHaveASearchField() {
        #expect(make().0.searchField != nil)
        let (sizes, _) = make(values: [.fontSize(12), .fontSize(14)], isSearchable: false)
        #expect(sizes.searchField == nil)
        #expect(sizes.initialFirstResponder === sizes.table)
    }

    @Test func heightFollowsTheRowsUpToAMaximum() {
        let sizes = { (count: Int) in Array(repeating: StyleValue.fontSize(12), count: count) }
        let short = DropdownListPanel.size(for: sizes(3), isSearchable: false)
        let long = DropdownListPanel.size(for: sizes(200), isSearchable: false)
        #expect(short.height < long.height)
        #expect(long == DropdownListPanel.size(for: sizes(DropdownListPanel.maximumVisibleRows), isSearchable: false))
        #expect(DropdownListPanel.size(for: sizes(3), isSearchable: true).width == DropdownListPanel.searchableWidth)
    }

    @Test func searchFiltersByTitleAndSelectsTheFirstMatch() throws {
        let (panel, _) = make()
        let field = try #require(panel.searchField)
        field.stringValue = "helv"
        panel.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        #expect(panel.values == [.font(.family("Helvetica")), .font(.family("Helvetica Neue"))])
        #expect(panel.table.selectedRow == 0)
    }

    @Test func returnPicksTheSelectedValue() {
        let (panel, recorder) = make()
        panel.search("helv")
        #expect(panel.handle(#selector(NSResponder.moveDown(_:))))
        #expect(panel.handle(#selector(NSResponder.insertNewline(_:))))
        #expect(recorder.picked == [.font(.family("Helvetica Neue"))])
    }

    @Test func arrowsStayWithinTheList() {
        let (panel, _) = make()
        panel.handle(#selector(NSResponder.moveUp(_:)))
        #expect(panel.table.selectedRow == 0)
        panel.moveSelection(by: 10)
        #expect(panel.table.selectedRow == 3)
    }

    @Test func nothingToPickWithoutMatches() {
        let (panel, recorder) = make()
        panel.search("zzz")
        panel.pickSelected()
        panel.moveSelection(by: 1)
        #expect(recorder.picked.isEmpty)
    }

    @Test func escapeCloses() {
        let (panel, recorder) = make()
        #expect(panel.control(NSTextField(), textView: NSTextView(), doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        panel.cancelOperation(nil)
        panel.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        #expect(recorder.closed == 3)
    }

    @Test func otherCommandsAreLeftAlone() {
        let (panel, _) = make()
        #expect(!panel.handle(#selector(NSResponder.moveLeft(_:))))
    }

    @Test func fontsShowInTheirOwnTypeface() throws {
        let row = try #require(DropdownListPanel.rowContent(for: .font(.family("Helvetica"))) as? NSTextField)
        #expect(row.stringValue == "Helvetica")
        #expect(row.font?.familyName == "Helvetica")
    }

    @Test func widthsShowALineThatThick() throws {
        let row = try #require(DropdownListPanel.rowContent(for: .lineWidth(8)) as? NSStackView)
        #expect(row.arrangedSubviews.first is NSImageView)
        #expect((row.arrangedSubviews.last as? NSTextField)?.stringValue == "8 px")
        #expect(DropdownListPanel.linePreview(width: 8).accessibilityDescription == "8 px")
    }

    @Test func sizesShowTheirNumber() throws {
        let row = try #require(DropdownListPanel.rowContent(for: .fontSize(36)) as? NSTextField)
        #expect(row.stringValue == "36 px")
    }

    @Test func rowsComeFromTheValues() {
        let (panel, _) = make(values: [.fontSize(12), .fontSize(14)], isSearchable: false)
        #expect(panel.numberOfRows(in: panel.table) == 2)
        let row = panel.tableView(panel.table, viewFor: nil, row: 1)
        #expect((row?.subviews.first as? NSTextField)?.stringValue == "14 px")
    }

    @Test func colorsShowASwatchAndTheirName() throws {
        let row = try #require(DropdownListPanel.rowContent(for: .color(.blue)) as? NSStackView)
        #expect((row.arrangedSubviews.first as? NSImageView)?.image?.accessibilityDescription == "Blue")
        #expect((row.arrangedSubviews.last as? NSTextField)?.stringValue == "Blue")
    }

    /// Regression: the list showed a wide legacy scroller even when every row fit.
    @Test func scrollsWithAThinOverlayScrollerHiddenWhenNotNeeded() throws {
        let (panel, _) = make()
        let scroll = try #require(panel.scroll)
        #expect(scroll.scrollerStyle == .overlay)
        #expect(scroll.autohidesScrollers)
        #expect(!scroll.hasHorizontalScroller)
        #expect(scroll.verticalScroller?.controlSize == .small)

        scroll.scrollerStyle = .legacy  // what AppKit does when the system preference changes
        #expect(scroll.scrollerStyle == .overlay)
    }

    @Test func theColumnFillsTheList() {
        let (panel, _) = make()
        #expect(panel.table.columnAutoresizingStyle == .firstColumnOnlyAutoresizingStyle)
        #expect(panel.table.tableColumns.first?.resizingMask == .autoresizingMask)
    }

    @Test func rowsUseTheRoundedRowView() {
        let (panel, _) = make()
        #expect(panel.tableView(panel.table, rowViewForRow: 0) is DropdownRowView)
    }
}

@MainActor
struct DropdownListSizingTests {
    /// Regression: rows sat flush against the highlight's left edge.
    @Test func rowContentIsInsetFromBothEdges() throws {
        let row = DropdownListPanel.paddedRow(for: .fontSize(22))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 120, height: DropdownListPanel.rowHeight), styleMask: .borderless, backing: .buffered,
            defer: true)
        window.contentView = row
        row.layoutSubtreeIfNeeded()
        let content = try #require(row.subviews.first)
        // Auto Layout pins the alignment rect: where the text starts, not the label's frame.
        let placed = content.alignmentRect(forFrame: content.frame)
        #expect(placed.minX == DropdownListPanel.rowPadding)
        #expect(placed.maxX <= 120 - DropdownListPanel.rowPadding)
    }

    /// Regression: a fixed 150 pt list left lots of empty space after short values.
    @Test func listsAreAsWideAsTheirWidestRow() {
        let sizes = DropdownListPanel.size(for: TextSize.presets.map(StyleValue.fontSize), isSearchable: false)
        let colors = DropdownListPanel.size(for: AnnotationColor.allCases.map(StyleValue.color), isSearchable: false)
        let widest = DropdownListPanel.rowContent(for: .fontSize(96)).fittingSize.width
        #expect(
            sizes.width
                == max(DropdownListPanel.minimumWidth, ceil(widest) + (DropdownListPanel.rowPadding + DropdownListPanel.padding) * 2))
        #expect(sizes.width < 150)
        #expect(colors.width > sizes.width)  // swatch plus "Orange"
    }
}

@MainActor
struct DropdownRowViewTests {
    private func render(_ view: NSView) throws -> CGImage {
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        return try #require(rep.cgImage)
    }

    /// Regression: the selection was a square block inside the rounded dropdown.
    @Test func selectionHasRoundedCorners() throws {
        let row = DropdownRowView(frame: CGRect(x: 0, y: 0, width: 140, height: 26))
        row.isSelected = true
        row.drawSelection(in: row.bounds)
        let image = try render(row)
        let scale = image.width / 140
        let top = Int(DropdownRowView.verticalInset) * scale  // first row of the fill
        #expect(TestImages.pixel(image, x: 0, y: top).a == 0)  // its corner is rounded off
        #expect(TestImages.pixel(image, x: image.width / 2, y: image.height / 2).a == 255)  // middle filled
    }

    @Test func selectedRowTextAndLinesTakeTheReadableForeground() {
        let row = DropdownRowView(frame: CGRect(x: 0, y: 0, width: 140, height: 26))
        let label = NSTextField(labelWithString: "4 px")
        let line = NSImageView(image: DropdownListPanel.linePreview(width: 4))
        let swatch = NSImageView(image: DropdownListPanel.colorSwatch(.red))
        let stack = NSStackView(views: [line, swatch, label])
        row.addSubview(stack)

        row.isSelected = true
        #expect(label.textColor == ToolbarButton.accentForeground)
        #expect(line.contentTintColor == ToolbarButton.accentForeground)
        #expect(swatch.contentTintColor == nil)

        row.isSelected = false
        #expect(label.textColor == .labelColor)
    }
}
