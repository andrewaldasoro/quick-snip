import CoreGraphics
import Foundation

/// One on-screen window, as the window server lists it.
struct WindowInfo: Equatable, Sendable {
    let id: CGWindowID
    /// Frame in Core Graphics global coordinates (points, top-left origin of the primary display).
    let frame: CGRect
    /// Window level; ordinary app windows are 0.
    let layer: Int
    let ownerProcessID: pid_t
    let alpha: Double

    init(id: CGWindowID = 1, frame: CGRect, layer: Int = 0, ownerProcessID: pid_t = 1, alpha: Double = 1) {
        self.id = id
        self.frame = frame
        self.layer = layer
        self.ownerProcessID = ownerProcessID
        self.alpha = alpha
    }

    /// Reads one entry of `CGWindowListCopyWindowInfo`; nil when the number, bounds, layer or owner is missing.
    init?(_ entry: [String: Any]) {
        guard let id = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
            let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
            let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
            let layer = (entry[kCGWindowLayer as String] as? NSNumber)?.intValue,
            let owner = (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
        else { return nil }
        let alpha = (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
        self.init(id: id, frame: frame, layer: layer, ownerProcessID: owner, alpha: alpha)
    }
}
