import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct StylePanelTests {
    private final class Recorder {
        var opened: [StyleList] = []
        var alignments: [TextAlignment] = []
        var shapes: [ShapeKind] = []
        var arrowHeads: [ArrowHeads] = []
    }

    private let text = StyleOptions.text(font: .serif, size: 36, alignment: .center)

    private func make() -> (StylePanel, Recorder) {
        let recorder = Recorder()
        let panel = StylePanel(
            actions: .init(
                openList: { recorder.opened.append($0) },
                selectAlignment: { recorder.alignments.append($0) },
                selectShape: { recorder.shapes.append($0) },
                selectArrowHeads: { recorder.arrowHeads.append($0) }
            ))
        return (panel, recorder)
    }

    @Test func alwaysHasAColorDropdownShowingTheCurrentColor() {
        let (panel, _) = make()
        panel.update(options: .stroke(lineWidth: 4), color: .blue, openList: nil)
        #expect(panel.buttons[.color]?.leadingImage?.accessibilityDescription == "Blue")
        #expect(panel.buttons[.color]?.accessibilityValue() as? String == "Blue")
        panel.update(options: text, color: .green, openList: nil)
        #expect(panel.buttons[.color]?.leadingImage?.accessibilityDescription == "Green")
    }

    @Test func shapesGetAWidthDropdown() {
        let (panel, _) = make()
        panel.update(options: .stroke(lineWidth: 6), color: .red, openList: nil)
        #expect(Set(panel.buttons.keys) == [.color, .lineWidth])
        #expect(panel.buttons[.lineWidth]?.title == "6 px")
        #expect(panel.alignmentButtons.isEmpty)
    }

    @Test func shapesGetWidthAndRectangleOrOval() {
        let (panel, recorder) = make()
        panel.update(options: .shape(.oval, lineWidth: 3), color: .red, openList: nil)
        #expect(Set(panel.buttons.keys) == [.color, .lineWidth])
        #expect(panel.buttons[.lineWidth]?.title == "3 px")
        #expect(panel.shapeButtons[.oval]?.state == .on)
        #expect(panel.shapeButtons[.rectangle]?.state == .off)
        #expect(panel.arrowHeadButtons.isEmpty)

        panel.shapeButtons[.rectangle]?.performClick(nil)
        #expect(recorder.shapes == [.rectangle])
    }

    @Test func arrowsGetWidthAndHeads() {
        let (panel, recorder) = make()
        panel.update(options: .arrow(.both, lineWidth: 6), color: .red, openList: nil)
        #expect(panel.buttons[.lineWidth]?.title == "6 px")
        #expect(Set(panel.arrowHeadButtons.keys) == Set(ArrowHeads.allCases))
        #expect(panel.arrowHeadButtons[.both]?.state == .on)
        #expect(panel.shapeButtons.isEmpty)

        panel.arrowHeadButtons[.none]?.performClick(nil)
        #expect(recorder.arrowHeads == [.none])
    }

    @Test func switchingFromShapeToArrowSwapsTheButtons() {
        let (panel, _) = make()
        panel.update(options: .shape(.rectangle, lineWidth: 4), color: .red, openList: nil)
        panel.update(options: .arrow(.end, lineWidth: 4), color: .red, openList: nil)
        #expect(panel.shapeButtons.isEmpty)
        #expect(panel.arrowHeadButtons[.end]?.state == .on)
    }

    @Test func textGetsFontSizeAndAlignment() {
        let (panel, _) = make()
        panel.update(options: text, color: .red, openList: nil)
        #expect(Set(panel.buttons.keys) == [.color, .font, .fontSize])
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
        panel.buttons[.color]?.performClick(nil)
        panel.alignmentButtons[.right]?.performClick(nil)

        #expect(recorder.opened == [.fontSize, .font, .color])
        #expect(recorder.alignments == [.right])
    }
}
