// Renders the QuickSnip app icon (original artwork) into an .iconset directory.
// Usage: swift scripts/make-icon.swift <output.iconset>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func render(size: Int) -> CGImage {
    let s = CGFloat(size) / 1024
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: s, y: s)

    // macOS icon grid: 824pt rounded square centered in 1024.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(srgbRed: 0.42, green: 0.24, blue: 0.94, alpha: 1),
            CGColor(srgbRed: 0.18, green: 0.50, blue: 1.00, alpha: 1),
        ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])

    // The "snipped" region: a lighter panel.
    let snip = CGRect(x: 292, y: 292, width: 440, height: 440)
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.18))
    ctx.fill(snip)
    ctx.restoreGState()

    // Corner brackets around the snip.
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(52)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    let arm: CGFloat = 130
    let corners: [(CGPoint, CGFloat, CGFloat)] = [
        (CGPoint(x: snip.minX, y: snip.minY), 1, 1),
        (CGPoint(x: snip.maxX, y: snip.minY), -1, 1),
        (CGPoint(x: snip.minX, y: snip.maxY), 1, -1),
        (CGPoint(x: snip.maxX, y: snip.maxY), -1, -1),
    ]
    for (corner, dx, dy) in corners {
        ctx.move(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
        ctx.addLine(to: corner)
        ctx.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
    }
    ctx.strokePath()

    // Crosshair in the middle.
    ctx.setLineWidth(30)
    ctx.move(to: CGPoint(x: 512, y: 452))
    ctx.addLine(to: CGPoint(x: 512, y: 572))
    ctx.move(to: CGPoint(x: 452, y: 512))
    ctx.addLine(to: CGPoint(x: 572, y: 512))
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
