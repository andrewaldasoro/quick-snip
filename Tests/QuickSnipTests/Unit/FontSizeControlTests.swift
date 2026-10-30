import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct FontSizeControlTests {
    private final class Recorder {
        var sizes: [CGFloat] = []
    }

    private func make(size: CGFloat = 22) -> (FontSizeControl, Recorder) {
        let recorder = Recorder()
        let control = FontSizeControl(size: size) { recorder.sizes.append($0) }
        return (control, recorder)
    }

    @Test func showsTheSizeInFieldAndStepper() {
        let (control, _) = make(size: 36)
        #expect(control.field.stringValue == "36")
        #expect(control.stepper.doubleValue == 36)
        #expect(control.stepper.minValue == Double(TextSize.range.lowerBound))
        #expect(control.stepper.maxValue == Double(TextSize.range.upperBound))
    }

    @Test func returnAppliesATypedSize() {
        let (control, recorder) = make()
        control.field.stringValue = "48px"
        control.field.performClick(nil)
        _ = control.field.sendAction(control.field.action, to: control.field.target)

        #expect(recorder.sizes.first == 48)
        #expect(control.size == 48)
        #expect(control.stepper.doubleValue == 48)
    }

    @Test func returnWithoutAChangeStillReportsSoFocusReturns() {
        let (control, recorder) = make()
        _ = control.field.sendAction(control.field.action, to: control.field.target)
        #expect(recorder.sizes == [22])
    }

    @Test func endingTheEditCommitsOnlyRealChanges() {
        let (control, recorder) = make()
        control.field.stringValue = "30"
        control.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification))
        control.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification))
        #expect(recorder.sizes == [30])
    }

    @Test func invalidInputPutsTheSizeBack() {
        let (control, recorder) = make()
        control.field.stringValue = "big"
        #expect(!control.commit())
        #expect(control.field.stringValue == "22")
        #expect(recorder.sizes.isEmpty)
    }

    @Test func outOfRangeInputIsClamped() {
        let (control, recorder) = make()
        control.field.stringValue = "900"
        control.commit()
        #expect(recorder.sizes == [TextSize.range.upperBound])
        #expect(control.field.stringValue == "200")
    }

    @Test func stepperChangesTheSize() {
        let (control, recorder) = make()
        control.stepper.doubleValue = 23
        _ = control.stepper.sendAction(control.stepper.action, to: control.stepper.target)
        #expect(recorder.sizes == [23])
        #expect(control.field.stringValue == "23")
    }

    @Test func escapePutsTheSizeBack() {
        let (control, recorder) = make()
        control.field.stringValue = "99"
        let handled = control.control(control.field, textView: NSTextView(), doCommandBy: #selector(NSResponder.cancelOperation(_:)))
        #expect(handled)
        #expect(control.field.stringValue == "22")
        #expect(recorder.sizes == [22])
    }

    @Test func otherCommandsAreLeftToTheField() {
        let (control, _) = make()
        #expect(!control.control(control.field, textView: NSTextView(), doCommandBy: #selector(NSResponder.moveLeft(_:))))
    }

    @Test func updateShowsANewSize() {
        let (control, _) = make()
        control.update(size: 64)
        #expect(control.field.stringValue == "64")
        #expect(control.size == 64)
    }
}
