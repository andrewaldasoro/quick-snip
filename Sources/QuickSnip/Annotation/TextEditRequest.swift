import Foundation

/// Text to type in place: new text at a placement, or an existing text annotation reopened
/// for editing (its text, style and placement).
struct TextEditRequest: Equatable, Sendable {
    let placement: TextPlacement
    let style: AnnotationStyle
    let text: String
    /// The annotation being edited; nil for new text.
    let annotationID: UUID?

    static func new(at placement: TextPlacement, style: AnnotationStyle) -> TextEditRequest {
        TextEditRequest(placement: placement, style: style, text: "", annotationID: nil)
    }

    /// Reopens `annotation` if it's text; nil otherwise.
    static func editing(_ annotation: Annotation) -> TextEditRequest? {
        guard case .text(let string, let origin, let boxWidth) = annotation.kind else { return nil }
        return TextEditRequest(
            placement: TextPlacement(origin: origin, boxWidth: boxWidth), style: annotation.style, text: string, annotationID: annotation.id
        )
    }
}
