import AppKit

/// Release notes from the feed arrive as the HTML fragment `scripts/notes-html.py` writes
/// (Sparkle shows it as-is in its window). Settings shows them like the bundled changelog:
/// each `<h3>` over its `<li>` items.
enum ReleaseNotes {
    @MainActor
    static func groups(fromHTML html: String) -> [ChangelogRelease.Group] {
        // The fragment has no single root; wrapping it makes it a document.
        guard let document = try? XMLDocument(xmlString: "<notes>\(html)</notes>", options: []),
            let root = document.rootElement()
        else { return fallbackGroups(fromHTML: html) }

        var groups: [ChangelogRelease.Group] = []
        for element in root.children ?? [] {
            let text = (element.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            switch element.name {
            case "h3":
                groups.append(.init(title: text, items: []))
            case "ul", "ol":
                let items = (element.children ?? []).compactMap { $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }
                append(items.filter { !$0.isEmpty }, to: &groups)
            default:
                if !text.isEmpty { append([text], to: &groups) }
            }
        }
        return groups.filter { !$0.items.isEmpty }
    }

    private static func append(_ items: [String], to groups: inout [ChangelogRelease.Group]) {
        if groups.isEmpty { groups.append(.init(title: "", items: [])) }
        groups[groups.count - 1].items += items
    }

    /// Notes that aren't well-formed still show, one line per paragraph or item.
    @MainActor
    private static func fallbackGroups(fromHTML html: String) -> [ChangelogRelease.Group] {
        // Malformed notes show nothing here; Sparkle's own window still has the original.
        guard let data = html.data(using: .utf8),
            let text = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil)
        else { return [] }
        let lines = text.string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "•\t"))) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? [] : [.init(title: "", items: lines)]
    }
}
