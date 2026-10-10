import CoreGraphics
import Foundation
import ImageIO

enum ImageEncoder {
    static let jpegQuality: CGFloat = 0.9

    /// Encodes `image`, tagging its DPI as 72 × `scale` so Retina captures open at point size.
    static func encode(_ image: CGImage, as format: ImageFormat, scale: CGFloat = 1) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.utType.identifier as CFString, 1, nil) else {
            return nil
        }
        var properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: 72 * scale,
            kCGImagePropertyDPIHeight: 72 * scale,
        ]
        if format == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality] = jpegQuality
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
