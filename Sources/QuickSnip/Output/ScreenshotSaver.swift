import Foundation

/// Writes images as "QuickSnip yyyy-MM-dd at HH.mm.ss.<ext>", never overwriting existing files.
struct ScreenshotSaver {
    var directory: URL
    var format: ImageFormat = .png
    var now: () -> Date = Date.init
    var timeZone: TimeZone = .current

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    func baseName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "QuickSnip \(formatter.string(from: date))"
    }

    func save(_ data: Data) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let base = baseName(for: now())
        let ext = format.fileExtension
        var url = directory.appendingPathComponent("\(base).\(ext)")
        var counter = 2
        while fileManager.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(base) (\(counter)).\(ext)")
            counter += 1
        }

        try data.write(to: url, options: .withoutOverwriting)
        return url
    }
}
