import Foundation
import Testing

@testable import QuickSnip

struct ChangelogTests {
    private let markdown = """
        # Changelog

        Intro text.

        - not a release item

        ## [Unreleased]

        ### Added

        - Something in progress

        ## [1.1.0] - 2026-10-30

        ### Added

        - **Resize**: drag a handle,
          then let go
        - Fonts

        ### Fixed

        - A crash

        ## [1.0.0] - 2026-10-14

        First stable release.

        - Window snap

        ## [0.0.1] - 2026-10-01
        """

    @Test func readsReleasesNewestFirstWithoutUnreleased() {
        let releases = Changelog.releases(fromMarkdown: markdown)
        #expect(releases.map(\.version) == ["1.1.0", "1.0.0"])
        #expect(releases.first?.date == "2026-10-30")
    }

    @Test func groupsItemsUnderTheirHeadingsAndJoinsWrappedLines() throws {
        let release = try #require(Changelog.releases(fromMarkdown: markdown).first)
        #expect(
            release.groups == [
                .init(title: "Added", items: ["**Resize**: drag a handle, then let go", "Fonts"]),
                .init(title: "Fixed", items: ["A crash"]),
            ])
    }

    @Test func itemsWithoutAHeadingGetAnUntitledGroup() throws {
        let release = try #require(Changelog.releases(fromMarkdown: markdown).last)
        #expect(release.groups == [.init(title: "", items: ["Window snap"])])
    }

    @Test func emptyOrUnrelatedTextHasNoReleases() {
        #expect(Changelog.releases(fromMarkdown: "").isEmpty)
        #expect(Changelog.releases(fromMarkdown: "Just text\n- an item").isEmpty)
    }

    /// The real changelog parses, so What's New won't come up empty in a release.
    @Test func theProjectChangelogParses() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("CHANGELOG.md")
        let releases = Changelog.releases(fromMarkdown: try String(contentsOf: url, encoding: .utf8))
        #expect(releases.contains { $0.version == "1.0.0" })
        #expect(releases.allSatisfy { !$0.groups.isEmpty })
    }

    @Test func noBundledChangelogOutsideTheApp() {
        #expect(BundledChangelog().loadMarkdown() == nil)
    }
}
