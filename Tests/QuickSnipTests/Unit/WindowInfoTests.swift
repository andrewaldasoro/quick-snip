import CoreGraphics
import Foundation
import Testing

@testable import QuickSnip

struct WindowInfoTests {
    private func entry(alpha: Double? = 0.5) -> [String: Any] {
        var entry: [String: Any] = [
            kCGWindowNumber as String: NSNumber(value: 812),
            kCGWindowBounds as String: CGRect(x: 10, y: 20, width: 300, height: 200).dictionaryRepresentation,
            kCGWindowLayer as String: NSNumber(value: 3),
            kCGWindowOwnerPID as String: NSNumber(value: 42),
        ]
        entry[kCGWindowAlpha as String] = alpha.map { NSNumber(value: $0) }
        return entry
    }

    @Test func readsAWindowListEntry() {
        let window = WindowInfo(entry())
        #expect(
            window == WindowInfo(id: 812, frame: CGRect(x: 10, y: 20, width: 300, height: 200), layer: 3, ownerProcessID: 42, alpha: 0.5))
    }

    @Test func missingAlphaMeansOpaque() {
        #expect(WindowInfo(entry(alpha: nil))?.alpha == 1)
    }

    @Test(arguments: [kCGWindowNumber, kCGWindowBounds, kCGWindowLayer, kCGWindowOwnerPID].map { $0 as String })
    func entryWithoutARequiredFieldIsSkipped(key: String) {
        var entry = entry()
        entry[key] = nil
        #expect(WindowInfo(entry) == nil)
    }
}
