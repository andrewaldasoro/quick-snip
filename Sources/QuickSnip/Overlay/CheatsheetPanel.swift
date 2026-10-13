import AppKit

/// The shortcut cheatsheet inside the capture overlay, toggled with **?**. Drawn straight into
/// the overlay view: the overlay sits above the level where macOS opens menus and popovers.
@MainActor
struct CheatsheetPanel {
    typealias Section = ShortcutCheatsheet.Section

    static let title = "Keyboard Shortcuts"
    static let footer = "Press ? or Esc to close"
    static let columnCount = 3
    static let padding: CGFloat = 24
    static let columnSpacing: CGFloat = 32
    static let titleHeight: CGFloat = 36
    static let headerHeight: CGFloat = 24
    static let rowHeight: CGFloat = 24
    static let sectionSpacing: CGFloat = 14
    static let footerHeight: CGFloat = 28
    static let actionKeySpacing: CGFloat = 20
    static let keySpacing: CGFloat = 4
    static let keyPadding = CGSize(width: 6, height: 2)
    static let keyCornerRadius: CGFloat = 4
    static let cornerRadius: CGFloat = 14

    static let backgroundColor = NSColor.black.withAlphaComponent(0.85)
    static let keyColor = NSColor.white.withAlphaComponent(0.18)
    static let textColor = NSColor.white
    static let secondaryTextColor = NSColor.white.withAlphaComponent(0.6)
    static let titleFont = NSFont.systemFont(ofSize: 17, weight: .bold)
    static let headerFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
    static let actionFont = NSFont.systemFont(ofSize: 13)
    static let keyFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    static let noteFont = NSFont.systemFont(ofSize: 11)

    let columns: [[Section]]

    init(cheatsheet: ShortcutCheatsheet) {
        columns = Self.columns(of: cheatsheet.sections, count: Self.columnCount)
    }

    // MARK: Layout

    /// Spreads sections over columns, each going to the shortest column so far.
    static func columns(of sections: [Section], count: Int) -> [[Section]] {
        var columns = Array(repeating: [Section](), count: count)
        var heights = Array(repeating: CGFloat.zero, count: count)
        for section in sections {
            let shortest = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            columns[shortest].append(section)
            heights[shortest] += height(of: section) + sectionSpacing
        }
        return columns.filter { !$0.isEmpty }
    }

    static func height(of section: Section) -> CGFloat {
        headerHeight + CGFloat(section.entries.count) * rowHeight + (section.note == nil ? 0 : rowHeight)
    }

    static func height(of column: [Section]) -> CGFloat {
        column.map(height(of:)).reduce(0, +) + CGFloat(max(column.count - 1, 0)) * sectionSpacing
    }

    var size: CGSize {
        let widths = columns.map(Self.width(of:))
        let width = widths.reduce(0, +) + CGFloat(max(widths.count - 1, 0)) * Self.columnSpacing
        let height = columns.map(Self.height(of:)).max() ?? 0
        return CGSize(
            width: (width + Self.padding * 2).rounded(.up),
            height: (Self.titleHeight + height + Self.footerHeight + Self.padding * 2).rounded(.up)
        )
    }

    /// Centered on the display.
    func frame(in bounds: CGRect) -> CGRect {
        let size = size
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height).integral
    }

    private static func width(of column: [Section]) -> CGFloat {
        let rows = column.flatMap { section in
            section.entries.map { text($0.action, actionFont).size().width + actionKeySpacing + keysWidth($0.keys) }
        }
        let notes = column.compactMap { $0.note.map { text($0, noteFont).size().width } }
        let headers = column.map { text($0.title.uppercased(), headerFont).size().width }
        return (rows + notes + headers).max() ?? 0
    }

    private static func keysWidth(_ keys: [String]) -> CGFloat {
        keys.map { keyCapSize($0).width }.reduce(0, +) + CGFloat(max(keys.count - 1, 0)) * keySpacing
    }

    private static func keyCapSize(_ key: String) -> CGSize {
        let size = text(key, keyFont).size()
        return CGSize(width: size.width + keyPadding.width * 2, height: size.height + keyPadding.height * 2)
    }

    private static func text(_ string: String, _ font: NSFont, color: NSColor = textColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    }

    // MARK: Drawing

    /// Draws into the current context; expects a flipped view (top-left origin).
    func draw(in bounds: CGRect) {
        let frame = frame(in: bounds)
        Self.backgroundColor.setFill()
        NSBezierPath(roundedRect: frame, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius).fill()

        let content = frame.insetBy(dx: Self.padding, dy: Self.padding)
        Self.text(Self.title, Self.titleFont).draw(at: content.origin)

        var x = content.minX
        for column in columns {
            let width = Self.width(of: column)
            drawColumn(column, at: CGPoint(x: x, y: content.minY + Self.titleHeight), width: width)
            x += width + Self.columnSpacing
        }

        let footer = Self.text(Self.footer, Self.noteFont, color: Self.secondaryTextColor)
        let footerSize = footer.size()
        footer.draw(at: CGPoint(x: content.midX - footerSize.width / 2, y: content.maxY - footerSize.height))
    }

    private func drawColumn(_ column: [Section], at origin: CGPoint, width: CGFloat) {
        var y = origin.y
        for section in column {
            Self.text(section.title.uppercased(), Self.headerFont, color: Self.secondaryTextColor).draw(at: CGPoint(x: origin.x, y: y))
            y += Self.headerHeight
            for entry in section.entries {
                drawEntry(entry, in: CGRect(x: origin.x, y: y, width: width, height: Self.rowHeight))
                y += Self.rowHeight
            }
            if let note = section.note {
                Self.text(note, Self.noteFont, color: Self.secondaryTextColor).draw(at: CGPoint(x: origin.x, y: y + 4))
                y += Self.rowHeight
            }
            y += Self.sectionSpacing
        }
    }

    /// Action on the left, key caps right-aligned, both centered in the row.
    private func drawEntry(_ entry: ShortcutCheatsheet.Entry, in row: CGRect) {
        let action = Self.text(entry.action, Self.actionFont)
        action.draw(at: CGPoint(x: row.minX, y: row.midY - action.size().height / 2))

        var x = row.maxX - Self.keysWidth(entry.keys)
        for key in entry.keys {
            let size = Self.keyCapSize(key)
            let cap = CGRect(x: x, y: row.midY - size.height / 2, width: size.width, height: size.height)
            Self.keyColor.setFill()
            NSBezierPath(roundedRect: cap, xRadius: Self.keyCornerRadius, yRadius: Self.keyCornerRadius).fill()
            Self.text(key, Self.keyFont).draw(at: CGPoint(x: cap.minX + Self.keyPadding.width, y: cap.minY + Self.keyPadding.height))
            x += size.width + Self.keySpacing
        }
    }
}
