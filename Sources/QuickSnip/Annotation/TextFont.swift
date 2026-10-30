import AppKit

/// The typeface of a text annotation: a curated system style or any installed family.
enum TextFont: Hashable, Sendable {
    case system, rounded, serif, monospaced, handwriting
    case family(String)

    /// The inline choices in the toolbar; every other family is in the font list.
    static let curated: [TextFont] = [.system, .rounded, .serif, .monospaced, .handwriting]
    static let handwritingFamily = "Marker Felt"
    /// Text annotations are semibold so they stand out on screenshots.
    static let weight = NSFont.Weight.semibold
    private static let familyPrefix = "family:"

    var displayName: String {
        switch self {
        case .system: "System"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .monospaced: "Monospaced"
        case .handwriting: "Handwriting"
        case .family(let name): name
        }
    }

    /// How the choice is stored in `UserDefaults`.
    var storageValue: String {
        switch self {
        case .system: "system"
        case .rounded: "rounded"
        case .serif: "serif"
        case .monospaced: "monospaced"
        case .handwriting: "handwriting"
        case .family(let name): Self.familyPrefix + name
        }
    }

    init?(storageValue: String) {
        if storageValue.hasPrefix(Self.familyPrefix) {
            let name = String(storageValue.dropFirst(Self.familyPrefix.count))
            guard !name.isEmpty else { return nil }
            self = .family(name)
            return
        }
        guard let curated = Self.curated.first(where: { $0.storageValue == storageValue }) else { return nil }
        self = curated
    }

    /// The font at `size` points. A family that isn't installed (a font removed since it was
    /// picked) falls back to the system font, so the text still shows.
    @MainActor
    func font(size: CGFloat) -> NSFont {
        let system = NSFont.systemFont(ofSize: size, weight: Self.weight)
        switch self {
        case .system: return system
        case .rounded: return Self.font(system, design: .rounded) ?? system
        case .serif: return Self.font(system, design: .serif) ?? system
        case .monospaced: return Self.font(system, design: .monospaced) ?? system
        case .handwriting: return Self.font(family: Self.handwritingFamily, size: size) ?? system
        case .family(let name): return Self.font(family: name, size: size) ?? system
        }
    }

    @MainActor
    private static func font(_ base: NSFont, design: NSFontDescriptor.SystemDesign) -> NSFont? {
        base.fontDescriptor.withDesign(design).flatMap { NSFont(descriptor: $0, size: base.pointSize) }
    }

    /// The family's regular face. Font matching substitutes a different family for an unknown
    /// name, so the result is checked rather than trusted.
    @MainActor
    private static func font(family: String, size: CGFloat) -> NSFont? {
        let descriptor = NSFontDescriptor(fontAttributes: [.family: family])
        guard let font = NSFont(descriptor: descriptor, size: size), font.familyName == family else { return nil }
        return font
    }
}
