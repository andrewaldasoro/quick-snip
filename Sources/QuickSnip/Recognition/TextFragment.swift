import CoreGraphics

/// One piece of recognized text and where it sits, in Vision's normalized space
/// (0–1, bottom-left origin).
struct TextFragment: Equatable, Sendable {
    let text: String
    let bounds: CGRect

    /// Fragments in reading order: lines top to bottom, each line left to right.
    /// Fragments whose vertical centers are within half a line height share a line,
    /// so a row of columns or table cells reads across instead of down.
    static func readingOrder(_ fragments: [TextFragment]) -> String {
        var lines: [[TextFragment]] = []
        for fragment in fragments.sorted(by: { $0.bounds.midY > $1.bounds.midY }) {
            if let last = lines.last?.last,
                abs(last.bounds.midY - fragment.bounds.midY) < min(last.bounds.height, fragment.bounds.height) / 2
            {
                lines[lines.count - 1].append(fragment)
            } else {
                lines.append([fragment])
            }
        }
        return
            lines
            .map { line in line.sorted { $0.bounds.minX < $1.bounds.minX }.map(\.text).joined(separator: " ") }
            .joined(separator: "\n")
    }
}
