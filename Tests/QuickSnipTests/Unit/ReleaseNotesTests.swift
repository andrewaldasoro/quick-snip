import Testing

@testable import QuickSnip

@MainActor
struct ReleaseNotesTests {
    @Test func headingsGroupTheirItems() {
        let html =
            "<p>First stable release.</p>\n<h3>Added</h3>\n<ul><li><b>Resize</b>: drag a handle</li><li>Fonts</li></ul>\n<h3>Fixed</h3><ul><li>A crash</li></ul>"
        #expect(
            ReleaseNotes.groups(fromHTML: html) == [
                .init(title: "", items: ["First stable release."]),
                .init(title: "Added", items: ["Resize: drag a handle", "Fonts"]),
                .init(title: "Fixed", items: ["A crash"]),
            ])
    }

    @Test func notesFromTheAppcastScriptRoundTrip() {
        let html = "<h3>Changed</h3>\n<ul><li>Uses <code>CHANGELOG.md</code> &amp; more</li></ul>\n"
        #expect(ReleaseNotes.groups(fromHTML: html) == [.init(title: "Changed", items: ["Uses CHANGELOG.md & more"])])
    }

    @Test func malformedNotesStillShowTheirText() {
        let groups = ReleaseNotes.groups(fromHTML: "<ul><li>Unclosed <b>bold</li>")
        #expect(groups.flatMap(\.items).joined(separator: " ").contains("Unclosed"))
    }

    @Test func emptyNotesHaveNoGroups() {
        #expect(ReleaseNotes.groups(fromHTML: "").isEmpty)
    }
}
