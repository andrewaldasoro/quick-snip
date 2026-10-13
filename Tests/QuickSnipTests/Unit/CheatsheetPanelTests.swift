import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct CheatsheetPanelTests {
    private typealias Section = ShortcutCheatsheet.Section

    private func section(_ title: String, rows: Int) -> Section {
        Section(title: title, entries: (0..<rows).map { .init(action: "\(title) \($0)", keys: ["\($0)"]) })
    }

    @Test func sectionsGoToTheShortestColumn() {
        let sections = [section("A", rows: 7), section("B", rows: 7), section("C", rows: 8), section("D", rows: 2)]
        let columns = CheatsheetPanel.columns(of: sections, count: 3)
        #expect(columns.map { $0.map(\.title) } == [["A", "D"], ["B"], ["C"]])
    }

    @Test func emptyColumnsAreDropped() {
        let columns = CheatsheetPanel.columns(of: [section("A", rows: 1)], count: 3)
        #expect(columns.count == 1)
    }

    @Test func noteAddsARow() {
        var withNote = section("A", rows: 2)
        withNote.note = "Note"
        #expect(CheatsheetPanel.height(of: withNote) == CheatsheetPanel.height(of: section("A", rows: 2)) + CheatsheetPanel.rowHeight)
    }

    @Test func columnHeightIncludesSpacingBetweenSections() {
        let column = [section("A", rows: 1), section("B", rows: 1)]
        let expected = CheatsheetPanel.height(of: column[0]) * 2 + CheatsheetPanel.sectionSpacing
        #expect(CheatsheetPanel.height(of: column) == expected)
    }

    @Test func overlayCheatsheetFitsASmallDisplay() {
        let size = CheatsheetPanel(cheatsheet: .overlay).size
        #expect(size.width <= 1024)
        #expect(size.height <= 640)
        #expect(size.width > 0 && size.height > 0)
    }

    @Test func panelIsCenteredOnTheDisplay() {
        let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = CheatsheetPanel(cheatsheet: .overlay).frame(in: bounds)
        #expect(abs(frame.midX - bounds.midX) <= 1)
        #expect(abs(frame.midY - bounds.midY) <= 1)
    }
}
