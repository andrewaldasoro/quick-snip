import Foundation

/// One version's release notes: its headings ("Added", "Fixed") and their items.
struct ChangelogRelease: Equatable, Identifiable, Sendable {
    struct Group: Equatable, Sendable {
        let title: String
        var items: [String]
    }

    let version: String
    let date: String?
    var groups: [Group]

    var id: String { version }
}

/// Parses `CHANGELOG.md` (Keep a Changelog): `## [1.0.0] - 2026-10-14`, `### Added`, `- item`.
/// Unreleased changes are left out: they aren't in any build users have.
enum Changelog {
    static func releases(fromMarkdown markdown: String) -> [ChangelogRelease] {
        var parser = Parser()
        for line in markdown.components(separatedBy: .newlines) {
            parser.read(line)
        }
        parser.finishRelease()
        return parser.releases.filter { !$0.groups.isEmpty }
    }

    private struct Parser {
        var releases: [ChangelogRelease] = []
        var current: ChangelogRelease?
        var isInsideItem = false

        mutating func read(_ line: String) {
            if line.hasPrefix("## ") {
                finishRelease()
                current = Self.release(fromHeading: String(line.dropFirst(3)))
            } else if line.hasPrefix("### ") {
                current?.groups.append(.init(title: line.dropFirst(4).trimmingCharacters(in: .whitespaces), items: []))
                isInsideItem = false
            } else if line.hasPrefix("- ") {
                addItem(String(line.dropFirst(2)))
            } else if isInsideItem, line.hasPrefix("  ") {
                // A wrapped item continues on an indented line.
                continueItem(line.trimmingCharacters(in: .whitespaces))
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                isInsideItem = false
            }
        }

        mutating func finishRelease() {
            if let release = current, release.version.lowercased() != "unreleased" { releases.append(release) }
            current = nil
            isInsideItem = false
        }

        private mutating func addItem(_ text: String) {
            guard var release = current else { return }
            var group = release.groups.popLast() ?? .init(title: "", items: [])
            group.items.append(text)
            release.groups.append(group)
            current = release
            isInsideItem = true
        }

        private mutating func continueItem(_ text: String) {
            guard var release = current, var group = release.groups.popLast(), let last = group.items.popLast() else { return }
            group.items.append(last + " " + text)
            release.groups.append(group)
            current = release
        }

        /// "[1.0.0] - 2026-10-14" → version and date.
        private static func release(fromHeading heading: String) -> ChangelogRelease {
            let parts = heading.components(separatedBy: " - ")
            let version = (parts.first ?? heading).trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            let date = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : nil
            return ChangelogRelease(version: version, date: date, groups: [])
        }
    }
}
