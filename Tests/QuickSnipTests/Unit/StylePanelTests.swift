import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct StylePanelTests {
    private final class Recorder {
        var opened: [StyleList] = []
    }

    private func make() -> (StylePanel, Recorder) {
        let recorder = Recorder()
        return (StylePanel { list, _ in recorder.opened.append(list) }, recorder)
    }

    @Test func shapesGetAWidthDropdown() {
        let (panel, _) = make()
        panel.update(options: .stroke(lineWidth: 6), openList: nil)
        #expect(Set(panel.buttons.keys) == [.lineWidth])
        #expect(panel.buttons[.lineWidth]?.title == "6 px")
        #expect(panel.frame.width > 0)
    }

    @Test func textGetsFontAndSizeDropdowns() {
        let (panel, _) = make()
        panel.update(options: .text(font: .serif, size: 36), openList: nil)
        #expect(Set(panel.buttons.keys) == [.font, .fontSize])
        #expect(panel.buttons[.font]?.title == "Serif")
        #expect(panel.buttons[.font]?.titleFontOverride == TextFont.serif.font(size: StylePanel.fontTitleSize))
        #expect(panel.buttons[.fontSize]?.title == "36 px")
    }

    @Test func switchingKindRebuildsAndSameKindUpdatesInPlace() throws {
        let (panel, _) = make()
        panel.update(options: .text(font: .serif, size: 36), openList: nil)
        let font = try #require(panel.buttons[.font])
        panel.update(options: .text(font: .rounded, size: 12), openList: nil)
        #expect(panel.buttons[.font] === font)
        #expect(font.title == "Rounded")

        panel.update(options: .stroke(lineWidth: 2), openList: nil)
        #expect(panel.buttons[.font] == nil)
    }

    @Test func theOpenListsButtonLooksOpen() {
        let (panel, _) = make()
        panel.update(options: .text(font: .serif, size: 36), openList: .fontSize)
        #expect(panel.buttons[.fontSize]?.isOpen == true)
        #expect(panel.buttons[.font]?.isOpen == false)
        panel.markOpen(nil)
        #expect(panel.buttons[.fontSize]?.isOpen == false)
    }

    @Test func clickingADropdownAsksToOpenItsList() {
        let (panel, recorder) = make()
        panel.update(options: .text(font: .serif, size: 36), openList: nil)
        panel.buttons[.fontSize]?.performClick(nil)
        panel.buttons[.font]?.performClick(nil)
        #expect(recorder.opened == [.fontSize, .font])
    }
}
