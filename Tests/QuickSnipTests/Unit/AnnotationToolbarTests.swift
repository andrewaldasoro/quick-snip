import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct AnnotationToolbarTests {
    private final class Recorder {
        var tools: [AnnotationTool] = []
        var commands: [OverlayCommand] = []
    }

    private func make() -> (AnnotationToolbar, Recorder) {
        let recorder = Recorder()
        let toolbar = AnnotationToolbar(
            actions: .init(
                selectTool: { recorder.tools.append($0) },
                command: { recorder.commands.append($0) }
            ))
        return (toolbar, recorder)
    }

    @Test func hasAButtonForEveryToolAndCommand() {
        let (toolbar, _) = make()
        #expect(Set(toolbar.toolButtons.keys) == Set(AnnotationTool.allCases))
        #expect(Set(toolbar.commandButtons.keys) == Set(AnnotationToolbar.commands))
    }

    @Test func isOneRow() {
        let (toolbar, _) = make()
        #expect(toolbar.frame.width > 200)
        #expect(toolbar.frame.height < AnnotationToolbar.buttonSize.height * 2)
    }

    /// Regression: a single row was 812pt wide, overflowing small selections and screens.
    /// Regression: at exactly 480 pt it measured 481 on CI's 1× runner (text widths differ by
    /// scale), so it keeps a few points of headroom.
    @Test func compactEnoughForSmallScreens() {
        let (toolbar, _) = make()
        #expect(toolbar.frame.width <= 480 - 4)
    }

    @Test func readTextSitsJustBeforeSaveAndCopy() throws {
        let (toolbar, _) = make()
        toolbar.layoutSubtreeIfNeeded()
        let readText = try #require(toolbar.commandButtons[.readText]).convert(NSPoint.zero, to: toolbar).x
        let save = try #require(toolbar.commandButtons[.save]).convert(NSPoint.zero, to: toolbar).x
        let copy = try #require(toolbar.commandButtons[.copy]).convert(NSPoint.zero, to: toolbar).x
        let redo = try #require(toolbar.commandButtons[.redo]).convert(NSPoint.zero, to: toolbar).x
        #expect(redo < readText)
        #expect(readText < save)
        #expect(save < copy)
    }

    @Test func saveIsAnOutlinedIconButton() {
        let (toolbar, _) = make()
        let save = toolbar.commandButtons[.save]
        #expect(save is OutlineToolbarButton)
        #expect(save?.title.isEmpty == true)
        #expect(save?.intrinsicContentSize.height == AnnotationToolbar.buttonSize.height)
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

    @Test func updateReflectsSessionState() {
        let (toolbar, _) = make()
        toolbar.update(tool: .marker, canUndo: true, canRedo: false)

        #expect(toolbar.toolButtons[.marker]?.state == .on)
        #expect(toolbar.toolButtons[.shape]?.state == .off)
        #expect(toolbar.commandButtons[.undo]?.isEnabled == true)
        #expect(toolbar.commandButtons[.redo]?.isEnabled == false)
    }

    @Test func shapeAndArrowButtonsShowWhatTheyDrawNext() {
        let (toolbar, _) = make()
        #expect((toolbar.toolButtons[.shape] as? ToolbarButton)?.symbol == ShapeKind.rectangle.symbol)
        #expect((toolbar.toolButtons[.arrow] as? ToolbarButton)?.symbol == ArrowHeads.end.symbol)

        toolbar.update(tool: nil, style: AnnotationStyle(shape: .oval, arrowHeads: .both), canUndo: false, canRedo: false)

        #expect((toolbar.toolButtons[.shape] as? ToolbarButton)?.symbol == ShapeKind.oval.symbol)
        #expect((toolbar.toolButtons[.arrow] as? ToolbarButton)?.symbol == ArrowHeads.both.symbol)
        #expect((toolbar.toolButtons[.pen] as? ToolbarButton)?.symbol == "pencil.tip")
    }

    @Test func noToolSelectedTurnsAllOff() {
        let (toolbar, _) = make()
        toolbar.update(tool: .text, canUndo: false, canRedo: false)
        toolbar.update(tool: nil, canUndo: false, canRedo: false)
        #expect(toolbar.toolButtons.values.allSatisfy { $0.state == .off })
    }

    @Test func everyControlIsLabelledForAccessibility() {
        let (toolbar, _) = make()
        let buttons =
            Array(toolbar.toolButtons.values) + Array(toolbar.commandButtons.values)
        #expect(buttons.allSatisfy { !($0.accessibilityLabel() ?? "").isEmpty })
        #expect(buttons.allSatisfy { !($0.toolTip ?? "").isEmpty })
    }

    /// A misspelled SF Symbol name silently gives an empty button.
    @Test func everySymbolExists() {
        let names =
            AnnotationTool.allCases.map { AnnotationToolbar.symbol(for: $0) }
            + AnnotationToolbar.commands.map(AnnotationToolbar.symbol(for:))
            + ShapeKind.allCases.map(\.symbol) + ArrowHeads.allCases.map(\.symbol)
        for name in names {
            #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
        }
    }

    @Test func glyphButtonsAreBorderlessAndUniform() {
        let (toolbar, _) = make()
        let glyphs = Array(toolbar.toolButtons.values) + toolbar.commandButtons.filter { ![.copy, .save].contains($0.key) }.map(\.value)
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
        toolbar.update(tool: .pen, canUndo: true, canRedo: true)
        #expect(toolbar.fittingSize == size)
    }
}

@MainActor
struct AnnotationToolbarShortcutTests {
    @Test func tooltipsAdvertiseKeyboardShortcuts() {
        let toolbar = AnnotationToolbar(
            actions: .init(selectTool: { _ in }, command: { _ in }))
        #expect(toolbar.toolButtons[.shape]?.toolTip == "Shape (R)")
        #expect(toolbar.toolButtons[.pixelate]?.toolTip == "Pixelate (X)")
        #expect(toolbar.commandButtons[.copy]?.toolTip == "Copy (⌘C)")
        #expect(AnnotationToolbar.label(for: AnnotationColor.red) == "Red (1)")
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
        #expect(button.contentTintColor == ToolbarButton.accentForeground)
    }

    /// Regression: an accent glyph on a 20% accent wash was hard to read. On and primary
    /// buttons are now an opaque fill.
    @Test func onAndPrimaryButtonsAreOpaque() throws {
        let tool = ToolbarButton(symbol: "rectangle", label: "Rectangle", toggles: true)
        tool.setFrameSize(AnnotationToolbar.buttonSize)
        tool.state = .on
        let copy = PrimaryToolbarButton(title: "Copy", symbol: "doc.on.doc", label: "Copy (⌘C)")
        copy.setFrameSize(copy.intrinsicContentSize)

        #expect(try centerAlpha(tool) == 255)
        #expect(try centerAlpha(copy) == 255)
    }

    @Test func foregroundContrastsWithTheAccentFill() {
        for (isHighlighted, isHovered) in [(false, false), (false, true), (true, false)] {
            let fill = ToolbarButton.accentFill(isHighlighted: isHighlighted, isHovered: isHovered)
            #expect(ColorContrast.ratio(ToolbarButton.accentForeground, fill) >= ColorContrast.minimumRatio)
        }
    }

    @Test func hoverAndPressDarkenTheFill() {
        let plain = ColorContrast.luminance(ToolbarButton.accentFill(isHighlighted: false, isHovered: false))
        let hovered = ColorContrast.luminance(ToolbarButton.accentFill(isHighlighted: false, isHovered: true))
        let pressed = ColorContrast.luminance(ToolbarButton.accentFill(isHighlighted: true, isHovered: false))
        #expect(pressed < hovered)
        #expect(hovered < plain)
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

    /// CI renders at 1×, this Mac at 2×: check the border at both.
    @Test(arguments: [1, 2])
    func outlineBorderShowsAtEveryScale(scale: Int) throws {
        let button = OutlineToolbarButton(symbol: "square.and.arrow.down", label: "Save (⌘S)")
        button.setFrameSize(button.intrinsicContentSize)
        let image = try TestRendering.render(button, scale: scale)
        #expect(image.width == Int(button.bounds.width) * scale)
        #expect(TestImages.pixel(image, x: image.width / 2, y: 0).a > 0)
        #expect(TestImages.pixel(image, x: 0, y: image.height / 2).a > 0)
    }

    /// Regression: the Save icon sat a point low, centered by its padded bounds.
    @Test(arguments: [1, 2])
    func saveIconIsCenteredByWhatYouSee(scale: Int) throws {
        let button = OutlineToolbarButton(symbol: "square.and.arrow.down", label: "Save (⌘S)")
        button.setFrameSize(button.intrinsicContentSize)
        let image = try TestRendering.render(button, scale: scale)
        let inset = 3 * scale  // past the border
        let inside = try #require(
            image.cropping(to: CGRect(x: inset, y: inset, width: image.width - inset * 2, height: image.height - inset * 2)))
        let ink = try #require(ImageInk.pixelBounds(of: inside))
        let center = CGFloat(inside.width) / 2
        #expect(abs(ink.midX - center) <= 1, "x \(ink.midX) vs \(center)")
        #expect(abs(ink.midY - CGFloat(inside.height) / 2) <= 1, "y \(ink.midY)")
    }

    @Test func outlineButtonHasABorderAndFillsOnlyOnHoverAndPress() throws {
        let button = OutlineToolbarButton(symbol: "square.and.arrow.down", label: "Save (⌘S)")
        button.setFrameSize(button.intrinsicContentSize)
        #expect(button.fillAlpha == 0)
        // The border's top edge: row 0 at any scale (at 1× it's only that row).
        let image = try render(button)
        #expect(TestImages.pixel(image, x: image.width / 2, y: 0).a > 0)
        #expect(TestImages.pixel(image, x: image.width / 7, y: image.height / 2).a == 0)  // no fill inside
        button.mouseEntered(with: NSEvent())
        #expect(button.fillAlpha > 0)
        button.isHighlighted = true
        let pressed = button.fillAlpha
        button.mouseExited(with: NSEvent())
        #expect(button.fillAlpha == pressed)
        button.isHighlighted = false
        #expect(button.fillAlpha == 0)
        #expect(button.accessibilityLabel() == "Save (⌘S)")
    }
}
