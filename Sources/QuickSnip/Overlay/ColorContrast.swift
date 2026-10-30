import AppKit

/// WCAG contrast math, so text and glyphs stay readable on whatever accent color the user picked.
enum ColorContrast {
    /// Relative luminance (0 black – 1 white) of a color in sRGB.
    static func luminance(_ color: NSColor) -> CGFloat {
        guard let srgb = color.usingColorSpace(.sRGB) else { return 0 }
        func linear(_ c: CGFloat) -> CGFloat { c <= 0.039_28 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(srgb.redComponent) + 0.7152 * linear(srgb.greenComponent) + 0.0722 * linear(srgb.blueComponent)
    }

    /// From 1 (none) to 21 (black on white).
    static func ratio(_ a: NSColor, _ b: NSColor) -> CGFloat {
        let (first, second) = (luminance(a), luminance(b))
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    /// WCAG's minimum for UI components and large text.
    static let minimumRatio: CGFloat = 3

    /// White, like macOS's own accent buttons, unless it's too faint on `background` (a yellow
    /// or light accent): then black.
    static func readableForeground(on background: NSColor) -> NSColor {
        ratio(.white, background) >= minimumRatio ? .white : .black
    }
}
