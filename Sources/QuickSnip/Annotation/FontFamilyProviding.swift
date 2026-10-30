import AppKit

/// The installed font families.
@MainActor
protocol FontFamilyProviding {
    var availableFamilies: [String] { get }
}

struct SystemFontFamilies: FontFamilyProviding {
    var availableFamilies: [String] { NSFontManager.shared.availableFontFamilies }
}
