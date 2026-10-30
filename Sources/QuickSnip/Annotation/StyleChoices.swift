import CoreGraphics

/// One of the style panel's dropdowns.
enum StyleList: Equatable, Sendable {
    case lineWidth, font, fontSize
}

/// A value picked from a style dropdown.
enum StyleValue: Equatable, Sendable {
    case lineWidth(CGFloat)
    case font(TextFont)
    case fontSize(CGFloat)

    /// "4 px", "Serif", "22 px".
    var title: String {
        switch self {
        case .lineWidth(let width): StyleChoices.pixels(width)
        case .font(let font): font.displayName
        case .fontSize(let size): StyleChoices.pixels(size)
        }
    }
}

/// The entries of each style dropdown and which one is current.
enum StyleChoices {
    static func values(for list: StyleList, options: StyleOptions, fontFamilies: [String]) -> [StyleValue] {
        switch (list, options) {
        case (.lineWidth, .stroke):
            return LineWidth.presets.map(StyleValue.lineWidth)
        case (.font, .text):
            let installed = fontFamilies.map { StyleValue.font(.family($0)) }
            return TextFont.curated.map(StyleValue.font) + installed
        case (.fontSize, .text(_, let size)):
            return TextSize.choices(including: size).map(StyleValue.fontSize)
        default:
            return []
        }
    }

    /// The value the list opens on: the current width, font or size.
    static func current(for list: StyleList, options: StyleOptions) -> StyleValue? {
        switch (list, options) {
        case (.lineWidth, .stroke(let width)): .lineWidth(width)
        case (.font, .text(let font, _)): .font(font)
        case (.fontSize, .text(_, let size)): .fontSize(size)
        default: nil
        }
    }

    /// The font list is long enough to need a search field; the others aren't.
    static func isSearchable(_ list: StyleList) -> Bool {
        list == .font
    }

    static func pixels(_ value: CGFloat) -> String {
        "\(Int(value.rounded())) px"
    }
}
