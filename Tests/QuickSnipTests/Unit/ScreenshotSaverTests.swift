import Foundation
import Testing

@testable import QuickSnip

struct ScreenshotSaverTests {
    // 2026-10-07 11:49:40 UTC
    private let date = Date(timeIntervalSince1970: 1_791_373_780)

    private func saver(_ directory: URL) -> ScreenshotSaver {
        ScreenshotSaver(directory: directory, now: { date }, timeZone: .gmt)
    }

    @Test func baseNameUsesTimestamp() {
        #expect(saver(URL(fileURLWithPath: "/tmp")).baseName(for: date) == "QuickSnip 2026-10-07 at 11.49.40")
    }

    @Test func baseNameRespectsTimeZone() {
        var saver = saver(URL(fileURLWithPath: "/tmp"))
        saver.timeZone = TimeZone(secondsFromGMT: -4 * 3600)!
        #expect(saver.baseName(for: date) == "QuickSnip 2026-10-07 at 07.49.40")
    }

    @Test func saveWritesDataAndCreatesDirectory() throws {
        let directory = TestImages.temporaryDirectory().appendingPathComponent("nested")
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        let url = try saver(directory).save(Data([1, 2, 3]))

        #expect(url.lastPathComponent == "QuickSnip 2026-10-07 at 11.49.40.png")
        #expect(try Data(contentsOf: url) == Data([1, 2, 3]))
    }

    @Test func saveNeverOverwrites() throws {
        let directory = TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let saver = saver(directory)

        let first = try saver.save(Data([1]))
        let second = try saver.save(Data([2]))
        let third = try saver.save(Data([3]))

        #expect(second.lastPathComponent == "QuickSnip 2026-10-07 at 11.49.40 (2).png")
        #expect(third.lastPathComponent == "QuickSnip 2026-10-07 at 11.49.40 (3).png")
        #expect(try Data(contentsOf: first) == Data([1]))
    }

    @Test func defaultDirectoryIsDesktop() {
        #expect(ScreenshotSaver.defaultDirectory.lastPathComponent == "Desktop")
    }
}

struct ScreenshotSaverFormatTests {
    private let date = Date(timeIntervalSince1970: 1_791_373_780)

    @Test func jpegUsesJpgExtensionAndOwnCollisionSequence() throws {
        let directory = TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var saver = ScreenshotSaver(directory: directory, now: { date }, timeZone: .gmt)
        saver.format = .jpeg

        let first = try saver.save(Data([1]))
        let second = try saver.save(Data([2]))
        #expect(first.lastPathComponent == "QuickSnip 2026-10-07 at 11.49.40.jpg")
        #expect(second.lastPathComponent == "QuickSnip 2026-10-07 at 11.49.40 (2).jpg")
    }

    @Test func defaultFormatIsPNG() {
        #expect(ScreenshotSaver(directory: URL(fileURLWithPath: "/tmp")).format == .png)
    }
}
