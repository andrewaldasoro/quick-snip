// Renders the QuickSnip app icon (original artwork) into an .iconset directory.
// Usage: swift scripts/make-icon.swift <output.iconset>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The same artwork as the website logo (`site/index.html`): a 64-unit blue rounded square
/// with four white corner brackets. Keep the two in sync.
func render(size: Int) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    // macOS icon grid: the artwork fills the 824pt tile centered in 1024. Flipped so the
    // 64-unit coordinates match the SVG (top-left origin).
    let unit: CGFloat = 824 / 64
    ctx.translateBy(x: 100, y: 924)
    ctx.scaleBy(x: unit, y: -unit)

    ctx.setFillColor(CGColor(srgbRed: 10 / 255, green: 132 / 255, blue: 1, alpha: 1))  // #0a84ff
    ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 64, height: 64), cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.fillPath()

    // M18 26v-8h8  M46 26v-8h-8  M18 38v8h8  M46 38v8h-8
    let brackets: [[CGPoint]] = [
        [CGPoint(x: 18, y: 26), CGPoint(x: 18, y: 18), CGPoint(x: 26, y: 18)],
        [CGPoint(x: 46, y: 26), CGPoint(x: 46, y: 18), CGPoint(x: 38, y: 18)],
        [CGPoint(x: 18, y: 38), CGPoint(x: 18, y: 46), CGPoint(x: 26, y: 46)],
        [CGPoint(x: 46, y: 38), CGPoint(x: 46, y: 46), CGPoint(x: 38, y: 46)],
    ]
    for bracket in brackets {
        ctx.addLines(between: bracket)
    }
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(5)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    precondition(CGImageDestinationFinalize(dest), "Failed to write \(url.path)")
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    write(render(size: base), to: output.appendingPathComponent("icon_\(base)x\(base).png"))
    write(render(size: base * 2), to: output.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
