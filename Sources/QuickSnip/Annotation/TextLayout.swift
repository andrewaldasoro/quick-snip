import AppKit

/// Where a text annotation's text goes. Text in a box wraps to the box's width, with its
/// origin at the box's top-left. Text placed with a click is one line; its origin is the
/// click, which is the line's start, middle or end depending on the alignment.
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
            return CGRect(x: origin.x - size.width * style.alignment.anchorFraction, y: origin.y, width: size.width, height: size.height)
        }
        let height = text.boundingRect(
            with: CGSize(width: boxWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).height
        return CGRect(x: origin.x, y: origin.y, width: boxWidth, height: max(ceil(height), lineHeight(style)))
    }

    /// The origin that puts one-line text's frame at `frame` with `alignment`.
    static func origin(forLineFrame frame: CGRect, alignment: TextAlignment) -> CGPoint {
        CGPoint(x: frame.minX + frame.width * alignment.anchorFraction, y: frame.minY)
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
