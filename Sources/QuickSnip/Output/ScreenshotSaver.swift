import Foundation

/// Writes PNGs as "QuickSnip yyyy-MM-dd at HH.mm.ss.png", never overwriting existing files.
struct ScreenshotSaver {
    var directory: URL
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

    func save(_ png: Data) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let base = baseName(for: now())
        var url = directory.appendingPathComponent("\(base).png")
        var counter = 2
        while fileManager.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(base) (\(counter)).png")
            counter += 1
        }

        try png.write(to: url, options: .withoutOverwriting)
        return url
    }
}
