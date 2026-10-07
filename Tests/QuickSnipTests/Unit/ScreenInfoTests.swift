import CoreGraphics
import Testing
@testable import QuickSnip

struct ScreenInfoTests {
    @Test(arguments: [
        (CGRect(x: 0, y: 0, width: 1512, height: 982), CGFloat(2), CGSize(width: 3024, height: 1964)),
        (CGRect(x: 1512, y: 0, width: 1920, height: 1080), 1, CGSize(width: 1920, height: 1080)),
        (CGRect(x: 0, y: 0, width: 1001, height: 501), 1.5, CGSize(width: 1502, height: 752)),
    ] as [(CGRect, CGFloat, CGSize)])
    func pixelSizeScalesAndRounds(frame: CGRect, scale: CGFloat, expected: CGSize) {
        #expect(ScreenInfo(displayID: 1, frame: frame, scale: scale).pixelSize == expected)
    }

    @Test @MainActor func currentScreensHaveUniqueIDs() {
        let screens = ScreenInfo.current()
        #expect(Set(screens.map(\.displayID)).count == screens.count)
    }
}
