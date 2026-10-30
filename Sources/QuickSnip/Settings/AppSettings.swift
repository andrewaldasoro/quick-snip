import Foundation
import Observation
import UniformTypeIdentifiers

enum ImageFormat: String, CaseIterable, Sendable {
    case png, jpeg

    var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpeg: "jpg"
        }
    }

    var utType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        }
    }

    var displayName: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        }
    }
}

/// User preferences, persisted in `UserDefaults`.
@MainActor
@Observable
final class AppSettings {
    enum Key {
        static let saveDirectory = "saveDirectory"
        static let imageFormat = "imageFormat"
        static let showThumbnail = "showThumbnail"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let textFont = "textFont"
        static let textSize = "textSize"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var saveDirectory: URL {
        didSet { defaults.set(saveDirectory.path, forKey: Key.saveDirectory) }
    }

    var imageFormat: ImageFormat {
        didSet { defaults.set(imageFormat.rawValue, forKey: Key.imageFormat) }
    }

    var showThumbnail: Bool {
        didSet { defaults.set(showThumbnail, forKey: Key.showThumbnail) }
    }

    /// When off, reopening the app (Finder, Spotlight) is the way back to Settings.
    var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Key.showMenuBarIcon) }
    }

    /// The last font and size picked for text annotations.
    var textFont: TextFont {
        didSet { defaults.set(textFont.storageValue, forKey: Key.textFont) }
    }

    var textSize: CGFloat {
        didSet { defaults.set(Double(textSize), forKey: Key.textSize) }
    }

    init(defaults: UserDefaults = .standard, defaultDirectory: URL = ScreenshotSaver.defaultDirectory) {
        self.defaults = defaults
        saveDirectory =
            defaults.string(forKey: Key.saveDirectory).map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? defaultDirectory
        imageFormat = defaults.string(forKey: Key.imageFormat).flatMap(ImageFormat.init(rawValue:)) ?? .png
        showThumbnail = defaults.object(forKey: Key.showThumbnail) as? Bool ?? true
        showMenuBarIcon = defaults.object(forKey: Key.showMenuBarIcon) as? Bool ?? true
        textFont = defaults.string(forKey: Key.textFont).flatMap(TextFont.init(storageValue:)) ?? .system
        textSize = (defaults.object(forKey: Key.textSize) as? Double).map { TextSize.clamp(CGFloat($0)) } ?? TextSize.default
    }
}
