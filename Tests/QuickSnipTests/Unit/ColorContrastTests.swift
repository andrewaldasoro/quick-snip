import AppKit
import Testing

@testable import QuickSnip

struct ColorContrastTests {
    private static func srgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    @Test func luminanceSpansBlackToWhite() {
        #expect(ColorContrast.luminance(.black) == 0)
        #expect(abs(ColorContrast.luminance(.white) - 1) < 0.001)
    }

    @Test func blackOnWhiteIsTheMaximumRatio() {
        #expect(abs(ColorContrast.ratio(.black, .white) - 21) < 0.01)
        #expect(ColorContrast.ratio(.white, .white) == 1)
    }

    @Test func ratioIsSymmetric() {
        let blue = Self.srgb(0, 0.48, 1)
        #expect(ColorContrast.ratio(.white, blue) == ColorContrast.ratio(blue, .white))
    }

    /// The accent can be any of the system colors, light or dark.
    @Test(arguments: [
        (CGFloat(0), CGFloat(0.48), CGFloat(1), true),  // blue
        (0.69, 0.32, 0.87, true),  // purple
        (1, 0.8, 0, false),  // yellow
        (0.6, 0.6, 0.6, false),  // graphite-ish light gray
    ])
    func readableForegroundPicksWhiteOrBlack(red: CGFloat, green: CGFloat, blue: CGFloat, expectsWhite: Bool) {
        let background = Self.srgb(red, green, blue)
        let foreground = ColorContrast.readableForeground(on: background)
        #expect(foreground == (expectsWhite ? NSColor.white : NSColor.black))
        #expect(ColorContrast.ratio(foreground, background) >= ColorContrast.minimumRatio)
    }
}
