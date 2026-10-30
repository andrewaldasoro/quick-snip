import Foundation

/// The families offered in the font list: sorted by name, searchable, without the hidden
/// system families (their names start with a dot and aren't meant for users).
struct FontCatalog {
    let families: [String]

    @MainActor
    init(provider: FontFamilyProviding = SystemFontFamilies()) {
        self.init(families: provider.availableFamilies)
    }

    init(families: [String]) {
        self.families = Set(families.filter { !$0.hasPrefix(".") && !$0.isEmpty })
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Families whose name contains `query`, ignoring case and accents; all of them when empty.
    func matching(_ query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return families }
        return families.filter { $0.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}
