import AppKit

/// Where a text annotation's text goes. Its origin is always its box's top-left. Text in a
/// dragged box wraps to the box's width; text placed with a click has a box as wide as its
/// longest line, which grows right and down as it's typed. Alignment lines the lines up inside
/// the box, so it never moves the box.
@MainActor
enum TextLayout {
    /// The narrowest box a drag makes; anything shorter counts as a click.
    static let minimumBoxWidth: CGFloat = 24

    static func attributed(_ string: String, style: AnnotationStyle) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = style.alignment.nsAlignment
        return NSAttributedString(
            string: string,
            attributes: [
                .font: style.font.font(size: style.fontSize),
                .foregroundColor: style.color.nsColor,
                .paragraphStyle: paragraph,
            ])
    }

    static func frame(_ string: String, origin: CGPoint, boxWidth: CGFloat?, style: AnnotationStyle) -> CGRect {
        let text = attributed(string, style: style)
        guard let boxWidth else {
            let size = text.size()
            return CGRect(origin: origin, size: size)
        }
        let height = text.boundingRect(
            with: CGSize(width: boxWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).height
        return CGRect(x: origin.x, y: origin.y, width: boxWidth, height: max(ceil(height), lineHeight(style)))
    }

    /// One empty line, so an empty box still has a height to show.
    static func lineHeight(_ style: AnnotationStyle) -> CGFloat {
        let font = style.font.font(size: style.fontSize)
        return ceil(font.ascender - font.descender + font.leading)
    }

    static func draw(_ string: String, origin: CGPoint, boxWidth: CGFloat?, style: AnnotationStyle) {
        attributed(string, style: style).draw(
            with: frame(string, origin: origin, boxWidth: boxWidth, style: style), options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}
