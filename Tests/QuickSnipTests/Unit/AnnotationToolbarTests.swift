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
        let toolbar = AnnotationToolbar(
            actions: .init(
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
        #expect(Set(toolbar.colorButtons.keys) == Set(AnnotationColor.allCases))
        #expect(Set(toolbar.widthButtons.keys) == Set(StrokeWidth.allCases))
    }

    @Test func sizesItselfToFitContent() {
        let (toolbar, _) = make()
        #expect(toolbar.frame.width > 200)
        #expect(toolbar.frame.height > 40)  // two rows
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

    @Test func colorAndWidthButtonsSendTheirValue() {
        let (toolbar, recorder) = make()
        toolbar.colorButtons[.green]?.performClick(nil)
        toolbar.widthButtons[.thick]?.performClick(nil)
        #expect(recorder.colors == [.green])
        #expect(recorder.widths == [.thick])
    }

    @Test func updateReflectsSessionState() {
        let (toolbar, _) = make()
        toolbar.update(tool: .marker, style: AnnotationStyle(color: .blue, width: .thin), canUndo: true, canRedo: false)

        #expect(toolbar.toolButtons[.marker]?.state == .on)
        #expect(toolbar.toolButtons[.rectangle]?.state == .off)
        #expect(toolbar.colorButtons[.blue]?.state == .on)
        #expect(toolbar.colorButtons.filter { $0.value.state == .on }.count == 1)
        #expect(toolbar.widthButtons[.thin]?.state == .on)
        #expect(toolbar.widthButtons.filter { $0.value.state == .on }.count == 1)
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
        let buttons =
            Array(toolbar.toolButtons.values) + Array(toolbar.commandButtons.values)
            + Array(toolbar.colorButtons.values) + Array(toolbar.widthButtons.values)
        #expect(buttons.allSatisfy { !($0.accessibilityLabel() ?? "").isEmpty })
        #expect(buttons.allSatisfy { !($0.toolTip ?? "").isEmpty })
    }

    /// A misspelled SF Symbol name silently gives an empty button.
    @Test func everySymbolExists() {
        let names =
            AnnotationTool.allCases.map(AnnotationToolbar.symbol(for:))
            + AnnotationToolbar.commands.map(AnnotationToolbar.symbol(for:))
        for name in names {
            #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
        }
    }

    @Test func glyphButtonsAreBorderlessAndUniform() {
        let (toolbar, _) = make()
        let glyphs = Array(toolbar.toolButtons.values) + toolbar.commandButtons.filter { $0.key != .copy }.map(\.value)
        toolbar.layoutSubtreeIfNeeded()
        #expect(glyphs.allSatisfy { !$0.isBordered })
        #expect(glyphs.allSatisfy { $0.frame.size == AnnotationToolbar.buttonSize })
    }

    @Test func copyIsTheProminentTextButton() {
        let (toolbar, _) = make()
        let copy = toolbar.commandButtons[.copy]
        #expect(copy is PrimaryToolbarButton)
        #expect(copy?.title == "Copy")
        #expect(copy?.image != nil)
    }

    /// Regression: the trailing inset was dropped, so Copy touched the panel's edge and
    /// got clipped by its rounded corner.
    @Test func controlsKeepTheirInsetFromEveryEdge() throws {
        let (toolbar, _) = make()
        toolbar.layoutSubtreeIfNeeded()
        let all =
            Array(toolbar.toolButtons.values) + Array(toolbar.commandButtons.values)
            + Array(toolbar.colorButtons.values) + Array(toolbar.widthButtons.values)
        let inner = toolbar.bounds.insetBy(dx: AnnotationToolbar.insets.left, dy: AnnotationToolbar.insets.top)
        for button in all {
            let frame = button.convert(button.bounds, to: toolbar)
            #expect(inner.contains(frame), "\(button.toolTip ?? "") at \(frame)")
        }
        let copy = try #require(toolbar.commandButtons[.copy]).convert(toolbar.commandButtons[.copy]!.bounds, to: toolbar)
        #expect(toolbar.bounds.maxX - copy.maxX == AnnotationToolbar.insets.right)
    }

    /// Regression: the Copy push bezel was 24pt tall, inset 2pt, so it sat off the
    /// glyph buttons' line.
    @Test func copyLinesUpWithGlyphButtons() throws {
        let (toolbar, _) = make()
        toolbar.layoutSubtreeIfNeeded()
        let copy = try #require(toolbar.commandButtons[.copy])
        let save = try #require(toolbar.commandButtons[.save])
        #expect(copy.frame.height == AnnotationToolbar.buttonSize.height)
        #expect(copy.frame.minY == save.frame.minY)
    }

    @Test func hoverAndToggleDoNotChangeLayout() {
        let (toolbar, _) = make()
        let size = toolbar.fittingSize
        toolbar.update(tool: .pen, style: AnnotationStyle(color: .yellow, width: .thick), canUndo: true, canRedo: true)
        #expect(toolbar.fittingSize == size)
    }
}

@MainActor
struct AnnotationToolbarShortcutTests {
    @Test func tooltipsAdvertiseKeyboardShortcuts() {
        let toolbar = AnnotationToolbar(
            actions: .init(selectTool: { _ in }, selectColor: { _ in }, selectWidth: { _ in }, command: { _ in }))
        #expect(toolbar.toolButtons[.rectangle]?.toolTip == "Rectangle (R)")
        #expect(toolbar.toolButtons[.pixelate]?.toolTip == "Pixelate (X)")
        #expect(toolbar.commandButtons[.copy]?.toolTip == "Copy (⌘C)")
        #expect(toolbar.colorButtons[.red]?.toolTip == "Red (1)")
    }
}

@MainActor
struct ToolbarControlDrawingTests {
    private func render(_ view: NSView) throws -> CGImage {
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        return try #require(rep.cgImage)
    }

    private func centerAlpha(_ view: NSView) throws -> UInt8 {
        let image = try render(view)
        return TestImages.pixel(image, x: image.width / 2, y: 1).a
    }

    @Test func glyphButtonHighlightsOnHoverAndWhenOn() throws {
        let button = ToolbarButton(symbol: "rectangle", label: "Rectangle", toggles: true)
        button.setFrameSize(AnnotationToolbar.buttonSize)
        #expect(try centerAlpha(button) == 0)

        button.mouseEntered(with: NSEvent())
        #expect(try centerAlpha(button) > 0)
        button.mouseExited(with: NSEvent())
        #expect(try centerAlpha(button) == 0)

        button.state = .on
        #expect(try centerAlpha(button) > 0)
        #expect(button.contentTintColor == .controlAccentColor)
    }

    @Test func disabledGlyphButtonDrawsNoHighlight() throws {
        let button = ToolbarButton(symbol: "arrow.uturn.backward", label: "Undo", toggles: false)
        button.setFrameSize(AnnotationToolbar.buttonSize)
        button.isEnabled = false
        button.mouseEntered(with: NSEvent())
        #expect(try centerAlpha(button) == 0)
    }

    @Test func primaryButtonIsAlwaysFilled() throws {
        let button = PrimaryToolbarButton(title: "Copy", symbol: "doc.on.doc", label: "Copy (⌘C)")
        button.setFrameSize(button.intrinsicContentSize)
        #expect(try centerAlpha(button) > 0)
        #expect(button.intrinsicContentSize.height == AnnotationToolbar.buttonSize.height)
    }

    @Test func selectedSwatchDrawsARing() throws {
        let swatch = ColorSwatchButton(color: .green, label: "Green (4)")
        swatch.setFrameSize(NSSize(width: AnnotationToolbar.swatchSize, height: AnnotationToolbar.swatchSize))
        #expect(try centerAlpha(swatch) == 0)
        swatch.state = .on
        #expect(try centerAlpha(swatch) > 0)
    }
}
