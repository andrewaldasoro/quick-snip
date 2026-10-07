import CoreGraphics

/// Final image: the selected region at full pixel resolution with annotations burned in.
@MainActor
enum ExportRenderer {
    static func render(
        display: CapturedDisplay,
        selection: CGRect,
        annotations: [Annotation],
        cache: PixelateCache
    ) -> CGImage? {
        guard let pixelRect = CropMath.pixelRect(for: selection, in: display),
              let base = display.image.cropping(to: pixelRect) else { return nil }
        guard !annotations.isEmpty else { return base }

        let width = Int(pixelRect.width), height = Int(pixelRect.height)
        let colorSpace = display.image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }
            ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Map display-local points (top-left origin) onto the crop's pixels.
        let scaleX = display.pixelSize.width / display.frame.width
        let scaleY = display.pixelSize.height / display.frame.height
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scaleX, y: -scaleY)
        context.translateBy(x: -pixelRect.minX / scaleX, y: -pixelRect.minY / scaleY)

        AnnotationRenderer.draw(annotations, in: context, display: display, cache: cache)
        return context.makeImage()
    }
}
