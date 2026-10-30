import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct FontListPanelTests {
    private final class Recorder {
        var picked: [String] = []
        var closed = 0
    }

    private let catalog = FontCatalog(families: ["Avenir", "Helvetica", "Helvetica Neue", "Menlo"])

    private func make(current: TextFont = .system) -> (FontListPanel, Recorder) {
        let recorder = Recorder()
        let panel = FontListPanel(
            catalog: catalog, current: current, onPick: { recorder.picked.append($0) }, onClose: { recorder.closed += 1 })
        return (panel, recorder)
    }

    private func command(_ panel: FontListPanel, _ selector: Selector) -> Bool {
        panel.control(panel.searchField, textView: NSTextView(), doCommandBy: selector)
    }

    @Test func listsEveryFamily() {
        let (panel, _) = make()
        #expect(panel.families == catalog.families)
        #expect(panel.table.numberOfRows == 4)
        #expect(panel.frame.size == FontListPanel.size)
    }

    @Test func currentFamilyIsSelected() {
        let (panel, _) = make(current: .family("Menlo"))
        #expect(panel.table.selectedRow == 3)
    }

    @Test func searchFiltersAndSelectsTheFirstMatch() {
        let (panel, _) = make()
        panel.searchField.stringValue = "helv"
        panel.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        #expect(panel.families == ["Helvetica", "Helvetica Neue"])
        #expect(panel.table.selectedRow == 0)
    }

    @Test func returnPicksTheSelectedFamily() {
        let (panel, recorder) = make()
        panel.search("helv")
        #expect(command(panel, #selector(NSResponder.moveDown(_:))))
        #expect(command(panel, #selector(NSResponder.insertNewline(_:))))
        #expect(recorder.picked == ["Helvetica Neue"])
    }

    @Test func arrowsStayWithinTheList() {
        let (panel, _) = make()
        panel.search("helv")
        _ = command(panel, #selector(NSResponder.moveUp(_:)))
        #expect(panel.table.selectedRow == 0)
        panel.moveSelection(by: 10)
        #expect(panel.table.selectedRow == 1)
    }

    @Test func returnWithNoMatchesPicksNothing() {
        let (panel, recorder) = make()
        panel.search("zzz")
        panel.pickSelected()
        panel.moveSelection(by: 1)
        #expect(recorder.picked.isEmpty)
    }

    @Test func escapeCloses() {
        let (panel, recorder) = make()
        #expect(command(panel, #selector(NSResponder.cancelOperation(_:))))
        panel.cancelOperation(nil)
        #expect(recorder.closed == 2)
    }

    @Test func otherCommandsAreLeftToTheSearchField() {
        let (panel, _) = make()
        #expect(!command(panel, #selector(NSResponder.moveLeft(_:))))
    }

    @Test func rowsShowEachFamilyInItsOwnFont() throws {
        let (panel, _) = make()
        let row = try #require(panel.tableView(panel.table, viewFor: nil, row: 1) as? NSTextField)
        #expect(row.stringValue == "Helvetica")
        #expect(row.font?.familyName == "Helvetica")
    }
}
