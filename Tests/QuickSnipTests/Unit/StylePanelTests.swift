import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct StylePanelTests {
    private final class Recorder {
        var opened: [StyleList] = []
        var colors: [AnnotationColor] = []
        var alignments: [TextAlignment] = []
    }

    private let text = StyleOptions.text(font: .serif, size: 36, alignment: .center)

    private func make() -> (StylePanel, Recorder) {
        let recorder = Recorder()
        let panel = StylePanel(
            actions: .init(
                openList: { recorder.opened.append($0) },
                selectColor: { recorder.colors.append($0) },
                selectAlignment: { recorder.alignments.append($0) }
            ))
        return (panel, recorder)
    }

    @Test func alwaysOffersEveryColorAndMarksTheCurrentOne() {
        let (panel, _) = make()
        panel.update(options: .stroke(lineWidth: 4), color: .blue, openList: nil)
        #expect(Set(panel.colorButtons.keys) == Set(AnnotationColor.allCases))
        #expect(panel.colorButtons[.blue]?.state == .on)
        #expect(panel.colorButtons.filter { $0.value.state == .on }.count == 1)
    }

    @Test func shapesGetAWidthDropdown() {
        let (panel, _) = make()
        panel.update(options: .stroke(lineWidth: 6), color: .red, openList: nil)
        #expect(Set(panel.buttons.keys) == [.lineWidth])
        #expect(panel.buttons[.lineWidth]?.title == "6 px")
        #expect(panel.alignmentButtons.isEmpty)
    }

    @Test func textGetsFontSizeAndAlignment() {
        let (panel, _) = make()
        panel.update(options: text, color: .red, openList: nil)
        #expect(Set(panel.buttons.keys) == [.font, .fontSize])
        #expect(panel.buttons[.font]?.title == "Serif")
        #expect(panel.buttons[.font]?.titleFontOverride == TextFont.serif.font(size: StylePanel.fontTitleSize))
        #expect(panel.buttons[.fontSize]?.title == "36 px")
        #expect(Set(panel.alignmentButtons.keys) == Set(TextAlignment.allCases))
        #expect(panel.alignmentButtons[.center]?.state == .on)
        #expect(panel.alignmentButtons[.left]?.state == .off)
    }

    @Test func isOneRow() {
        let (panel, _) = make()
        panel.update(options: text, color: .red, openList: nil)
        #expect(panel.frame.height < AnnotationToolbar.buttonSize.height * 2)
    }

    @Test func switchingKindRebuildsAndSameKindUpdatesInPlace() throws {
        let (panel, _) = make()
        panel.update(options: text, color: .red, openList: nil)
        let font = try #require(panel.buttons[.font])
        panel.update(options: .text(font: .rounded, size: 12, alignment: .left), color: .red, openList: nil)
        #expect(panel.buttons[.font] === font)
        #expect(font.title == "Rounded")

        panel.update(options: .stroke(lineWidth: 2), color: .red, openList: nil)
        #expect(panel.buttons[.font] == nil)
        #expect(panel.alignmentButtons.isEmpty)
    }

    @Test func theOpenListsButtonLooksOpen() {
        let (panel, _) = make()
        panel.update(options: text, color: .red, openList: .fontSize)
        #expect(panel.buttons[.fontSize]?.isOpen == true)
        #expect(panel.buttons[.font]?.isOpen == false)
        panel.markOpen(nil)
        #expect(panel.buttons[.fontSize]?.isOpen == false)
    }

    @Test func controlsSendTheirChoice() {
        let (panel, recorder) = make()
        panel.update(options: text, color: .red, openList: nil)
        panel.buttons[.fontSize]?.performClick(nil)
        panel.buttons[.font]?.performClick(nil)
        panel.colorButtons[.green]?.performClick(nil)
        panel.alignmentButtons[.right]?.performClick(nil)

        #expect(recorder.opened == [.fontSize, .font])
        #expect(recorder.colors == [.green])
        #expect(recorder.alignments == [.right])
    }
}
