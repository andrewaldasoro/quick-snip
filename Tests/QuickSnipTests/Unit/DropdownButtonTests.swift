import AppKit
import Testing

@testable import QuickSnip

@MainActor
struct DropdownButtonTests {
    @Test func isAsTallAsTheToolbarGlyphsAndFitsItsTitle() {
        let button = DropdownButton(title: "4 px", label: "Line width")
        let short = button.intrinsicContentSize
        button.title = "Helvetica Neue"
        #expect(short.height == AnnotationToolbar.buttonSize.height)
        #expect(button.intrinsicContentSize.width > short.width)
    }

    @Test func readsAsAPopUpButtonWithItsValue() {
        let button = DropdownButton(title: "Serif", label: "Font")
        #expect(button.accessibilityRole() == .popUpButton)
        #expect(button.accessibilityLabel() == "Font")
        #expect(button.accessibilityValue() as? String == "Serif")
        #expect(button.toolTip == "Font")
    }

    @Test func aLeadingSwatchAddsWidthAndAnEmptyTitleTakesNone() {
        let button = DropdownButton(title: "", label: "Color")
        let bare = button.intrinsicContentSize.width
        button.leadingImage = DropdownListPanel.colorSwatch(.red)
        #expect(button.intrinsicContentSize.width > bare)
        button.setFrameSize(button.intrinsicContentSize)
        let rep = button.bitmapImageRepForCachingDisplay(in: button.bounds)
        #expect(rep != nil)
        if let rep { button.cacheDisplay(in: button.bounds, to: rep) }
    }

    @Test func titleFontOverrideChangesTheWidth() {
        let button = DropdownButton(title: "Wide", label: "Font")
        let plain = button.intrinsicContentSize.width
        button.titleFontOverride = TextFont.system.font(size: 30)
        #expect(button.intrinsicContentSize.width > plain)
    }

    @Test func drawsAFillThatGetsStrongerWhenOpen() throws {
        let button = DropdownButton(title: "4 px", label: "Line width")
        button.setFrameSize(button.intrinsicContentSize)
        let closed = try Self.alpha(button)
        button.isOpen = true
        #expect(try Self.alpha(button) > closed)
        button.mouseEntered(with: NSEvent())
        button.mouseExited(with: NSEvent())
    }

    private static func alpha(_ view: NSView) throws -> UInt8 {
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = try #require(rep.cgImage)
        return TestImages.pixel(image, x: 2, y: image.height / 2).a
    }
}
