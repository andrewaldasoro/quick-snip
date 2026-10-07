import AppKit
import Testing
@testable import QuickSnip

@MainActor
struct AnnotationToolbarTests {
    private final class Recorder {
        var tools: [AnnotationTool] = []
        var colors: [AnnotationColor] = []
        var widths: [StrokeWidth] = []
        var commands: [OverlayCommand] = []
    }

    private func make() -> (AnnotationToolbar, Recorder) {
        let recorder = Recorder()
        let toolbar = AnnotationToolbar(actions: .init(
            selectTool: { recorder.tools.append($0) },
            selectColor: { recorder.colors.append($0) },
            selectWidth: { recorder.widths.append($0) },
            command: { recorder.commands.append($0) }
        ))
        return (toolbar, recorder)
    }

    @Test func hasAButtonForEveryToolAndCommand() {
        let (toolbar, _) = make()
        #expect(Set(toolbar.toolButtons.keys) == Set(AnnotationTool.allCases))
        #expect(Set(toolbar.commandButtons.keys) == Set(AnnotationToolbar.commands))
        #expect(toolbar.colorControl.segmentCount == AnnotationColor.allCases.count)
        #expect(toolbar.widthControl.segmentCount == StrokeWidth.allCases.count)
    }

    @Test func sizesItselfToFitContent() {
        let (toolbar, _) = make()
        #expect(toolbar.frame.width > 200)
        #expect(toolbar.frame.height > 40)   // two rows
    }

    /// Regression: a single row was 812pt wide, overflowing small selections and screens.
    @Test func compactEnoughForSmallScreens() {
        let (toolbar, _) = make()
        #expect(toolbar.frame.width <= 480)
    }

    @Test func toolButtonsSendTheirTool() {
        let (toolbar, recorder) = make()
        toolbar.toolButtons[.arrow]?.performClick(nil)
        toolbar.toolButtons[.pixelate]?.performClick(nil)
        #expect(recorder.tools == [.arrow, .pixelate])
    }

    @Test func commandButtonsSendTheirCommand() {
        let (toolbar, recorder) = make()
        for command in AnnotationToolbar.commands {
            toolbar.commandButtons[command]?.isEnabled = true
            toolbar.commandButtons[command]?.performClick(nil)
        }
        #expect(recorder.commands == AnnotationToolbar.commands)
    }

    @Test func colorAndWidthSegmentsSendTheirValue() {
        let (toolbar, recorder) = make()
        toolbar.colorControl.selectedSegment = AnnotationColor.allCases.firstIndex(of: .green)!
        toolbar.colorControl.sendAction(toolbar.colorControl.action, to: toolbar.colorControl.target)
        toolbar.widthControl.selectedSegment = StrokeWidth.allCases.firstIndex(of: .thick)!
        toolbar.widthControl.sendAction(toolbar.widthControl.action, to: toolbar.widthControl.target)
        #expect(recorder.colors == [.green])
        #expect(recorder.widths == [.thick])
    }

    @Test func updateReflectsSessionState() {
        let (toolbar, _) = make()
        toolbar.update(tool: .marker, style: AnnotationStyle(color: .blue, width: .thin), canUndo: true, canRedo: false)

        #expect(toolbar.toolButtons[.marker]?.state == .on)
        #expect(toolbar.toolButtons[.rectangle]?.state == .off)
        #expect(toolbar.colorControl.selectedSegment == AnnotationColor.allCases.firstIndex(of: .blue))
        #expect(toolbar.widthControl.selectedSegment == StrokeWidth.allCases.firstIndex(of: .thin))
        #expect(toolbar.commandButtons[.undo]?.isEnabled == true)
        #expect(toolbar.commandButtons[.redo]?.isEnabled == false)
    }

    @Test func noToolSelectedTurnsAllOff() {
        let (toolbar, _) = make()
        toolbar.update(tool: .text, style: .default, canUndo: false, canRedo: false)
        toolbar.update(tool: nil, style: .default, canUndo: false, canRedo: false)
        #expect(toolbar.toolButtons.values.allSatisfy { $0.state == .off })
    }

    @Test func everyControlIsLabelledForAccessibility() {
        let (toolbar, _) = make()
        let buttons = Array(toolbar.toolButtons.values) + Array(toolbar.commandButtons.values)
        #expect(buttons.allSatisfy { !($0.accessibilityLabel() ?? "").isEmpty })
        #expect(buttons.allSatisfy { $0.image != nil })
    }
}
