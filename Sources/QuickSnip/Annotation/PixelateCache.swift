import CoreImage
import CoreImage.CIFilterBuiltins

/// Pixelated copies of captured regions. The overlay redraws on every mouse move,
/// so results are cached per region.
@MainActor
final class PixelateCache {
    /// Block size in points; scaled to pixels per display.
    static let blockPoints: CGFloat = 10
    static let capacity = 64

    private static let context = CIContext(options: [.cacheIntermediates: false])

    private struct Key: Hashable {
        let displayID: CGDirectDisplayID
        let x, y, width, height: Int
    }

    private var images: [Key: CGImage] = [:]

    var count: Int { images.count }

    func image(for display: CapturedDisplay, pixelRect: CGRect) -> CGImage? {
        let key = Key(
            displayID: display.displayID,
            x: Int(pixelRect.minX), y: Int(pixelRect.minY),
            width: Int(pixelRect.width), height: Int(pixelRect.height)
        )
        if let cached = images[key] { return cached }

        guard let region = display.image.cropping(to: pixelRect) else { return nil }
        let block = Self.blockPoints * display.pixelSize.width / display.frame.width
        guard let result = Self.pixelate(region, blockSize: block) else { return nil }

        if images.count >= Self.capacity { images.removeAll() }
        images[key] = result
        return result
    }

    static func pixelate(_ image: CGImage, blockSize: CGFloat) -> CGImage? {
        let input = CIImage(cgImage: image)
        let filter = CIFilter.pixellate()
        filter.inputImage = input.clampedToExtent()
        filter.scale = Float(max(blockSize, 1))
        filter.center = .zero
        guard let output = filter.outputImage?.cropped(to: input.extent) else { return nil }
        return context.createCGImage(output, from: input.extent)
    }
}
